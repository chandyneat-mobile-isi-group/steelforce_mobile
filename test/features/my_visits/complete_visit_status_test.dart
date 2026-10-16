import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/location_sample_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
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

/// The field report: **Complete Visit leaves the stop card on "In Progress".**
///
/// "In Progress" is `stop_card.dart`'s label for [VisitStatus.checkedIn], and
/// "Visited" is its label for [VisitStatus.checkedOut] — so the card was
/// telling the truth. The check-out genuinely never happened.
///
/// The chain, all of it upstream of the button:
///
/// ```text
/// _onLoad emits dayStarted: false      (hardcoded, even for a running route)
///        ↓
/// _persistWorkflow returns early        (gated on dayStarted)
///        ↓
/// no active_workflow row
///        ↓
/// CompleteVisitCheckOut → noActiveWorkflow → skipped
///        ↓
/// no check-out row, no status write → the card stays "In Progress"
/// ```
///
/// Every step is silent, and the check-in immediately before it succeeds and
/// pushes — which is why the log showed `POST /push status=200` and the screen
/// still looked stuck.
void main() {
  late AppDatabase db;
  late RouteRepositoryImpl routes;
  late VisitRepositoryImpl visits;
  late VisitDriftLocalDataSource visitLocal;
  late ActiveWorkflowRepositoryImpl workflows;
  late CompleteVisitCheckOut completeVisit;

  const logger = ConsoleAppLogger(verbose: false);
  const routeId = 'route-1';
  const stopA = 'stop-1';
  const stopB = 'stop-2';

  Future<void> build({required RouteStatus routeStatus}) async {
    db = AppDatabase(NativeDatabase.memory());
    visitLocal = VisitDriftLocalDataSource(db.visitDao, logger);
    routes =
        RouteRepositoryImpl(RouteDriftLocalDataSource(db.routeDao, logger));
    visits = VisitRepositoryImpl(visitLocal);
    workflows = ActiveWorkflowRepositoryImpl(
        WorkflowStateLocalDataSourceImpl(db.workflowStateDao));
    completeVisit = CompleteVisitCheckOut(
        workflows, routes, CheckOut(visits), UpdateStopStatus(routes));

    await _seed(db, routeId: routeId, status: routeStatus);
  }

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

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 40));

  Future<VisitStatus> statusOf(String stopId) async {
    final r = await routes.getRoute(routeId);
    return r
        .when(success: (route) => route, failure: (_) => null)!
        .stops
        .firstWhere((s) => s.id == stopId)
        .status;
  }

  Future<String?> pointerStopId() async {
    final r = await workflows.getActiveWorkflow();
    return r.when(success: (w) => w?.currentStopId, failure: (_) => null);
  }

  /// The entry the bug arrived through: Stop Dashboard → Stop Information →
  /// Check-in. Nothing on that path taps **Start Day**.
  Future<ActiveRouteBloc> checkInWithoutStartDay(int stopIndex) async {
    final bloc = buildBloc()..add(const ActiveRouteLoadRequested(routeId));
    addTearDown(bloc.close);
    await settle();

    bloc
      ..add(StopSelected(stopIndex))
      ..add(const GeofenceStatusChanged(
        insideGeofence: true,
        distanceMeters: 10,
        accuracyMeters: 8,
        isMocked: false,
        latitude: 11.55,
        longitude: 104.91,
      ));
    await settle();

    bloc.add(const CheckInRequested());
    await settle();
    return bloc;
  }

  group('a visit opened without tapping Start Day', () {
    setUp(() => build(routeStatus: RouteStatus.published));

    test('the check-in itself always worked — that was never the problem',
        () async {
      await checkInWithoutStartDay(0);

      expect(await statusOf(stopA), VisitStatus.checkedIn);
      expect(await visitLocal.fetchPendingCheckIns(), hasLength(1),
          reason: 'this is the row whose push returned 200');
    });

    test('it now leaves a resume pointer behind', () async {
      await checkInWithoutStartDay(0);

      // The missing link. Without this row `CompleteVisitCheckOut` has no way
      // to know which stop it is meant to close.
      expect(await pointerStopId(), stopA);
    });

    test('Complete Visit closes it — the card reads Visited, not In Progress',
        () async {
      await checkInWithoutStartDay(0);

      final result = await completeVisit(null);

      expect(result.when(success: (c) => c, failure: (_) => false), isTrue);
      expect(await statusOf(stopA), VisitStatus.checkedOut,
          reason: 'stop_card renders checkedOut as "Visited"');
      expect(await visitLocal.fetchPendingCheckOuts(), hasLength(1),
          reason: 'and there is a row for POST /push to carry');
      expect(await pointerStopId(), isNull, reason: 'the visit is closed');
    });
  });

  group('reloading a route that is already running', () {
    setUp(() => build(routeStatus: RouteStatus.inProgress));

    test('the day is read back from the route, not assumed to be over',
        () async {
      // `StartDayRequested` persists `RouteStatus.inProgress`, so the route is
      // the durable record. `_onLoad` used to emit a hardcoded `false` and
      // throw that away on every reload.
      final bloc = buildBloc()..add(const ActiveRouteLoadRequested(routeId));
      addTearDown(bloc.close);
      await settle();

      expect((bloc.state as ActiveRouteReady).dayStarted, isTrue);
    });
  });

  group('selecting a second stop while a visit is open', () {
    setUp(() => build(routeStatus: RouteStatus.published));

    test('does not wipe the live visit’s pointer', () async {
      final bloc = await checkInWithoutStartDay(0);
      expect(await pointerStopId(), stopA);

      // Browsing another stop on the same route is not a decision to abandon
      // the one in progress — but it used to clear the pointer, which put the
      // visit back in the state this whole file exists to prevent.
      bloc.add(const StopSelected(1));
      await settle();

      expect(await pointerStopId(), stopA);
      expect(await statusOf(stopB), VisitStatus.pending);
    });

    test('and Complete Visit still closes the right stop', () async {
      final bloc = await checkInWithoutStartDay(0);
      bloc.add(const StopSelected(1));
      await settle();

      await completeVisit(null);

      expect(await statusOf(stopA), VisitStatus.checkedOut);
      expect(await statusOf(stopB), VisitStatus.pending,
          reason: 'the stop merely looked at is untouched');
    });
  });

  group('nothing open', () {
    setUp(() => build(routeStatus: RouteStatus.published));

    test('selecting a stop with no visit in flight clears the pointer',
        () async {
      // The original behaviour, still wanted: the guard added above narrows
      // when the pointer is cleared, it does not stop it being cleared.
      final bloc = buildBloc()..add(const ActiveRouteLoadRequested(routeId));
      addTearDown(bloc.close);
      await settle();

      bloc
        ..add(const StartDayRequested())
        ..add(const StopSelected(0));
      await settle();

      expect(await pointerStopId(), isNull,
          reason: 'a pending stop is not a visit to resume');
    });
  });
}

