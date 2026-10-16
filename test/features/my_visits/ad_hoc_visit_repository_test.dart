import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/features/my_visits/data/models/ad_hoc_visit_response.dart';
import 'package:steelforce/features/my_visits/data/models/depot_stop_info_model.dart';
import 'package:steelforce/features/my_visits/data/models/route_stop_model.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/ad_hoc_visit_repository_impl.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_visit_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/territory_type.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements AdHocVisitRemoteDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _SilentLogger extends Mock implements AppLogger {}

DepotStopInfoModel _depot() => const DepotStopInfoModel(
      id: 'dep-9',
      name: 'Toul Kork Yard',
      nameKh: 'ទួលគោក',
      code: 'C-9',
      contact: 'Sok Dara',
      phone: '012345678',
      address: 'Street 315',
      territory: 'Phnom Penh',
      territoryType: TerritoryType.urban,
      latitude: 11.57,
      longitude: 104.89,
    );

AdHocVisitResponse _response({bool created = true}) => AdHocVisitResponse(
      stop: RouteStopModel(
        id: 'stop-adhoc-1',
        routeId: 'route-new',
        depot: _depot(),
        sequence: 1001,
        plannedArrival: null,
        plannedDeparture: null,
        status: VisitStatus.pending,
        visitSource: VisitSource.adHoc,
      ),
      depot: _depot(),
      visitDate: DateTime(2026, 9, 29),
      created: created,
    );

ApiException _refusal(String code, int status) => ApiException(
      ApiError(
        code: code,
        statusCode: status,
        message: 'Refused',
        correlationId: 'corr-42',
      ),
    );

