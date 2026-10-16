import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/location_sample_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/services/fraud_detection_service.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_in.dart';
import 'package:steelforce/features/my_visits/domain/usecases/check_out.dart';
import 'package:steelforce/features/my_visits/domain/usecases/clear_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route.dart';
import 'package:steelforce/features/my_visits/domain/usecases/record_fraud_flag.dart';
import 'package:steelforce/features/my_visits/domain/usecases/save_active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_route_status.dart';
import 'package:steelforce/features/my_visits/domain/usecases/update_stop_status.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/active_route_bloc.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/events/active_route_event.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/active_route_state.dart';

/// Pins the route state machine end to end, against a real in-memory
/// database: the transitions after check-in, the override-reason rules and
/// the "Continue Working" resume pointer.
void main() {
  late AppDatabase db;
  late RouteRepositoryImpl routes;
  late ActiveWorkflowRepositoryImpl workflows;
  late _RecordedFlags flags;

  const logger = ConsoleAppLogger(verbose: false);
  const routeId = 'route-1';
  const reason = 'Shop moved across the road';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    routes =
        RouteRepositoryImpl(RouteDriftLocalDataSource(db.routeDao, logger));
    workflows = ActiveWorkflowRepositoryImpl(
        WorkflowStateLocalDataSourceImpl(db.workflowStateDao));
    flags = _RecordedFlags(LocationSampleRepositoryImpl(
        LocationSampleDriftLocalDataSource(db.routeTelemetryDao)));
    await _seed(db, routeId: routeId);
  });
  tearDown(() => db.close());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 60));

  Future<ActiveRouteBloc> ready() async {
    final visits =
        VisitRepositoryImpl(VisitDriftLocalDataSource(db.visitDao, logger));
    final bloc = ActiveRouteBloc(
      saveActiveWorkflow: SaveActiveWorkflow(workflows),
      clearActiveWorkflow: ClearActiveWorkflow(workflows),
      getActiveWorkflow: GetActiveWorkflow(workflows),
      getRoute: GetRoute(routes),
      updateRouteStatus: UpdateRouteStatus(routes),
      updateStopStatus: UpdateStopStatus(routes),
      checkIn: CheckIn(visits),
      checkOut: CheckOut(visits),
      recordFraudFlag: flags,
      fraudDetectionService: const FraudDetectionService(),
    )..add(const ActiveRouteLoadRequested(routeId));
    addTearDown(bloc.close);
    await settle();
    return bloc;
  }

  GeofenceStatusChanged position({
    bool inside = true,
    bool mocked = false,
  }) =>
      GeofenceStatusChanged(
        insideGeofence: inside,
        distanceMeters: inside ? 10 : 400,
        accuracyMeters: 8,
        isMocked: mocked,
        latitude: 11.55,
        longitude: 104.91,
      );

  /// Selects stop [index], reports [at] (or nothing, with [noFix]) and
  /// checks in.
  Future<void> checkInAt(ActiveRouteBloc bloc, int index,
      {GeofenceStatusChanged? at,
      bool noFix = false,
      String? overrideReason}) async {
    bloc.add(StopSelected(index));
    if (!noFix) bloc.add(at ?? position());
    await settle();
    bloc.add(CheckInRequested(
        stopId: 'stop-${index + 1}', overrideReason: overrideReason));
    await settle();
  }

  ActiveRouteReady readyState(ActiveRouteBloc bloc) =>
      bloc.state as ActiveRouteReady;
  VisitStatus stateStatus(ActiveRouteBloc bloc, int i) =>
      readyState(bloc).route.stops[i].status;

  Future<RoutePlan> stored() async => (await routes.getRoute(routeId))
      .when(success: (r) => r, failure: (f) => fail('$f'));
  Future<ActiveWorkflow?> pointer() async =>
      (await workflows.getActiveWorkflow())
          .when(success: (w) => w, failure: (_) => null);

  group('after check-in', () {
    test('check-out marks the stop checked out and drops the pointer',
        () async {
      final bloc = await ready();
      bloc.add(const StartDayRequested());
      await settle();
      await checkInAt(bloc, 0);
      expect(await pointer(), isNotNull);

      bloc.add(const CheckOutRequested('Ordered rebar'));
      await settle();

      expect(stateStatus(bloc, 0), VisitStatus.checkedOut);
      expect((await stored()).stops[0].status, VisitStatus.checkedOut);
      expect(await pointer(), isNull, reason: 'no live visit left');
    });

    // Current behaviour, pinned as-is: before Start Day the bloc writes the
    // pointer only for a checked-in stop, so its own check-out leaves it for
    // `CompleteVisitCheckOut` to close.
    test('check-out before Start Day leaves the pointer alone', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0);

      bloc.add(const CheckOutRequested('Ordered rebar'));
      await settle();

      expect(stateStatus(bloc, 0), VisitStatus.checkedOut);
      expect((await pointer())?.currentStopId, 'stop-1');
    });

    test('check-out does nothing for a stop that is not checked in', () async {
      final bloc = await ready();
      bloc.add(const StopSelected(0));
      await settle();
      final before = readyState(bloc);

      bloc.add(const CheckOutRequested('x'));
      await settle();

      expect(readyState(bloc), before);
      expect((await stored()).stops[0].status, VisitStatus.pending);
    });
  });

  group('moving along the route', () {
    test('next stop marks an unvisited stop missed and moves on', () async {
      final bloc = await ready();
      bloc.add(const StopSelected(0));
      await settle();

      bloc.add(const NextStopRequested());
      await settle();

      expect(stateStatus(bloc, 0), VisitStatus.missed);
      expect((await stored()).stops[0].status, VisitStatus.missed);
      expect(readyState(bloc).currentStopIndex, 1);
      expect(readyState(bloc).insideGeofence, isFalse);
    });

    test('next stop on the last stop stays on it', () async {
      final bloc = await ready();
      bloc.add(const StopSelected(1));
      await settle();

      bloc.add(const NextStopRequested());
      await settle();

      expect(readyState(bloc).currentStopIndex, 1);
      expect(stateStatus(bloc, 1), VisitStatus.missed);
    });

    test('skip marks the stop missed and keeps the reason', () async {
      final bloc = await ready();

      bloc.add(const SkipStopRequested(index: 1, reason: 'Shop closed'));
      await settle();

      expect(stateStatus(bloc, 1), VisitStatus.missed);
      expect(readyState(bloc).skipReasons, {'stop-2': 'Shop closed'});
      expect((await stored()).stops[1].status, VisitStatus.missed);
      expect(readyState(bloc).currentStopIndex, -1,
          reason: 'skipping does not move the pointer');
    });

    test('skip ignores a resolved stop and an index out of range', () async {
      final bloc = await ready();
      bloc.add(const SkipStopRequested(index: 1, reason: 'first'));
      await settle();

      bloc
        ..add(const SkipStopRequested(index: 1, reason: 'second'))
        ..add(const SkipStopRequested(index: 7, reason: 'nope'));
      await settle();

      expect(readyState(bloc).skipReasons, {'stop-2': 'first'});
    });

    test('end day completes the route and drops the pointer', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0);

      bloc.add(const EndDayRequested());
      await settle();

      expect(bloc.state, isA<ActiveRouteCompleted>());
      expect((bloc.state as ActiveRouteCompleted).route.status,
          RouteStatus.completed);
      expect((await stored()).status, RouteStatus.completed);
      expect(await pointer(), isNull);
    });
  });

  group('check-in rules', () {
    test('outside the geofence: refused, with a reason on offer', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0, at: position(inside: false));

      final state = readyState(bloc);
      expect(
          state.blockedCheckInReason, "You're outside the depot's geofence.");
      expect(state.checkInOverridable, isTrue);
      expect(stateStatus(bloc, 0), VisitStatus.pending);
      expect(flags.recorded, isEmpty);
    });

    test('a reason too short to be meant does not get past it', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0,
          at: position(inside: false), overrideReason: '  too short ');

      expect(readyState(bloc).blockedCheckInReason, isNotNull);
      expect(stateStatus(bloc, 0), VisitStatus.pending);
    });

    test('a written reason checks in outside, and is flagged', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0,
          at: position(inside: false), overrideReason: '  $reason  ');

      final state = readyState(bloc);
      expect(stateStatus(bloc, 0), VisitStatus.checkedIn);
      expect(state.blockedCheckInReason, isNull);
      expect(state.checkInWarnings,
          ['Checked in outside the geofence. Reason: $reason']);
      expect(flags.recorded.single.type, FraudFlagType.reasonedOverride);
      expect(flags.recorded.single.detail,
          "You're outside the depot's geofence. Reason: $reason");
      expect(flags.recorded.single.stopId, 'stop-1');
    });

    test('no GPS fix: checked in as unverified, and a given reason is kept',
        () async {
      final bloc = await ready();
      await checkInAt(bloc, 0, noFix: true, overrideReason: reason);

      expect(stateStatus(bloc, 0), VisitStatus.checkedIn);
      expect(readyState(bloc).checkInWarnings, [
        'No GPS fix yet — this check-in is recorded as unverified.',
        'Checked in without location verification. Reason: $reason',
      ]);
      expect(flags.recorded.single.type, FraudFlagType.reasonedOverride);
      expect(flags.recorded.single.detail, 'No GPS fix. Reason: $reason');
    });

    test('a simulated location is allowed in a debug build, and flagged',
        () async {
      final bloc = await ready();
      await checkInAt(bloc, 0, at: position(mocked: true));

      expect(stateStatus(bloc, 0), VisitStatus.checkedIn);
      expect(readyState(bloc).checkInWarnings,
          ['Simulated location detected (allowed in this build).']);
      expect(flags.recorded.single.type, FraudFlagType.mockLocation);
    });
  });

  group('the resume pointer', () {
    test('a fresh check-in resumes at the stock count', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0);

      final p = (await pointer())!;
      expect(p.currentStopId, 'stop-1');
      expect(p.currentWorkflow, VisitWorkflow.stockCount);
      expect(p.currentScreen, 'my-visits-inventory-visibility');
      expect(p.navigationArguments, {
        'stopId': 'stop-1',
        'depotId': 'cust-1',
        'depotName': 'ISI Hardware',
        'territory': 'PP-CENTRAL',
      });
      expect(p.shopName, 'ISI Hardware');
    });

    test('a later route event never downgrades a business task', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0);
      final p = (await pointer())!;
      await workflows.saveActiveWorkflow(ActiveWorkflow(
        routeId: p.routeId,
        currentStopId: 'stop-1',
        dayStarted: p.dayStarted,
        updatedAt: DateTime.now(),
        currentWorkflow: VisitWorkflow.quotation,
        currentScreen: 'quotation-builder',
        navigationArguments: const {'quoteId': 'q1'},
      ));

      bloc.add(const StopSelected(0));
      await settle();

      final after = (await pointer())!;
      expect(after.currentWorkflow, VisitWorkflow.quotation);
      expect(after.currentScreen, 'quotation-builder');
      expect(after.navigationArguments, {'quoteId': 'q1'});
    });

    test('a guided step keeps its own state through a route event', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0);
      final p = (await pointer())!;
      await workflows.saveActiveWorkflow(ActiveWorkflow(
        routeId: p.routeId,
        currentStopId: 'stop-1',
        dayStarted: p.dayStarted,
        updatedAt: DateTime.now(),
        currentWorkflow: VisitWorkflow.stockCount,
        currentScreen: 'post-audit-decision',
        navigationArguments: {
          ...p.navigationArguments!,
          'depotName': 'stale name',
          'counted': ['rebar-12'],
        },
      ));

      bloc.add(const StopSelected(0));
      await settle();

      final after = (await pointer())!;
      expect(after.currentScreen, 'post-audit-decision');
      expect(after.navigationArguments!['counted'], ['rebar-12']);
      expect(after.navigationArguments!['depotName'], 'ISI Hardware',
          reason: 'the baseline owns its keys');
    });

    test('selecting another stop keeps a live visit resumable', () async {
      final bloc = await ready();
      await checkInAt(bloc, 0);

      bloc.add(const StopSelected(1));
      await settle();

      expect((await pointer())?.currentStopId, 'stop-1');
    });
  });
}

