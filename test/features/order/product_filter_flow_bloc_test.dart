import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/localization/localized_text.dart';
import 'package:steelforce/core/database/drift/app_database.dart'
    hide Category, Product;
import 'package:steelforce/features/order/data/local/product_drift_local_data_source.dart';
import 'package:steelforce/features/order/data/local/product_filter_local_data_source.dart';
import 'package:steelforce/features/order/data/mock/isi_demo_catalog.dart';
import 'package:steelforce/features/order/data/models/category_model.dart';
import 'package:steelforce/features/order/data/models/product_model.dart';
import 'package:steelforce/features/order/data/remote/mock_product_filter_remote_data_source.dart';
import 'package:steelforce/features/order/data/repositories/product_filter_repository_impl.dart';
import 'package:steelforce/features/order/domain/entities/filter/filter_option.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/entities/product_filter.dart';
import 'package:steelforce/features/order/domain/entities/material_category.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/repositories/material_availability_repository.dart';
import 'package:steelforce/features/order/domain/usecases/check_material_availability.dart';
import 'package:steelforce/features/order/domain/usecases/get_materials.dart';
import 'package:steelforce/features/order/domain/usecases/fetch_filter_categories.dart';
import 'package:steelforce/features/order/domain/usecases/get_category_filter_schema.dart';
import 'package:steelforce/features/order/domain/usecases/get_filter_step_options.dart';
import 'package:steelforce/features/order/domain/usecases/get_stock_location_options.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_bloc.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_event.dart';
import 'package:steelforce/features/order/presentation/bloc/product_filter_flow/product_filter_flow_state.dart';

/// Counts product reads so the tests can assert the flow's central promise:
/// the catalog is not queried for products until every filter is answered.
class _CountingMaterials extends GetMaterials {
  _CountingMaterials(super.repository);

  int calls = 0;

  @override
  ResultFuture<PagedResult<Product>> call(GetMaterialsParams params) {
    calls++;
    return super.call(params);
  }
}

/// Stands in for the live SAP sellability check, which these tests must never
/// make.
///
/// It answers the way an unreachable middleware does, and that is the point:
/// the flow has to treat "could not ask" as *no verdict at all*, not as a
/// refusal. Every assertion below about products reaching the screen would
/// still pass if this quietly returned "unsellable", so the failure it guards
/// against is the flow letting a failed check disable a card.
///
/// [calls] is exposed so a test can assert the check is spent on commitment
/// rather than on browsing.
class _OfflineAvailability implements MaterialAvailabilityRepository {
  int calls = 0;

  @override
  ResultFuture<MaterialAvailability> checkAvailability(String material) async {
    calls++;
    return const Failed(NetworkFailure());
  }
}