Future<void> _seed(
  AppDatabase db, {
  required String routeId,
  required RouteStatus status,
}) async {
  final now = DateTime.now().toUtc();
  final day = DateTime.utc(now.year, now.month, now.day);

  for (final (id, code, name) in const [
    ('cust-1', 'C-1', 'ISI Hardware'),
    ('cust-2', 'C-2', 'Mekong Steel'),
  ]) {
    await db.into(db.depots).insert(DepotsCompanion.insert(
          id: id,
          sapDepotId: Value('SAP-$code'),
          depotCode: code,
          shopName: name,
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
  }

  await db.into(db.routes).insert(RoutesCompanion.insert(
        id: routeId,
        name: 'Route 1',
        repId: 'rep-1',
        repName: 'Rep One',
        territory: 'PP-CENTRAL',
        visitDate: day,
        plannedStart: day.add(const Duration(hours: 8)),
        plannedEnd: day.add(const Duration(hours: 17)),
        // Persisted by enum name — see `RouteRowMapper` in
        // `route_drift_mappers.dart`.
        status: status.name,
      ));

  for (final (index, stopId, depotId) in const [
    (1, 'stop-1', 'cust-1'),
    (2, 'stop-2', 'cust-2'),
  ]) {
    await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
          id: stopId,
          routeId: routeId,
          depotId: depotId,
          sequence: index,
          plannedArrival: Value(day.add(Duration(hours: 8 + index))),
          plannedDeparture: Value(day.add(Duration(hours: 9 + index))),
          status: 'pending',
        ));
  }
}