void main() {
  late AppDatabase db;
  late _MockRemote remote;
  late _MockNetwork network;
  late AdHocVisitRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(<String, Object?>{});
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = _MockRemote();
    network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);
    final logger = _SilentLogger();
    when(() => logger.error(any(),
        fields: any(named: 'fields'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'))).thenReturn(null);

    repository = AdHocVisitRepositoryImpl(
      remote: remote,
      dao: db.routeDao,
      network: network,
      logger: logger,
    );
  });

  tearDown(() => db.close());

  group('the persisted clientRequestId', () {
    test('is written before the request is sent', () async {
      // The ordering that stops a crash between tap and response from
      // producing a duplicate visit. Asserted by looking at the queue from
      // *inside* the send, which is the only moment the claim is checkable.
      List<AdHocVisitQueueRow> queueDuringSend = const [];
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenAnswer((_) async {
        queueDuringSend = await db.routeDao.pendingAdHocVisits();
        return _response();
      });

      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      expect(queueDuringSend, hasLength(1));
      expect(queueDuringSend.single.depotId, 'dep-9');
      // The SAP code is what a replay has to send, so it is persisted too.
      expect(queueDuringSend.single.sk, '1000123');
    });

    test('is reused on retry rather than regenerated', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');
      final firstId = (await db.routeDao.pendingAdHocVisits()).single.id;

      when(() => network.isConnected).thenAnswer((_) async => true);
      final sentIds = <String>[];
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenAnswer((call) async {
        sentIds.add(call.namedArguments[#clientRequestId] as String);
        return _response();
      });

      await repository.drainQueue();

      // A new id on retry would be a new visit — exactly the duplicate the
      // field exists to prevent.
      expect(sentIds, [firstId]);
    });

    test('is a v4 uuid, within the 128-character limit', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      final id = (await db.routeDao.pendingAdHocVisits()).single.id;
      expect(id.length, lessThanOrEqualTo(128));
      expect(
          id,
          matches(RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    });
  });

  group('success', () {
    setUp(() {
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenAnswer((_) async => _response());
    });

    test('returns AdHocVisitAdded and clears the queue', () async {
      final result = await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      expect(result, isA<Success<AdHocVisitOutcome>>());
      expect((result as Success).data, isA<AdHocVisitAdded>());
      expect(await db.routeDao.pendingAdHocVisits(), isEmpty);
    });

    test('writes the stop and its depot locally', () async {
      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      final stop = await (db.select(db.routeStops)
            ..where((t) => t.id.equals('stop-adhoc-1')))
          .getSingle();
      expect(stop.visitSource, 'adHoc');
      expect(stop.plannedArrival, isNull);
      expect(stop.sequence, 1001);

      // Without the depot row the card renders a placeholder naming an id.
      final depot = await (db.select(db.routeDepots)
            ..where((t) => t.id.equals('dep-9')))
          .getSingle();
      expect(depot.name, 'Toul Kork Yard');
    });

    test('opens a placeholder route when the server names an unseen one',
        () async {
      // A rep with no Call Plan for today gets a route opened server-side. A
      // stop with no route header is invisible to the dashboard, which groups
      // by route.
      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      final route = await (db.select(db.routes)
            ..where((t) => t.id.equals('route-new')))
          .getSingle();
      // A localisation key, not a fabricated SAP route name — the dashboard
      // runs route names through `.tr`.
      expect(route.name, kAdHocRouteNameKey);
      expect(route.repName, isEmpty);
    });

    test('never overwrites a real route header with the placeholder', () async {
      await db.into(db.routes).insert(RoutesCompanion.insert(
            id: 'route-new',
            name: 'PP Central — Tuesday',
            repId: 'rep-1',
            repName: 'Sok Dara',
            territory: 'PP-CENTRAL',
            visitDate: DateTime.utc(2026, 9, 29),
            plannedStart: DateTime.utc(2026, 9, 29, 8),
            plannedEnd: DateTime.utc(2026, 9, 29, 17),
            status: 'planned',
          ));

      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      final route = await (db.select(db.routes)
            ..where((t) => t.id.equals('route-new')))
          .getSingle();
      expect(route.name, 'PP Central — Tuesday');
      expect(route.repName, 'Sok Dara');
    });

    test('created:false is a success, not a duplicate warning', () async {
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenAnswer((_) async => _response(created: false));

      final result = await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');
      final outcome = (result as Success).data as AdHocVisitAdded;

      expect(outcome.created, isFalse);
      expect(await db.routeDao.pendingAdHocVisits(), isEmpty);
    });
  });

  group('offline', () {
    test('queues without calling the server', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);

      final result = await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      expect((result as Success).data, isA<AdHocVisitQueued>());
      verifyNever(() => remote.create(
          sk: any(named: 'sk'),
          clientRequestId: any(named: 'clientRequestId')));
      expect(await db.routeDao.pendingAdHocVisits(), hasLength(1));
    });

    test('drainQueue is a no-op while still offline', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      await repository.drainQueue();

      verifyNever(() => remote.create(
          sk: any(named: 'sk'),
          clientRequestId: any(named: 'clientRequestId')));
      expect(await db.routeDao.pendingAdHocVisits(), hasLength(1));
    });
  });

  group('the two 409s', () {
    for (final code in const [
      ApiErrorCodes.visitDepotAlreadyPlanned,
      ApiErrorCodes.visitAdHocAlreadyExists,
    ]) {
      test('$code is a success outcome, not a failure', () async {
        when(() => remote.create(
                sk: any(named: 'sk'),
                clientRequestId: any(named: 'clientRequestId')))
            .thenThrow(_refusal(code, 409));

        final result = await repository.add(
            depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

        // The depot is on their day either way. A red error toast here would
        // tell the rep something failed when nothing did.
        expect(result, isA<Success<AdHocVisitOutcome>>());
        final outcome = (result as Success).data;
        expect(outcome, isA<AdHocVisitAlreadyOnToday>());
        expect((outcome as AdHocVisitAlreadyOnToday).depotId, 'dep-9');
        // Nothing left to retry: the answer will not change.
        expect(await db.routeDao.pendingAdHocVisits(), isEmpty);
      });
    }
  });

  group('business refusals', () {
    for (final (code, status) in const [
      (ApiErrorCodes.visitDepotNotFound, 404),
      (ApiErrorCodes.visitDepotCodeAmbiguous, 409),
      (ApiErrorCodes.visitDepotNotAccessible, 403),
      (ApiErrorCodes.visitAdHocDateInvalid, 400),
      (ApiErrorCodes.visitRepNotAuthorized, 403),
      (ApiErrorCodes.visitTerritoryNotAssigned, 422),
      (ApiErrorCodes.visitAdHocNotAllowed, 422),
    ]) {
      test('$code fails and drops the request — retrying cannot help it',
          () async {
        when(() => remote.create(
                sk: any(named: 'sk'),
                clientRequestId: any(named: 'clientRequestId')))
            .thenThrow(_refusal(code, status));

        final result = await repository.add(
            depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

        expect(result, isA<Failed<AdHocVisitOutcome>>());
        final failure = (result as Failed).failure;
        expect(failure, isA<AdHocVisitRefusedFailure>());
        expect((failure as AdHocVisitRefusedFailure).code, code);
        // Left queued, it would replay forever against an answer that never
        // changes.
        expect(await db.routeDao.pendingAdHocVisits(), isEmpty);
      });
    }

    test('only RepNotAuthorized marks the action permanently unavailable',
        () async {
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(_refusal(ApiErrorCodes.visitRepNotAuthorized, 403));
      var result = await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');
      expect(
          ((result as Failed).failure as AdHocVisitRefusedFailure)
              .isPermanentlyUnavailable,
          isTrue);

      // The other 403 is about *this depot*, not the account — hiding the
      // action for the session over it would remove a working feature.
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(_refusal(ApiErrorCodes.visitDepotNotAccessible, 403));
      result = await repository.add(
          depotId: 'dep-8', sk: '1000124', depotName: 'Other Yard');
      expect(
          ((result as Failed).failure as AdHocVisitRefusedFailure)
              .isPermanentlyUnavailable,
          isFalse);
    });

    test('only DepotCodeAmbiguous carries a support reference', () async {
      // Master data only support can fix: the rep needs something to quote.
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(_refusal(ApiErrorCodes.visitDepotCodeAmbiguous, 409));
      var result = await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');
      expect(
          ((result as Failed).failure as AdHocVisitRefusedFailure)
              .supportReference,
          'corr-42');

      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(_refusal(ApiErrorCodes.visitDepotNotFound, 404));
      result = await repository.add(
          depotId: 'dep-8', sk: '1000124', depotName: 'Other Yard');
      expect(
          ((result as Failed).failure as AdHocVisitRefusedFailure)
              .supportReference,
          isNull);
    });
  });

  group('retryable failures', () {
    test('a 5xx keeps the request queued under the same id', () async {
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(_refusal('Server.Unavailable', 503));

      final result = await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      expect((result as Success).data, isA<AdHocVisitQueued>());
      final queued = await db.routeDao.pendingAdHocVisits();
      expect(queued, hasLength(1));
      expect(queued.single.lastErrorCode, 'Server.Unavailable');
    });

    test('an unreadable 200 stays queued — the visit may exist', () async {
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(const ServerException(message: 'bad body'));

      final result = await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      expect((result as Success).data, isA<AdHocVisitQueued>());
      expect(await db.routeDao.pendingAdHocVisits(), hasLength(1));
    });

    test('a later drain delivers it and clears the queue', () async {
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(_refusal('Server.Unavailable', 503));
      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');

      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenAnswer((_) async => _response(created: false));
      final drained = await repository.drainQueue();

      expect((drained as Success).data, hasLength(1));
      expect(await db.routeDao.pendingAdHocVisits(), isEmpty);
    });

    test('one refusal does not abandon the rest of the queue', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      await repository.add(depotId: 'dep-1', sk: 'SAP-1', depotName: 'First');
      await repository.add(depotId: 'dep-2', sk: 'SAP-2', depotName: 'Second');
      when(() => network.isConnected).thenAnswer((_) async => true);

      when(() => remote.create(
              sk: 'SAP-1', clientRequestId: any(named: 'clientRequestId')))
          .thenThrow(_refusal(ApiErrorCodes.visitAdHocNotAllowed, 422));
      when(() => remote.create(
              sk: 'SAP-2', clientRequestId: any(named: 'clientRequestId')))
          .thenAnswer((_) async => _response());

      await repository.drainQueue();

      // The second depot is a different request with a different answer.
      verify(() => remote.create(
          sk: 'SAP-2',
          clientRequestId: any(named: 'clientRequestId'))).called(1);
      expect(await db.routeDao.pendingAdHocVisits(), isEmpty);
    });

    test('a drain replays the stored SAP code, not a fresh lookup', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      await repository.add(
          depotId: 'dep-9', sk: '1000123', depotName: 'Toul Kork Yard');
      final queuedId = (await db.routeDao.pendingAdHocVisits()).single.id;
      when(() => network.isConnected).thenAnswer((_) async => true);
      when(() => remote.create(
              sk: any(named: 'sk'),
              clientRequestId: any(named: 'clientRequestId')))
          .thenAnswer((_) async => _response());

      await repository.drainQueue();

      verify(() => remote.create(sk: '1000123', clientRequestId: queuedId))
          .called(1);
    });

    test('a request queued without a SAP code is dropped, never sent',
        () async {
      // Rows written before schema v26 have no `sk`. Guessing one could add
      // the wrong depot, so the drain discards them.
      await db.routeDao.enqueueAdHocVisit(AdHocVisitQueueCompanion.insert(
        id: 'legacy-req',
        depotId: 'dep-9',
        depotName: 'Toul Kork Yard',
        createdAt: DateTime.utc(2026, 9, 29),
      ));

      final drained = await repository.drainQueue();

      expect((drained as Success).data, isEmpty);
      verifyNever(() => remote.create(
          sk: any(named: 'sk'),
          clientRequestId: any(named: 'clientRequestId')));
      expect(await db.routeDao.pendingAdHocVisits(), isEmpty);
    });
  });

  group('depotIdsOnDay', () {
    test('reports depots already on the day, whatever put them there',
        () async {
      await db.into(db.routes).insert(RoutesCompanion.insert(
            id: 'route-1',
            name: 'PP Central',
            repId: 'rep-1',
            repName: 'Sok Dara',
            territory: 'PP-CENTRAL',
            visitDate: DateTime.utc(2026, 9, 29),
            plannedStart: DateTime.utc(2026, 9, 29, 8),
            plannedEnd: DateTime.utc(2026, 9, 29, 17),
            status: 'planned',
          ));
      await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
            id: 'stop-1',
            routeId: 'route-1',
            depotId: 'dep-1',
            sequence: 1,
            status: 'pending',
          ));

      final result = await repository.depotIdsOnDay(DateTime.utc(2026, 9, 29));
      expect((result as Success).data, {'dep-1'});
    });

    test('does not report a depot from another day', () async {
      await db.into(db.routes).insert(RoutesCompanion.insert(
            id: 'route-1',
            name: 'PP Central',
            repId: 'rep-1',
            repName: 'Sok Dara',
            territory: 'PP-CENTRAL',
            visitDate: DateTime.utc(2026, 9, 28),
            plannedStart: DateTime.utc(2026, 9, 28, 8),
            plannedEnd: DateTime.utc(2026, 9, 28, 17),
            status: 'planned',
          ));
      await db.into(db.routeStops).insert(RouteStopsCompanion.insert(
            id: 'stop-1',
            routeId: 'route-1',
            depotId: 'dep-1',
            sequence: 1,
            status: 'pending',
          ));

      final result = await repository.depotIdsOnDay(DateTime.utc(2026, 9, 29));
      expect((result as Success).data, isEmpty);
    });
  });
}
