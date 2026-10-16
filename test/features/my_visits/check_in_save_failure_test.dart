import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/my_visits/domain/usecases/send_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_send_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/location_sample_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/visit_drift_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/local/workflow_state_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/active_workflow_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/location_sample_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/route_repository_impl.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/check_in_record.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
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

/// A check-in whose local save fails must never read as a success.
///
/// `CheckIn` reports a failed write as a `Failed` result rather than a throw,
/// and the bloc used to only `catch` — so a `CacheFailure` went straight past
/// it, the stop was marked checked in on screen and the rep was sent into a
/// visit with no check-in row behind it.
void main() {
  late AppDatabase db;
  late RouteRepositoryImpl routes;
  late VisitRepositoryImpl visits;
  late VisitDriftLocalDataSource visitLocal;
  late ActiveWorkflowRepositoryImpl workflows;

  const logger = ConsoleAppLogger(verbose: false);
  const routeId = 'route-1';
  const stopId = 'stop-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    visitLocal = VisitDriftLocalDataSource(db.visitDao, logger);
    routes =
        RouteRepositoryImpl(RouteDriftLocalDataSource(db.routeDao, logger));
    visits = VisitRepositoryImpl(visitLocal);
    workflows = ActiveWorkflowRepositoryImpl(
        WorkflowStateLocalDataSourceImpl(db.workflowStateDao));
    await _seed(db, routeId: routeId, stopId: stopId);
  });
  tearDown(() => db.close());

  ActiveRouteBloc buildBloc(CheckIn checkIn, {SendCheckIn? send}) =>
      ActiveRouteBloc(
        sendCheckIn: send,
        saveActiveWorkflow: SaveActiveWorkflow(workflows),
        clearActiveWorkflow: ClearActiveWorkflow(workflows),
        getActiveWorkflow: GetActiveWorkflow(workflows),
        getRoute: GetRoute(routes),
        updateRouteStatus: UpdateRouteStatus(routes),
        updateStopStatus: UpdateStopStatus(routes),
        checkIn: checkIn,
        checkOut: CheckOut(visits),
        recordFraudFlag: RecordFraudFlag(LocationSampleRepositoryImpl(
            LocationSampleDriftLocalDataSource(db.routeTelemetryDao))),
        fraudDetectionService: const FraudDetectionService(),
      );

  Future<ActiveRouteBloc> readyInside(CheckIn checkIn,
      {SendCheckIn? send}) async {
    final bloc = buildBloc(checkIn, send: send)
      ..add(const ActiveRouteLoadRequested(routeId));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    bloc
      ..add(const StopSelected(0))
      ..add(const GeofenceStatusChanged(
          insideGeofence: true,
          distanceMeters: 10,
          accuracyMeters: 8,
          isMocked: false,
          latitude: 11.55,
          longitude: 104.91));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return bloc;
  }

  Future<VisitStatus> storedStatus() async {
    final r = await routes.getRoute(routeId);
    return r
        .when(success: (route) => route, failure: (_) => null)!
        .stops
        .single
        .status;
  }

  VisitStatus stateStatus(ActiveRouteBloc bloc) =>
      (bloc.state as ActiveRouteReady).route.stops.single.status;

  for (final (label, checkIn) in [
    ('returns a Failed result', () => _FailedCheckIn(visits)),
    ('throws', () => _ThrowingCheckIn(visits)),
  ]) {
    group('when the check-in save $label', () {
      test('the bloc reports a save failure, not a success', () async {
        final bloc = await readyInside(checkIn());
        addTearDown(bloc.close);
        final before = (bloc.state as ActiveRouteReady).checkInAttempt;

        bloc.add(const CheckInRequested(stopId: stopId));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        final state = bloc.state as ActiveRouteReady;
        expect(state.checkInSaveFailed, isTrue);
        expect(state.checkInAttempt, before + 1,
            reason: 'the screen is answered, so its spinner stops');
        expect(state.checkInOverridable, isFalse,
            reason: 'a failed save is not something a reason can fix');
        expect(state.blockedCheckInReason, isNull,
            reason: 'no raw English sentence — the screen localizes the flag');
        expect(stateStatus(bloc), VisitStatus.pending,
            reason: 'the UI must not show the stop as checked in');
      });

      test('nothing is recorded and no resume pointer is written', () async {
        final bloc = await readyInside(checkIn());
        addTearDown(bloc.close);

        bloc.add(const CheckInRequested(stopId: stopId));
        await Future<void>.delayed(const Duration(milliseconds: 60));

        expect(await storedStatus(), VisitStatus.pending);
        expect(await visitLocal.fetchPendingCheckIns(), isEmpty);
        final pointer = await workflows.getActiveWorkflow();
        expect(pointer.when(success: (w) => w, failure: (_) => null), isNull);
      });
    });
  }

  test('a retry that saves clears the failure and checks in', () async {
    final flaky = _FlakyCheckIn(visits);
    final bloc = await readyInside(flaky);
    addTearDown(bloc.close);

    bloc.add(const CheckInRequested(stopId: stopId));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect((bloc.state as ActiveRouteReady).checkInSaveFailed, isTrue);

    bloc.add(const CheckInRequested(stopId: stopId));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final state = bloc.state as ActiveRouteReady;
    expect(state.checkInSaveFailed, isFalse);
    expect(stateStatus(bloc), VisitStatus.checkedIn);
    expect(await storedStatus(), VisitStatus.checkedIn);
    expect(await visitLocal.fetchPendingCheckIns(), hasLength(1),
        reason: 'exactly one row — the failed attempt wrote nothing');
  });

  test('selecting another stop clears a stale save failure', () async {
    final bloc = await readyInside(_FailedCheckIn(visits));
    addTearDown(bloc.close);

    bloc.add(const CheckInRequested(stopId: stopId));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect((bloc.state as ActiveRouteReady).checkInSaveFailed, isTrue);

    bloc.add(const StopSelected(0));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect((bloc.state as ActiveRouteReady).checkInSaveFailed, isFalse);
  });

  group('the server answers the check-in (check-in-check-out-mobile.md §4)',
      () {
    SendCheckIn sender(_Remote remote, {bool online = true}) =>
        SendCheckIn(VisitRepositoryImpl(visitLocal,
            remote: remote, network: _Network(online)));

    test('already visited today: refused, nothing recorded, rep told why',
        () async {
      final bloc = await readyInside(CheckIn(visits),
          send: sender(_Remote(const ApiException(
              ApiError(code: 'Visit.AlreadyCompleted', statusCode: 409)))));
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested(stopId: stopId));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final state = bloc.state as ActiveRouteReady;
      expect(state.checkInRefusal, VisitSendStatus.alreadyVisited);
      expect(stateStatus(bloc), isNot(VisitStatus.checkedIn));
      expect(await storedStatus(), isNot(VisitStatus.checkedIn));
      expect(await visitLocal.fetchPendingCheckIns(), isEmpty);
    });

    test('offline: checked in as normal, queued for the next sync', () async {
      final remote = _Remote(null);
      final bloc = await readyInside(CheckIn(visits),
          send: sender(remote, online: false));
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested(stopId: stopId));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final state = bloc.state as ActiveRouteReady;
      expect(state.checkInRefusal, isNull);
      expect(stateStatus(bloc), VisitStatus.checkedIn);
      expect(await visitLocal.fetchPendingCheckIns(), hasLength(1));
      expect(remote.calls, 0);
    });

    test('online: checked in, sent, with the route on the row', () async {
      final remote = _Remote(null);
      final bloc = await readyInside(CheckIn(visits), send: sender(remote));
      addTearDown(bloc.close);

      bloc.add(const CheckInRequested(stopId: stopId));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(stateStatus(bloc), VisitStatus.checkedIn);
      expect(remote.calls, 1);
      expect(remote.lastRouteId, routeId);
      expect(await visitLocal.fetchPendingCheckIns(), isEmpty);
    });
  });

  test('a successful save never sets the failure flag', () async {
    final bloc = await readyInside(CheckIn(visits));
    addTearDown(bloc.close);

    bloc.add(const CheckInRequested(stopId: stopId));
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final state = bloc.state as ActiveRouteReady;
    expect(state.checkInSaveFailed, isFalse);
    expect(stateStatus(bloc), VisitStatus.checkedIn);
  });
}