/// Records every fraud flag the bloc raises, then stores it as usual.
class _RecordedFlags extends RecordFraudFlag {
  _RecordedFlags(super.repository);

  final recorded = <FraudFlag>[];

  @override
  ResultFuture<void> call(FraudFlag params) {
    recorded.add(params);
    return super.call(params);
  }
}

Future<void> _seed(AppDatabase db, {required String routeId}) async {
  final now = DateTime.now().toUtc();
  final day = DateTime.utc(now.year, now.month, now.day);

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

  for (final (i, depot)
      in [('1', 'ISI Hardware'), ('2', 'Toul Kork Yard')].indexed) {
    await db.into(db.routeDepots).insert(RouteDepotsCompanion.insert(
          id: 'cust-${depot.$1}',
          name: depot.$2,
          code: 'C-${depot.$1}',
          contact: 'Sok Dara',
          phone: '012345678',
          address: 'St 271',
          territory: 'PP-CENTRAL',
          territoryType: 'urban',
          latitude: 11.55,
          longitude: 104.91,
        ));
    await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
          id: 'stop-${depot.$1}',
          routeId: routeId,
          depotId: 'cust-${depot.$1}',
          sequence: i + 1,
          plannedArrival: Value(day.add(Duration(hours: 9 + i))),
          plannedDeparture: Value(day.add(Duration(hours: 10 + i))),
          status: 'pending',
          syncState: const Value('synced'),
          dirty: const Value(false),
        ));
  }
}