void main() {
  late AppDatabase db;
  late ProductDriftLocalDataSource catalog;
  late _CountingMaterials materials;
  late _OfflineAvailability availability;
  late ProductFilterFlowBloc bloc;

  /// Two rows under a category SAP publishes no schema for, with no diameter
  /// and no thickness — the shape that forces the generic schema to skip.
  Future<void> seedGenericCategory() async {
    final base = IsiDemoCatalog.products().first;
    await catalog.upsertCategories([
      const CategoryModel(
        id: 'cat_legacy_demo',
        code: 'cat_legacy_demo',
        name: LocalizedText(en: 'Legacy Demo', km: ''),
        displayOrder: 9,
      ),
    ]);
    await catalog.upsertProducts([
      for (var i = 0; i < 2; i++)
        ProductModel.fromJson({
          ...base,
          'id': 'LEGACY-$i',
          'code': 'LEGACY-$i',
          'sku': 'LEGACY-$i',
          'barcode': 'BC-LEGACY-$i',
          'categoryId': 'cat_legacy_demo',
          'familyId': 'fam_legacy',
          'familyName': 'Legacy Family',
          'grade': 'G$i',
          'size': 'S$i',
          'diameter': 0.0,
          'thickness': 0.0,
        }),
    ]);
  }

  /// Waits for the flow to go quiet. The mock data layer deliberately
  /// simulates a slow backend (`MockLatency`), so a fixed short delay would
  /// assert against a half-loaded state — which is exactly the bug class these
  /// tests exist to catch.
  Future<void> settle() async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    var previous = bloc.state;
    var stableTicks = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      final current = bloc.state;
      final busy = current.status == FilterFlowStatus.loading ||
          current.optionsLoading ||
          current.productStatus == ProductListStatus.loading ||
          current.productStatus == ProductListStatus.loadingMore;

      if (current == previous && !busy) {
        if (++stableTicks >= 3) return;
      } else {
        stableTicks = 0;
        previous = current;
      }
    }
    fail('flow did not settle within 15s');
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    catalog = ProductDriftLocalDataSource(db.catalogDao);
    await catalog.upsertProducts(
      IsiDemoCatalog.products().map(ProductModel.fromJson).toList(),
    );
    await catalog.upsertCategories(
      IsiDemoCatalog.categories().map(CategoryModel.fromJson).toList(),
    );

    final filterRepository = ProductFilterRepositoryImpl(
      remote: MockProductFilterRemoteDataSource(),
      local: ProductFilterDriftLocalDataSource(db.catalogDao),
      products: catalog,
    );
    materials = _CountingMaterials(filterRepository);
    availability = _OfflineAvailability();

    bloc = ProductFilterFlowBloc(
      fetchFilterCategories: FetchFilterCategories(filterRepository),
      getCategoryFilterSchema: GetCategoryFilterSchema(filterRepository),
      getFilterStepOptions: GetFilterStepOptions(filterRepository),
      getStockLocationOptions: GetStockLocationOptions(filterRepository),
      getMaterials: materials,
      checkMaterialAvailability: CheckMaterialAvailability(availability),
    );
  });

  tearDown(() async {
    await bloc.close();
    await db.close();
  });

  /// Palm Profile roofing — ISI's volume line, and the deepest published
  /// hierarchy (profile → coating → gauge → colour), so it exercises the most
  /// of the flow per test.
  const structural = MaterialCategory(
    code: IsiDemoCatalog.palmProfileCategoryId,
    name: LocalizedText(en: 'Palm Profile Roofing', km: 'ផាម ភ្លី'),
    materialCount: 6,
    hasPublishedSchema: true,
  );

  /// A row read back out of the demo catalog, so tests that need a real
  /// material number or Khmer description don't hardcode one that the next
  /// SAP extract invalidates.
  Map<String, dynamic> demoRow(String categoryId) =>
      IsiDemoCatalog.products().firstWhere(
        (p) => p['categoryId'] == categoryId,
      );

  /// Answers the active step with its first option, repeatedly, until the flow
  /// has nothing left to ask.
  Future<void> answerEveryStep() async {
    while (bloc.state.activeStep != null) {
      final step = bloc.state.activeStep!;
      expect(bloc.state.activeOptions, isNotEmpty);
      bloc.add(FilterStepAnswered(
          stepKey: step.key, option: bloc.state.activeOptions.first));
      await settle();
    }
  }

  test('opening the flow loads categories and no products', () async {
    bloc.add(const FilterFlowStarted());
    await settle();

    expect(bloc.state.stage, FilterFlowStage.categories);
    expect(bloc.state.categories, isNotEmpty);
    expect(materials.calls, 0);
    expect(bloc.state.products, isEmpty);
  });

  test('picking a category asks the first step, still without products',
      () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();

    expect(bloc.state.stage, FilterFlowStage.steps);
    expect(bloc.state.activeStep!.key, 'profile');
    // Whatever the current extract's profiles are, the picker must offer them
    // all and account for every SKU in the category.
    expect(bloc.state.activeOptions, isNotEmpty);
    expect(
      bloc.state.activeOptions.fold<int>(0, (sum, o) => sum + o.matchCount),
      6,
    );
    expect(materials.calls, 0);
  });

  test('products are requested exactly once, after the last answer', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();

    // Walk every level but the last, asserting nothing is fetched on the way.
    while (bloc.state.activeStep != null) {
      expect(materials.calls, 0,
          reason: 'no product read before the last step');
      final step = bloc.state.activeStep!;
      bloc.add(FilterStepAnswered(
          stepKey: step.key, option: bloc.state.activeOptions.first));
      await settle();
    }

    expect(bloc.state.stage, FilterFlowStage.products);
    expect(materials.calls, 1);
    expect(bloc.state.productStatus, ProductListStatus.loaded);
    expect(bloc.state.products, isNotEmpty);
  });

  test('every answered option maps onto a product that actually exists',
      () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    await answerEveryStep();

    expect(bloc.state.products, isNotEmpty,
        reason: 'a fully answered path must never dead-end');
  });

  test('clearing a chip drops its dependents and the product list', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    await answerEveryStep();
    expect(bloc.state.products, isNotEmpty);

    // Clear the *second* answer, whatever the current schema calls it.
    final steps = bloc.state.schema!.steps;
    final cleared = steps[1].key;

    bloc.add(FilterStepCleared(cleared));
    await settle();

    expect(bloc.state.selection.valueFor(steps.first.key), isNotNull,
        reason: 'the step above the cleared one survives');
    expect(bloc.state.selection.valueFor(cleared), isNull);
    for (final below in steps.skip(2)) {
      expect(bloc.state.selection.valueFor(below.key), isNull,
          reason: '${below.key} depended on $cleared');
    }
    expect(bloc.state.products, isEmpty);
    expect(bloc.state.stage, FilterFlowStage.steps);
    expect(bloc.state.activeStep!.key, cleared);
  });

  test('back retraces one answer at a time, then returns to categories',
      () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();

    final firstStep = bloc.state.activeStep!;
    bloc.add(FilterStepAnswered(
        stepKey: firstStep.key, option: bloc.state.activeOptions.first));
    await settle();
    expect(bloc.state.activeStep!.key, isNot(firstStep.key));

    bloc.add(const FilterFlowBackRequested());
    await settle();
    expect(bloc.state.activeStep!.key, firstStep.key);
    expect(bloc.state.selection.isEmpty, isTrue);

    bloc.add(const FilterFlowBackRequested());
    await settle();
    expect(bloc.state.stage, FilterFlowStage.categories);
    expect(bloc.state.canGoBack, isFalse);
  });

  test('a step with no options for the current path is skipped, not shown',
      () async {
    // A category with no published schema falls back to the generic one, whose
    // diameter/thickness steps have no data here. The rep must never be shown
    // an empty picker — those levels are passed over silently.
    await seedGenericCategory();

    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(MaterialCategory(
        code: 'cat_legacy_demo',
        name: LocalizedText(en: 'Legacy Demo', km: ''),
        materialCount: 2,
        hasPublishedSchema: true)));
    await settle();

    final shown = <String>[];
    while (bloc.state.activeStep != null) {
      shown.add(bloc.state.activeStep!.key);
      expect(bloc.state.activeOptions, isNotEmpty,
          reason: 'every step reached must have something to choose');
      bloc.add(FilterStepAnswered(
          stepKey: bloc.state.activeStep!.key,
          option: bloc.state.activeOptions.first));
      await settle();
    }

    expect(shown, isNot(contains('diameter')));
    expect(shown, isNot(contains('thickness')));
    expect(bloc.state.stage, FilterFlowStage.products);
    expect(bloc.state.products, isNotEmpty);
  });

  test('searching narrows the resolved set without re-running the flow',
      () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    await answerEveryStep();

    final before = materials.calls;
    bloc.add(const FilterProductSearchChanged('PALM'));
    await Future<void>.delayed(const Duration(milliseconds: 400)); // debounce
    await settle();

    expect(materials.calls, before + 1);
    expect(bloc.state.query, 'PALM');
    expect(bloc.state.stage, FilterFlowStage.products);
  });

  /// Types a query and waits out the debounce plus the load.
  Future<void> search(String query) async {
    bloc.add(FilterProductSearchChanged(query));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await settle();
  }

  test('a direct search from the category stage skips the hierarchy', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    expect(materials.calls, 0);

    // A word out of a real product description, so the assertion tracks the
    // extract rather than a name invented for the test.
    final term =
        (demoRow(IsiDemoCatalog.palmProfileCategoryId)['name'] as String)
            .split(' ')
            .first;
    await search(term);

    expect(materials.calls, 1);
    expect(bloc.state.stage, FilterFlowStage.products);
    expect(bloc.state.category, isNull,
        reason: 'searching commits the rep to no category');
    expect(bloc.state.products, isNotEmpty);
    expect(
      bloc.state.products.every((p) =>
          p.code.toUpperCase().contains(term.toUpperCase()) ||
          p.name.toUpperCase().contains(term.toUpperCase()) ||
          p.description.toUpperCase().contains(term.toUpperCase())),
      isTrue,
    );
  });

  test('a search shorter than the minimum never reaches the catalog', () async {
    bloc.add(const FilterFlowStarted());
    await settle();

    await search('D');

    expect(materials.calls, 0,
        reason: 'one character matches most of the catalog');
    expect(bloc.state.stage, FilterFlowStage.categories);
  });

  test('search finds a product by its SAP material number', () async {
    bloc.add(const FilterFlowStarted());
    await settle();

    final materialCode =
        demoRow(IsiDemoCatalog.palmProfileCategoryId)['materialCode'] as String;
    await search(materialCode);

    expect(bloc.state.products, hasLength(1));
    expect(bloc.state.products.single.materialCode, materialCode);
  });

  test('search matches the Khmer product name', () async {
    bloc.add(const FilterFlowStarted());
    await settle();

    // SAP's MaterialDesKH now lives in its own `nameKh` column rather than
    // being concatenated into the description, so the assertion follows it
    // there. Take a distinctive word out of a real row.
    final khmer =
        (demoRow(IsiDemoCatalog.palmProfileCategoryId)['nameKh'] as String)
            .split(RegExp(r'\s+'))
            .firstWhere((w) => w.runes.any((r) => r > 0x1780));

    await search(khmer);

    expect(bloc.state.products, isNotEmpty,
        reason: 'Khmer text must be searchable, not just the English name');
    expect(
      bloc.state.products.every((p) => p.nameKh.contains(khmer)),
      isTrue,
    );
  });

  test('search narrows further as hierarchy answers are added', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();

    await search('PALM');
    final unfiltered = bloc.state.products.length;
    expect(unfiltered, greaterThan(1));

    // Answering the step the rep was on re-runs the same search inside it.
    final step = bloc.state.activeStep!;
    bloc.add(FilterStepAnswered(
        stepKey: step.key, option: bloc.state.activeOptions.first));
    await settle();

    expect(bloc.state.query, 'PALM', reason: 'the search survives an answer');
    expect(bloc.state.products.length, lessThan(unfiltered));
  });

  test('clearing the search returns the rep to the step they were on',
      () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    final step = bloc.state.activeStep!.key;

    await search('PALM');
    expect(bloc.state.stage, FilterFlowStage.products);

    await search('');

    expect(bloc.state.stage, FilterFlowStage.steps);
    expect(bloc.state.activeStep!.key, step);
    expect(bloc.state.products, isEmpty);
  });

  test('find-new-product clears the flow and the search', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    await answerEveryStep();

    bloc.add(const FindNewProductRequested());
    await settle();

    expect(bloc.state.stage, FilterFlowStage.categories);
    expect(bloc.state.category, isNull);
    expect(bloc.state.selection.isEmpty, isTrue);
    expect(bloc.state.query, isEmpty);
    expect(bloc.state.products, isEmpty);
    expect(bloc.state.categories, isNotEmpty,
        reason: 'the rep lands back on a usable category list');
  });

  test('changing sort re-runs the query without touching the answers',
      () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    await answerEveryStep();

    final answers = bloc.state.selection;
    final before = materials.calls;

    bloc.add(const FilterPreferencesChanged(sortBy: ProductSortBy.priceDesc));
    await settle();

    expect(materials.calls, before + 1);
    expect(bloc.state.sortBy, ProductSortBy.priceDesc);
    expect(bloc.state.selection, answers);
  });

  test('sort and stock preferences reach the catalog query', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterPreferencesChanged(
        sortBy: ProductSortBy.priceAsc, availableOnly: true));
    await settle();

    await search('PALM');

    expect(bloc.state.productFilter.sortBy, ProductSortBy.priceAsc);
    expect(bloc.state.productFilter.availableOnly, isTrue);
    final prices = bloc.state.products.map((p) => p.effectivePrice).toList();
    expect(prices, orderedEquals(List.of(prices)..sort()));
  });

  test('reset returns to the category list and forgets the selection',
      () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    await answerEveryStep();

    bloc.add(const FilterFlowReset());
    await settle();

    expect(bloc.state.stage, FilterFlowStage.categories);
    expect(bloc.state.selection.isEmpty, isTrue);
    expect(bloc.state.products, isEmpty);
    expect(bloc.state.categories, isNotEmpty);
  });

  test('unused option lists never leak between categories', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(structural));
    await settle();
    final structuralOptions =
        bloc.state.activeOptions.map((o) => o.label).toSet();

    bloc.add(const FilterCategorySelected(MaterialCategory(
        code: IsiDemoCatalog.reinforcementCategoryId,
        name: LocalizedText(en: 'Reinforcement (Traded)', km: ''),
        materialCount: 1,
        hasPublishedSchema: true)));
    await settle();

    final rebarOptions = bloc.state.activeOptions.map((o) => o.label).toSet();
    expect(rebarOptions.intersection(structuralOptions), isEmpty);
    expect(bloc.state.selection.isEmpty, isTrue);
  });

  test('an option carries how many SKUs it keeps alive', () async {
    bloc.add(const FilterFlowStarted());
    await settle();
    bloc.add(const FilterCategorySelected(MaterialCategory(
        code: IsiDemoCatalog.giPipeCategoryId,
        name: LocalizedText(en: 'Galvanized Pipes', km: ''),
        materialCount: 1,
        hasPublishedSchema: true)));
    await settle();

    expect(
      bloc.state.activeOptions,
      everyElement(isA<FilterOption>()
          .having((o) => o.matchCount, 'matchCount', greaterThan(0))),
    );
  });
}
