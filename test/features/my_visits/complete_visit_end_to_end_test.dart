import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_out.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_repository.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_out_outcome.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';

/// What "Complete Visit" is supposed to do, run against a real database.
///
/// The button reported as doing nothing: no `POST /push` and the outlet still
/// showing as not visited. Both symptoms have one shared cause if the
/// check-out never writes — an empty pending queue means the push short-circuits
/// without a request, and no status write means the stop card never changes.
///
/// `CompleteVisitCheckOut` has three silent early-returns. These tests pin down
/// which preconditions it actually needs.
void main() {
  late AppDatabase db;
  late RouteDriftLocalDataSource routeLocal;
  late VisitDriftLocalDataSource visitLocal;
  late RouteRepositoryImpl routes;
  late VisitRepositoryImpl visits;
  late ActiveWorkflowRepositoryImpl workflows;
  late CompleteVisitCheckOut completeVisit;

  const logger = ConsoleAppLogger(verbose: false);
  const routeId = 'route-1';
  const stopId = 'stop-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    routeLocal = RouteDriftLocalDataSource(db.routeDao, logger);
    visitLocal = VisitDriftLocalDataSource(db.visitDao, logger);
    routes = RouteRepositoryImpl(routeLocal);
    visits = VisitRepositoryImpl(visitLocal);
    workflows = ActiveWorkflowRepositoryImpl(
        WorkflowStateLocalDataSourceImpl(db.workflowStateDao));

    completeVisit = CompleteVisitCheckOut(
      workflows,
      routes,
      CheckOut(visits),
      UpdateStopStatus(routes),
    );

    await _seedRouteWithStop(db, routeId: routeId, stopId: stopId);
  });
  tearDown(() => db.close());

  /// Puts the world in the state the guided flow leaves behind after a
  /// check-in: the stop is `checkedIn` and the resume pointer names it.
  Future<void> checkIn() async {
    await visits.checkIn(CheckInRecord(
      id: 'ci-1',
      stopId: stopId,
      timestamp: DateTime.now(),
      latitude: 11.55,
      longitude: 104.91,
      accuracyMeters: 8,
      distanceFromDepotMeters: 20,
      isMocked: false,
    ));
    await routes.updateStopStatus(stopId,
        status: VisitStatus.checkedIn, actualArrival: DateTime.now());
    await workflows.saveActiveWorkflow(ActiveWorkflow(
      routeId: routeId,
      currentStopId: stopId,
      dayStarted: true,
      updatedAt: DateTime.now(),
    ));
  }

  Future<VisitStatus> stopStatus() async {
    final route = await routeLocal.getRoute(routeId);
    return route!.stops.firstWhere((s) => s.id == stopId).status;
  }

  group('with the rep\'s answer (check-in-check-out-mobile.md §5)', () {
    test('without order: saves the reason and closes this check-in', () async {
      await checkIn();
      final sent = <CheckOutRecord>[];
      final withSend = CompleteVisitCheckOut(
        workflows,
        routes,
        CheckOut(visits),
        UpdateStopStatus(routes),
        null,
        null,
        visits,
        _RecordingSend(sent),
      );

      await withSend(const CheckOutChoice.withoutOrder(
          reason: 'other', noOrderNote: 'Owner travelling'));

      final saved = (await visitLocal.fetchPendingCheckOuts()).single;
      expect(saved.outcome, CheckOutOutcome.withoutOrder);
      expect(saved.noOrderReason, 'other');
      expect(saved.noOrderNote, 'Owner travelling');
      expect(saved.checkInId, 'ci-1');
      expect(await stopStatus(), VisitStatus.checkedOut,
          reason: 'status written before the send');
      expect(sent.single.id, saved.id, reason: 'offered to the server once');
    });

    test('with order: saves which orders', () async {
      await checkIn();
      await completeVisit(const CheckOutChoice.withOrder(
          [VisitOrderRef(clientId: 'qt-1', quotationId: 'srv-1')]));

      final saved = (await visitLocal.fetchPendingCheckOuts()).single;
      expect(saved.outcome, CheckOutOutcome.withOrder);
      expect(saved.orders.single.clientId, 'qt-1');
    });
  });

  group('after a normal check-in', () {
    test('writes a check-out, flips the stop, and queues it for push',
        () async {
      await checkIn();

      final result = await completeVisit(null);

      expect(result.when(success: (c) => c, failure: (_) => false), isTrue);

      // 1. The outlet reads as done. `checkedOut`'s label is "Completed".
      expect(await stopStatus(), VisitStatus.checkedOut);

      // 2. There is something for the push to send. An empty queue is exactly
      //    why no HTTP request would be made.
      final pending = await visitLocal.fetchPendingCheckOuts();
      expect(pending, hasLength(1));
      expect(pending.single.stopId, stopId);

      // 3. The resume pointer is gone, so the visit does not reappear.
      final pointer = await workflows.getActiveWorkflow();
      expect(pointer.when(success: (w) => w, failure: (_) => null), isNull);
    });

    test('is idempotent — a second tap writes nothing more', () async {
      await checkIn();
      await completeVisit(null);
      await completeVisit(null);

      expect(await visitLocal.fetchPendingCheckOuts(), hasLength(1));
    });
  });

  group('the silent no-op paths', () {
    test('no resume pointer: nothing is written at all', () async {
      // The stop is checked in, but no pointer names it — so the use case has
      // nothing to work from. This is the shape that produces *both* reported
      // symptoms at once.
      await visits.checkIn(CheckInRecord(
        id: 'ci-1',
        stopId: stopId,
        timestamp: DateTime.now(),
        latitude: 11.55,
        longitude: 104.91,
        accuracyMeters: 8,
        distanceFromDepotMeters: 20,
        isMocked: false,
      ));
      await routes.updateStopStatus(stopId,
          status: VisitStatus.checkedIn, actualArrival: DateTime.now());

      final result = await completeVisit(null);

      expect(result.when(success: (c) => c, failure: (_) => true), isFalse,
          reason: 'reports "nothing completed"');
      expect(await stopStatus(), VisitStatus.checkedIn,
          reason: 'the outlet never moves off Checked In');
      expect(await visitLocal.fetchPendingCheckOuts(), isEmpty,
          reason: 'nothing queued, so a push would make no request');
    });

    test('pointer without a currentStopId: nothing is written', () async {
      await routes.updateStopStatus(stopId,
          status: VisitStatus.checkedIn, actualArrival: DateTime.now());
      await workflows.saveActiveWorkflow(ActiveWorkflow(
        routeId: routeId,
        currentStopId: null, // never set — e.g. saved outside the check-in path
        dayStarted: true,
        updatedAt: DateTime.now(),
      ));

      await completeVisit(null);

      expect(await stopStatus(), VisitStatus.checkedIn);
      expect(await visitLocal.fetchPendingCheckOuts(), isEmpty);
    });

    test('stop not checked in: treated as already resolved', () async {
      // `pending` — the rep reached the completion screen without the stop
      // ever being flipped to checkedIn.
      await workflows.saveActiveWorkflow(ActiveWorkflow(
        routeId: routeId,
        currentStopId: stopId,
        dayStarted: true,
        updatedAt: DateTime.now(),
      ));

      await completeVisit(null);

      expect(await stopStatus(), VisitStatus.pending,
          reason: 'the outlet is left exactly as it was');
      expect(await visitLocal.fetchPendingCheckOuts(), isEmpty);
    });
  });

  group('the live stream the dashboard listens to', () {
    test('re-emits after the status write, so the card can refresh', () async {
      await checkIn();

      final seen = <VisitStatus>[];
      final sub = routes.watchAllRoutes().listen((list) {
        for (final r in list) {
          for (final s in r.stops) {
            if (s.id == stopId) seen.add(s.status);
          }
        }
      });
      // Let the initial snapshot land before mutating.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await completeVisit(null);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(seen.first, VisitStatus.checkedIn, reason: 'initial snapshot');
      expect(seen.last, VisitStatus.checkedOut,
          reason: 'a listening dashboard is told the outlet is done');
    });
  });
}

