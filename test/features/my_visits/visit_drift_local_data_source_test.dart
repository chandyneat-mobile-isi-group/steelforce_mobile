import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_collection.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_note.dart';

/// Parity tests for the T1.5 visit-capture cutover — the most valuable data in
/// the app (a lost capture is a lost order or an uncollected payment).
///
/// Asserts the **interface contract**, not the implementation (ADR-003 seam,
/// `playbook` §8).
void main() {
  late AppDatabase db;
  late VisitDriftLocalDataSource dataSource;

  const logger = ConsoleAppLogger(verbose: false);
  final day = DateTime.utc(2026, 7, 15);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dataSource = VisitDriftLocalDataSource(db.visitDao, logger);

    // Captures hang off a stop, which hangs off a route and a depot.
    await db.into(db.depots).insert(
          DepotsCompanion.insert(
            id: 'cust-1',
            sapDepotId: Value('SAP-1'),
            depotCode: 'C-1',
            shopName: 'ISI Hardware',
            ownerName: 'Sok Dara',
            phone: '012345678',
            address: 'St 271',
            province: 'PP',
            district: 'TK',
            territory: 'T1',
            latitude: 11.55,
            longitude: 104.91,
            creditLimit: 5000,
            status: 'active',
            assignedRepId: 'rep-1',
            assignedRepName: 'Rep One',
            updatedAt: day,
          ),
        );
    await db.into(db.routes).insert(
          RoutesCompanion.insert(
            id: 'r-1',
            name: 'North loop',
            repId: 'rep-1',
            repName: 'Rep One',
            territory: 'T1',
            visitDate: day,
            plannedStart: day.add(const Duration(hours: 8)),
            plannedEnd: day.add(const Duration(hours: 17)),
            status: 'inProgress',
          ),
        );
    await db.into(db.routeStops).insert(
          RouteStopsCompanion.insert(
            id: 's-1',
            routeId: 'r-1',
            depotId: 'cust-1',
            sequence: 1,
            plannedArrival: Value(day.add(const Duration(hours: 9))),
            plannedDeparture: Value(day.add(const Duration(hours: 10))),
            status: 'pending',
          ),
        );
  });

  tearDown(() => db.close());

  group('check-in / check-out', () {
    test('a check-in round-trips with every field intact', () async {
      await dataSource.insertCheckIn(CheckInRecordModel(
        id: 'ci-1',
        stopId: 's-1',
        timestamp: day.add(const Duration(hours: 9, minutes: 5)),
        latitude: 11.55,
        longitude: 104.91,
        accuracyMeters: 5,
        distanceFromDepotMeters: 12.5,
        isMocked: true,
      ));

      final stored = (await dataSource.fetchPendingCheckIns()).single;
      expect(stored.id, 'ci-1');
      expect(stored.stopId, 's-1');
      expect(stored.accuracyMeters, 5);
      expect(stored.distanceFromDepotMeters, 12.5);
      expect(stored.isMocked, isTrue);
    });

    test('a check-out round-trips', () async {
      await dataSource.insertCheckOut(CheckOutRecordModel(
        id: 'co-1',
        stopId: 's-1',
        timestamp: day.add(const Duration(hours: 10)),
        latitude: 11.55,
        longitude: 104.91,
        durationMinutes: 55,
        visitSummary: 'Order placed',
      ));

      final stored = (await dataSource.fetchPendingCheckOuts()).single;
      expect(stored.durationMinutes, 55);
      expect(stored.visitSummary, 'Order placed');
    });
  });

  group('captures round-trip', () {
    test('an order line keeps the price quoted at the visit', () async {
      await dataSource.insertOrderLine(VisitOrderLineModel(
        id: 'ol-1',
        stopId: 's-1',
        productId: 'p-1',
        productName: 'Rebar 12mm',
        quantity: 10,
        unit: 'pcs',
        unitPrice: 5.5,
      ));

      final stored = (await dataSource.fetchOrderLines('s-1')).single;
      expect(stored.productName, 'Rebar 12mm');
      expect(stored.quantity, 10);
      expect(stored.unitPrice, 5.5);
    });

    test('a collection round-trips its enum method', () async {
      await dataSource.insertCollection(VisitCollectionModel(
        id: 'col-1',
        stopId: 's-1',
        amount: 250.75,
        method: CollectionMethod.bankTransfer,
        reference: 'TRX-9',
        notes: 'partial',
      ));

      final stored = (await dataSource.fetchCollections('s-1')).single;
      expect(stored.amount, 250.75);
      expect(stored.method, CollectionMethod.bankTransfer);
      expect(stored.reference, 'TRX-9');
    });

    test('a note maps text↔body across the column rename', () async {
      await dataSource.insertNote(VisitNoteModel(
        id: 'n-1',
        stopId: 's-1',
        type: VisitNoteType.competitorActivity,
        text: 'Competitor promo running',
        createdAt: day,
      ));

      final stored = (await dataSource.fetchNotes('s-1')).single;
      expect(stored.text, 'Competitor promo running');
      expect(stored.type, VisitNoteType.competitorActivity);
    });

    test('a photo maps url↔path across the column rename', () async {
      await dataSource.insertPhoto(VisitPhotoModel(
        id: 'ph-1',
        stopId: 's-1',
        url: '/data/app/photos/ph-1.jpg',
        caption: 'shelf',
        takenAt: day,
        isSignature: true,
      ));

      final stored = (await dataSource.fetchPhotos('s-1')).single;
      expect(stored.url, '/data/app/photos/ph-1.jpg');
      expect(stored.isSignature, isTrue);
    });

    test('stock updates and returns round-trip', () async {
      await dataSource.insertStockUpdate(VisitStockUpdateModel(
        id: 'su-1',
        stopId: 's-1',
        productId: 'p-1',
        productName: 'Rebar',
        stockLevel: StockLevel.high,
        notes: 'back shelf',
      ));
      await dataSource.insertReturn(VisitReturnModel(
        id: 'rt-1',
        stopId: 's-1',
        productId: 'p-1',
        productName: 'Rebar',
        quantity: 2,
        reason: 'damaged',
      ));

      expect((await dataSource.fetchStockUpdates('s-1')).single.stockLevel,
          StockLevel.high);
      expect((await dataSource.fetchReturns('s-1')).single.reason, 'damaged');
    });

    test('a depot-scoped stock update (no stop) persists and is pending sync',
        () async {
      await dataSource.insertStockUpdate(VisitStockUpdateModel(
        id: 'su-depot-1',
        depotId: 'cust-1',
        productId: 'p-1',
        productName: 'Rebar',
        stockLevel: StockLevel.low,
        notes: '',
      ));

      // Not attached to any stop…
      expect(await dataSource.fetchStockUpdates('s-1'), isEmpty);
      // …but still part of the offline push batch.
      final pending = await dataSource.fetchPendingStockUpdates();
      final depotRow = pending.singleWhere((u) => u.id == 'su-depot-1');
      expect(depotRow.depotId, 'cust-1');
      expect(depotRow.stopId, isNull);
      expect(depotRow.stockLevel, StockLevel.low);
    });

    test('an unknown stop returns empty rather than throwing', () async {
      expect(await dataSource.fetchOrderLines('ghost'), isEmpty);
    });

    test('a capture for a stop sync has not written yet is kept (ADR-011)',
        () async {
      // This used to require a CacheException. Refusing the write meant the
      // note was lost the moment it was typed, for a reason that has nothing
      // to do with the rep: whether route sync had committed the stop row yet.
      //
      // The backend owns this relationship and the note is pushed by `stopId`,
      // so the device stores it and lets the server reconcile.
      await dataSource.insertNote(VisitNoteModel(
        id: 'n-x',
        stopId: 'ghost-stop',
        type: VisitNoteType.general,
        text: 'orphan',
        createdAt: day,
      ));

      final notes = await dataSource.fetchNotes('ghost-stop');
      expect(notes, hasLength(1));
      expect(notes.single.text, 'orphan');
    });
  });

  group('pending / markSynced', () {
    Future<void> seedOne() => dataSource.insertOrderLine(VisitOrderLineModel(
          id: 'ol-1',
          stopId: 's-1',
          productId: 'p-1',
          productName: 'Rebar',
          quantity: 1,
          unit: 'pcs',
          unitPrice: 5,
        ));

    test('a new capture is pending until the server confirms it', () async {
      await seedOne();

      expect(await dataSource.fetchPendingOrderLines(), hasLength(1));
      expect(await dataSource.countPendingVisitRecords(), 1);
    });

    test('markSynced clears the row using the legacy table name', () async {
      await seedOne();

      await dataSource.markSynced(table: 'visit_orders', ids: ['ol-1']);

      expect(await dataSource.fetchPendingOrderLines(), isEmpty);
      expect(await dataSource.countPendingVisitRecords(), 0);
      // The capture itself must remain readable — synced, not deleted.
      expect(await dataSource.fetchOrderLines('s-1'), hasLength(1));
    });

    test('every legacy table name the push batch emits is recognised',
        () async {
      // These are the exact keys `visit_push_batch.dart#idsByTable` produces.
      // If a rename ever breaks the mapping, this fails instead of rows being
      // silently re-pushed forever.
      const names = [
        'checkins',
        'checkouts',
        'visit_orders',
        'visit_stock_updates',
        'visit_returns',
        'visit_collections',
        'visit_notes',
        'visit_photos',
      ];

      for (final name in names) {
        // Empty id list is a no-op but still validates the name mapping.
        await dataSource.markSynced(table: name, ids: const []);
        await expectLater(
          dataSource.markSynced(table: name, ids: const ['nonexistent']),
          completes,
          reason: '$name must map to a known capture table',
        );
      }
    });

    test('an unknown table name throws instead of silently doing nothing',
        () async {
      // The legacy version issued an UPDATE against a missing table and
      // affected nothing — rows stayed dirty and were re-pushed forever.
      expect(
        () => dataSource.markSynced(table: 'visit_teleports', ids: ['x']),
        throwsA(isA<CacheException>()),
      );
    });

    test('markSynced with no ids is a no-op', () async {
      await seedOne();

      await dataSource.markSynced(table: 'visit_orders', ids: const []);

      expect(await dataSource.fetchPendingOrderLines(), hasLength(1));
    });

    test('countPendingVisitRecords sums across capture tables', () async {
      await seedOne();
      await dataSource.insertNote(VisitNoteModel(
        id: 'n-1',
        stopId: 's-1',
        type: VisitNoteType.general,
        text: 'note',
        createdAt: day,
      ));
      await dataSource.insertCollection(VisitCollectionModel(
        id: 'col-1',
        stopId: 's-1',
        amount: 10,
        method: CollectionMethod.cash,
        reference: '',
        notes: '',
      ));

      expect(await dataSource.countPendingVisitRecords(), 3);
    });
  });
}
