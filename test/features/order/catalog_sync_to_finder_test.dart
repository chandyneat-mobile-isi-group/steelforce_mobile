import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/database/drift/app_database.dart' hide Category;
import 'package:steelforce/features/order/data/local/product_drift_local_data_source.dart';
import 'package:steelforce/features/order/data/local/product_filter_local_data_source.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/remote/mock_product_remote_data_source.dart';
import 'package:steelforce/features/order/data/repositories/product_filter_repository_impl.dart';
import 'package:steelforce/features/order/data/remote/mock_product_filter_remote_data_source.dart';
import 'package:steelforce/features/order/data/repositories/sync_repository_impl.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/order/data/repositories/product_repository_impl.dart';
import 'package:steelforce/features/order/domain/usecases/count_products.dart';
import 'package:steelforce/features/order/domain/usecases/get_last_synced_at.dart';
import 'package:steelforce/features/order/domain/usecases/run_delta_sync.dart';
import 'package:steelforce/features/order/domain/usecases/run_initial_sync.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_cubit.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_selection.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';

/// End-to-end from the sync feed to the finder's opening screen.
///
/// The other tests in this folder seed the catalog tables directly, which
/// skips the exact path that broke in the field: sync runs, reports thousands
/// of rows upserted, and the category picker still comes up empty. Anything
/// that only asserts on a hand-seeded database cannot catch that, so this file
/// starts where the app does — at the remote feed.
class _AlwaysOnline implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

void main() {
  late AppDatabase db;
  late ProductDriftLocalDataSource local;
  late ProductFilterDriftLocalDataSource facets;
  late SyncRepositoryImpl sync;
  late ProductFilterRepositoryImpl filters;

  final scope = SyncScope(
    repId: 'rep-1',
    territory: 'Phnom Penh',
    warehouseCodes: const ['WH-PP01', 'WH-PP02', 'WH-PP03'],
    businessUnit: 'ISI Steel',
    pricingGroup: 'STANDARD',
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    local = ProductDriftLocalDataSource(db.catalogDao);
    facets = ProductFilterDriftLocalDataSource(db.catalogDao);
    sync = SyncRepositoryImpl(
      remote: MockProductRemoteDataSource(),
      local: local,
      network: _AlwaysOnline(),
    );
    filters = ProductFilterRepositoryImpl(
      remote: MockProductFilterRemoteDataSource(),
      local: facets,
    );
  });
  tearDown(() => db.close());

  test('an initial sync leaves the finder with categories to open on',
      () async {
    final result = await sync.runInitialSync(scope);
    expect(result.when(success: (r) => r.upserted, failure: (_) => 0),
        greaterThan(0));

    final categories = await filters.getFilterCategories();
    final list = categories.when(success: (c) => c, failure: (_) => const []);

    expect(list, isNotEmpty,
        reason: 'this is the empty-category-picker bug: sync reported rows, '
            'so the finder must have something to open on');
  });

  test('every ISI demo category survives the sync and has products', () async {
    await sync.runInitialSync(scope);

    final result = await filters.getFilterCategories();
    final ids = result
        .when(success: (c) => c, failure: (_) => const [])
        .map((c) => c.code)
        .toSet();

    for (final category in IsiDemoCatalog.categories()) {
      expect(ids, contains(category['id']),
          reason: '${category['name']} vanished between the feed and the '
              'finder — it is in the demo catalog but not offerable');
    }
  });

  test('a delta sync on top of an initial one keeps the categories', () async {
    await sync.runInitialSync(scope);
    final before = (await filters.getFilterCategories())
        .when(success: (c) => c, failure: (_) => const [])
        .length;

    await sync.runDeltaSync(scope);

    final after = (await filters.getFilterCategories())
        .when(success: (c) => c, failure: (_) => const [])
        .length;

    expect(after, before,
        reason: 'delta sync must not strand the taxonomy it just refreshed');
  });

  test('a stale taxonomy on disk is pruned by the next sync', () async {
    // What an upgraded device looks like: categories from the previous
    // taxonomy already sitting in the table, with no products pointing at them.
    await local.upsertCategories(const [
      CategoryModel(
        id: 'cat_isi_palm',
        code: 'cat_isi_palm',
        name: LocalizedText(en: 'Palm (retired)', km: ''),
        displayOrder: 0,
      ),
      CategoryModel(
        id: 'cat_isi_debar',
        code: 'cat_isi_debar',
        name: LocalizedText(en: 'DeBar (retired)', km: ''),
        displayOrder: 1,
      ),
    ]);

    await sync.runInitialSync(scope);

    final ids = (await filters.getFilterCategories())
        .when(success: (c) => c, failure: (_) => const [])
        .map((c) => c.code)
        .toSet();

    expect(ids, isNot(contains('cat_isi_palm')));
    expect(ids, isNot(contains('cat_isi_debar')));
    expect(ids, isNotEmpty);
  });

  test('a sync timestamp with an empty catalog still triggers a pull',
      () async {
    // The exact state behind the empty category picker: the device synced once
    // under the previous taxonomy, so `catalog_sync_meta` carries a date, but
    // the migration cleared the products behind it. Keying "do I need to sync"
    // off the timestamp alone read that as "nothing to do" and left the rep
    // stuck with no way to recover from inside the app.
    await local.setLastSyncedAt('products', DateTime(2026, 1, 1));
    expect(await local.count(), 0);

    final cubit = SyncCubit(
      runInitialSync: RunInitialSync(sync),
      runDeltaSync: RunDeltaSync(sync),
      getLastSyncedAt: GetLastSyncedAt(sync),
      countProducts: CountProducts(ProductRepositoryImpl(local)),
      sessionManager: SessionManager(),
    );
    addTearDown(cubit.close);

    await cubit.syncIfNeeded();

    expect(await local.count(), greaterThan(0),
        reason: 'an empty catalog must outrank a stale sync timestamp');
    final categories = (await filters.getFilterCategories())
        .when(success: (c) => c, failure: (_) => const []);
    expect(categories, isNotEmpty);
  });

  test('every offered category can actually be walked to a product', () async {
    await sync.runInitialSync(scope);

    final categories = (await filters.getFilterCategories())
        .when(success: (c) => c, failure: (_) => const []);

    for (final category in categories) {
      final schema = (await filters.getFilterSchema(category.code))
          .when(success: (s) => s, failure: (_) => null);
      expect(schema, isNotNull, reason: '${category.name} has no schema');

      // The first step of every offered category must have something to ask.
      // An offered category whose opening picker is empty is the same defect
      // as an empty category list, one screen later.
      final first = schema!.steps.isEmpty ? null : schema.steps.first;
      if (first == null) continue;

      final options = (await filters.getStepOptions(
        schema: schema,
        step: first,
        selection: const FilterSelection.empty(),
      ))
          .when(success: (o) => o, failure: (_) => const []);

      expect(options, isNotEmpty,
          reason: '${category.name} opens on an empty ${first.label} picker');
    }
  });
}
