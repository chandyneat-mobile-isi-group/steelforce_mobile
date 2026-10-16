import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/clear_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/complete_visit_check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/usecases/save_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_route_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/events/active_route_event.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';
import 'package:steelforce/features/my_visits/data/repositories/location_sample_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_drift_local_data_source.dart';

/// Reproduces the field report: tapping **Complete Visit** logs
/// `visit.checkout.skipped reason=noActiveWorkflow` and makes no `POST /push`.
///
/// The cause is upstream of that button. `StopsCheckInScreen._submit` does:
///
/// ```dart
/// bloc.add(const CheckInRequested());   // fire-and-forget
/// _goToVisit(context, stop);            // navigates immediately
/// ```
///
/// so the guided flow advances to the stock count whether or not the check-in
/// was *accepted*. And `FraudDetectionService.validateCheckIn` refuses it
/// outright when the rep is outside the geofence or GPS accuracy is worse than
/// 30 m — the normal case on a simulator, or anywhere but the shopfront.
///
/// The rep then walks Inventory → Completion → "Complete Visit" on a visit that
/// was never opened. Every symptom in the log follows from that.
void main() {
  late AppDatabase db;
  late RouteRepositoryImpl routes;
  late VisitRepositoryImpl visits;
  late VisitDriftLocalDataSource visitLocal;
  late ActiveWorkflowRepositoryImpl workflows;
  late CompleteVisitCheckOut completeVisit;

  const logger = ConsoleAppLogger(verbose: false);
  const routeId = 'route-1';
  const stopId = 'stop-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final routeLocal = RouteDriftLocalDataSource(db.routeDao, logger);
    visitLocal = VisitDriftLocalDataSource(db.visitDao, logger);
    routes = RouteRepositoryImpl(routeLocal);
    visits = VisitRepositoryImpl(visitLocal);
    workflows = ActiveWorkflowRepositoryImpl(
        WorkflowStateLocalDataSourceImpl(db.workflowStateDao));
    completeVisit = CompleteVisitCheckOut(
        workflows, routes, CheckOut(visits), UpdateStopStatus(routes));

    await _seed(db, routeId: routeId, stopId: stopId);
  });
  tearDown(() => db.close());

  ActiveRouteBloc buildBloc() => ActiveRouteBloc(
        saveActiveWorkflow: SaveActiveWorkflow(workflows),
        clearActiveWorkflow: ClearActiveWorkflow(workflows),
        getActiveWorkflow: GetActiveWorkflow(workflows),
        getRoute: GetRoute(routes),
        updateRouteStatus: UpdateRouteStatus(routes),
        updateStopStatus: UpdateStopStatus(routes),
        checkIn: CheckIn(visits),
        checkOut: CheckOut(visits),
        recordFraudFlag: RecordFraudFlag(LocationSampleRepositoryImpl(
            LocationSampleDriftLocalDataSource(db.routeTelemetryDao))),
        fraudDetectionService: const FraudDetectionService(),
      );

  /// Drives the bloc to the state the check-in screen shows, with the geofence
  /// verdict the caller wants.
  Future<ActiveRouteBloc> readyAtStop({
    required bool insideGeofence,
    double accuracyMeters = 8,
  }) async {
    final bloc = buildBloc()..add(const ActiveRouteLoadRequested(routeId));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    bloc
      ..add(const StartDayRequested())
      ..add(const StopSelected(0))
      ..add(GeofenceStatusChanged(
          insideGeofence: insideGeofence,
          distanceMeters: insideGeofence ? 10 : 900,
          accuracyMeters: accuracyMeters,
          isMocked: false,
          latitude: 11.55,
          longitude: 104.91));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return bloc;
  }

  Future<VisitStatus> stopStatus() async {
    final r = await routes.getRoute(routeId);
    return r
        .when(success: (route) => route, failure: (_) => null)!
        .stops
        .firstWhere((s) => s.id == stopId)
        .status;
  }

  group('check-in refused because the rep is outside the geofence', () {
    test('writes nothing and leaves no resume pointer', () async {
      final bloc = await readyAtStop(insideGeofence: false);
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = bloc.state as ActiveRouteReady;
      expect(state.blockedCheckInReason, isNotNull,
          reason: 'the bloc knows it refused');
      expect(await stopStatus(), VisitStatus.pending,
          reason: 'the stop never opens');

      final pointer = await workflows.getActiveWorkflow();
      expect(pointer.when(success: (w) => w, failure: (_) => null), isNull,
          reason: 'no resume pointer — this is what "Complete Visit" needs');
    });

    test('Complete Visit then no-ops exactly as the field log shows', () async {
      final bloc = await readyAtStop(insideGeofence: false);
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The rep has meanwhile walked Inventory → Completion and tapped the
      // button. This is the reported behaviour, reproduced.
      final result = await completeVisit(null);

      expect(result.when(success: (c) => c, failure: (_) => true), isFalse,
          reason: 'reports "nothing completed" — reason=noActiveWorkflow');
      expect(await visitLocal.fetchPendingCheckOuts(), isEmpty,
          reason: 'nothing queued, so the push makes no request at all');
      expect(await stopStatus(), VisitStatus.pending,
          reason: 'the outlet still reads as not visited');
    });

    test('poor GPS accuracy refuses it the same way', () async {
      // Inside the geofence, but the fix is worse than the 30 m policy limit.
      final bloc = await readyAtStop(insideGeofence: true, accuracyMeters: 120);
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect((bloc.state as ActiveRouteReady).blockedCheckInReason, isNotNull);
      expect(await stopStatus(), VisitStatus.pending);
    });
  });

  group('the same flow with an accepted check-in', () {
    test('opens the visit, so Complete Visit has something to close', () async {
      final bloc = await readyAtStop(insideGeofence: true);
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested());
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect((bloc.state as ActiveRouteReady).blockedCheckInReason, isNull);
      expect(await stopStatus(), VisitStatus.checkedIn);

      final pointer = await workflows.getActiveWorkflow();
      final workflow = pointer.when(success: (w) => w, failure: (_) => null);
      expect(workflow, isNotNull);
      expect(workflow!.currentStopId, stopId,
          reason: 'the pointer names the stop Complete Visit will close');

      // And now the button does what it says.
      final result = await completeVisit(null);
      expect(result.when(success: (c) => c, failure: (_) => false), isTrue);
      expect(await stopStatus(), VisitStatus.checkedOut);
      expect(await visitLocal.fetchPendingCheckOuts(), hasLength(1),
          reason: 'now there is a row for POST /push to send');
    });
  });

  group('the bloc must be told which stop', () {
    test('an unloaded bloc silently discards the check-in', () async {
      // The shipped bug: entering via Stop Dashboard -> Stop Information ->
      // Check-in dispatched neither `ActiveRouteLoadRequested` nor
      // `StopSelected`, so the bloc never reached `ActiveRouteReady` with a
      // stop. `_onCheckIn` returned on its first guard — no row written — and
      // the screen's own settle-listener returned on the same guard, so the CTA
      // span forever.
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.state, isNot(isA<ActiveRouteReady>()),
          reason: 'never loaded, so never ready');
      expect(await visitLocal.fetchPendingCheckIns(), isEmpty,
          reason: 'nothing to push — the accepted row was an older one');
      expect(await stopStatus(), VisitStatus.pending);
    });

    test('loaded and selected, the check-in lands', () async {
      // What `_ensureStopSelected` now guarantees before the CTA is usable.
      final bloc = buildBloc()..add(const ActiveRouteLoadRequested(routeId));
      addTearDown(bloc.close);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(bloc.state, isA<ActiveRouteReady>());
      expect((bloc.state as ActiveRouteReady).hasCurrentStop, isFalse,
          reason: 'loading alone does not select a stop');

      bloc.add(const StopSelected(0));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect((bloc.state as ActiveRouteReady).hasCurrentStop, isTrue);

      bloc.add(const CheckInRequested());
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(await stopStatus(), VisitStatus.checkedIn);
      expect(await visitLocal.fetchPendingCheckIns(), hasLength(1),
          reason: 'a real row for POST /push to carry');
    });
  });
}

Future<void> _seed(
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
        territory: 'PP-CENTRAL',
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
        territory: 'PP-CENTRAL',
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
