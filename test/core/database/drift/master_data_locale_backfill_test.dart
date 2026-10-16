import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/master_data_locale_backfill.dart';
import 'package:steelforce/core/logging/app_logger.dart';

/// Guards the step that makes a bilingual feed actually reach an existing
/// install.
///
/// The failure this prevents is the subtle one: everything downstream is
/// correct — widgets locale-aware, entities bilingual, the asset regenerated —
/// and the rep still sees English, because their device holds a populated
/// cache plus a `last_synced_at` watermark, and both sync repositories only
/// take the initial (full) path when that watermark is `null`. Nothing errors.
/// It just looks like the translation work did nothing.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  MasterDataLocaleBackfill backfill() =>
      MasterDataLocaleBackfill(db: db, logger: const ConsoleAppLogger());

  Future<void> seedWatermarks() async {
    final at = DateTime.utc(2026, 7, 1);
    await db.into(db.catalogSyncMeta).insertOnConflictUpdate(
        CatalogSyncMetaCompanion.insert(
            entity: 'products', lastSyncedAt: Value(at)));
    await db.into(db.depotSyncMeta).insertOnConflictUpdate(
        DepotSyncMetaCompanion.insert(
            entity: 'depots', lastSyncedAt: Value(at)));
    await db.into(db.routeSyncMeta).insertOnConflictUpdate(
        RouteSyncMetaCompanion.insert(
            entity: 'routes', lastSyncedAt: Value(at)));
  }

  Future<int> watermarkCount() async {
    final catalog = await db.select(db.catalogSyncMeta).get();
    final depots = await db.select(db.depotSyncMeta).get();
    final routes = await db.select(db.routeSyncMeta).get();
    return catalog.length + depots.length + routes.length;
  }

  test('clears every master-data watermark so the next sync is a full one',
      () async {
    await seedWatermarks();
    expect(await watermarkCount(), 3);

    expect(await backfill().run(), isTrue);

    // All three, not just the catalog: depot names drive the directory *and*
    // the route stop cards, so leaving that cursor set would fix products and
    // leave every shop name Latin.
    expect(await watermarkCount(), 0);
  });

  test('runs exactly once — a second launch is a no-op', () async {
    await seedWatermarks();
    expect(await backfill().run(), isTrue);

    // Simulate the app re-syncing after the backfill.
    await seedWatermarks();

    expect(await backfill().run(), isFalse,
        reason: 'a repeating backfill would force a full catalog re-sync on '
            'every launch — minutes of work and mobile data each time');
    expect(await watermarkCount(), 3,
        reason: 'the second run must not touch the fresh watermarks');
  });

  test('is safe on a fresh install with nothing synced yet', () async {
    expect(await watermarkCount(), 0);
    expect(await backfill().run(), isTrue);
    expect(await watermarkCount(), 0);
    expect(await db.appMetadataDao.getValue(MasterDataLocaleBackfill.markerKey),
        isNotNull);
  });

  test('writes the marker so completion is observable', () async {
    await backfill().run();
    final marker =
        await db.appMetadataDao.getValue(MasterDataLocaleBackfill.markerKey);
    expect(DateTime.tryParse(marker!), isNotNull);
  });
}