class _FailedCheckIn extends CheckIn {
  _FailedCheckIn(super.repository);

  @override
  ResultFuture<CheckInRecord> call(CheckInRecord params) async =>
      const Failed(CacheFailure(message: 'disk full'));
}

class _ThrowingCheckIn extends CheckIn {
  _ThrowingCheckIn(super.repository);

  @override
  ResultFuture<CheckInRecord> call(CheckInRecord params) async =>
      throw StateError('database closed');
}

/// Fails the first write, then behaves normally.
class _FlakyCheckIn extends CheckIn {
  _FlakyCheckIn(super.repository);

  var _calls = 0;

  @override
  ResultFuture<CheckInRecord> call(CheckInRecord params) {
    _calls++;
    if (_calls == 1) {
      return Future.value(const Failed(CacheFailure(message: 'busy')));
    }
    return super.call(params);
  }
}

Future<void> _seed(
  AppDatabase db, {
  required String routeId,
  required String stopId,
}) async {
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

  await db.into(db.routeDepots).insert(RouteDepotsCompanion.insert(
        id: 'cust-1',
        name: 'ISI Hardware',
        code: 'C-1',
        contact: 'Sok Dara',
        phone: '012345678',
        address: 'St 271',
        territory: 'PP-CENTRAL',
        territoryType: 'urban',
        latitude: 11.55,
        longitude: 104.91,
      ));

  await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
        id: stopId,
        routeId: routeId,
        depotId: 'cust-1',
        sequence: 1,
        plannedArrival: Value(day.add(const Duration(hours: 9))),
        plannedDeparture: Value(day.add(const Duration(hours: 10))),
        status: 'pending',
        syncState: const Value('synced'),
        dirty: const Value(false),
      ));
}

class _Network implements NetworkInfo {
  _Network(this.online);
  final bool online;
  @override
  Future<bool> get isConnected async => online;
}

/// Answers every check-in with [error], or accepts it when null.
class _Remote implements VisitCheckRemoteDataSource {
  _Remote(this.error);
  final Exception? error;
  int calls = 0;
  String? lastRouteId;

  @override
  Future<ServerVisit> checkIn(CheckInRecordModel record) async {
    calls++;
    lastRouteId = record.routeId;
    if (error != null) throw error!;
    return ServerVisit(stopId: record.stopId, status: VisitStatus.checkedIn);
  }

  @override
  Future<ServerVisit> checkOut(CheckOutRecordModel record) =>
      throw UnimplementedError();

  @override
  Future<List<NoOrderReason>> fetchCheckOutReasons() async => const [];
}