/// One route with one stop, and the depot row its FK needs.
Future<void> _seedRouteWithStop(
  AppDatabase db, {
  required String routeId,
  required String stopId,
}) async {
  final now = DateTime.now().toUtc();
  final day = DateTime.utc(now.year, now.month, now.day);

  await db.into(db.depots).insert(DepotsCompanion.insert(
        id: 'cust-1',
        sapDepotId: const Value('SAP-1'),
        depotCode: 'C-1',
        shopName: 'ISI Hardware',
        ownerName: 'Sok Dara',
        phone: '012345678',
        address: 'St 271',
        province: 'Phnom Penh',
        district: 'TK',
        territory: 'PP-NORTH',
        latitude: 11.55,
        longitude: 104.91,
        creditLimit: 5000,
        status: 'active',
        assignedRepId: 'rep-1',
        assignedRepName: 'Rep One',
        updatedAt: now,
        territoryType: const Value('urban'),
      ));

  await db.into(db.routes).insert(RoutesCompanion.insert(
        id: routeId,
        name: 'Route 1',
        repId: 'rep-1',
        repName: 'Rep One',
        territory: 'PP-NORTH',
        visitDate: day,
        plannedStart: day.add(const Duration(hours: 8)),
        plannedEnd: day.add(const Duration(hours: 17)),
        status: 'published',
      ));

  await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
        id: stopId,
        routeId: routeId,
        depotId: 'cust-1',
        sequence: 1,
        plannedArrival: Value(day.add(const Duration(hours: 9))),
        plannedDeparture: Value(day.add(const Duration(hours: 10))),
        status: 'pending',
      ));
}

class _RecordingSend extends SendCheckOut {
  _RecordingSend(this.sent) : super(_NoRepository());
  final List<CheckOutRecord> sent;

  @override
  ResultFuture<VisitSendResult> call(CheckOutRecord params) async {
    sent.add(params);
    return const Success(VisitSendResult.queued());
  }
}

class _NoRepository implements VisitRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
