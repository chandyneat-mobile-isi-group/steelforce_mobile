import 'package:drift/drift.dart' show Value;
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/daos/route_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/core/utils/uuid.dart';
import 'package:steelforce/features/my_visits/data/local/route_drift_mappers.dart';
import 'package:steelforce/features/my_visits/data/models/ad_hoc_visit_response.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_debug_log.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_visit_outcome.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/repositories/ad_hoc_visit_repository.dart';

/// The name stored on a placeholder route header.
///
/// A localisation **key**, not a string: `StopDashboardCubit` already runs
/// every route name through `.tr`, so this renders "Unplanned visits" in
/// English and Khmer alike. Storing a fabricated SAP-looking route name would
/// put a label on the rep's card that no system anywhere agrees with.
const String kAdHocRouteNameKey = 'my_visits.ad_hoc.route_name';

class AdHocVisitRepositoryImpl implements AdHocVisitRepository {
  const AdHocVisitRepositoryImpl({
    required AdHocVisitRemoteDataSource remote,
    required RouteDao dao,
    required NetworkInfo network,
    required AppLogger logger,
  })  : _remote = remote,
        _dao = dao,
        _network = network,
        _logger = logger;

  final AdHocVisitRemoteDataSource _remote;
  final RouteDao _dao;
  final NetworkInfo _network;
  final AppLogger _logger;

  @override
  ResultFuture<AdHocVisitOutcome> add({
    required String depotId,
    required String sk,
    required String depotName,
  }) async {
    // Generated once, here, and written to disk before anything is sent. A new
    // id per attempt is a new visit — this is the entire reason the field
    // exists, and the one ordering mistake that duplicates a rep's day.
    final clientRequestId = Uuid.v4();
    await _dao.enqueueAdHocVisit(AdHocVisitQueueCompanion.insert(
      id: clientRequestId,
      depotId: depotId,
      sk: Value(sk),
      depotName: depotName,
      createdAt: DateTime.now().toUtc(),
    ));

    // Real reachability, not interface state (ADR-0005). Checked *after* the
    // request is persisted, so an offline tap still leaves something to retry.
    if (!await _network.isConnected) {
      return Success(AdHocVisitQueued(
        clientRequestId: clientRequestId,
        depotId: depotId,
        depotName: depotName,
      ));
    }

    AdHocVisitDebugLog.attempt(
      trigger: 'tap',
      depotId: depotId,
      sk: sk,
      clientRequestId: clientRequestId,
    );
    return _send(
      clientRequestId: clientRequestId,
      depotId: depotId,
      sk: sk,
      depotName: depotName,
    );
  }

  @override
  ResultFuture<List<AdHocVisitOutcome>> drainQueue() async {
    final pending = await _dao.pendingAdHocVisits();
    if (pending.isEmpty) return const Success([]);
    if (!await _network.isConnected) return const Success([]);

    final delivered = <AdHocVisitOutcome>[];
    for (final row in pending) {
      final sk = row.sk;
      if (sk == null) {
        // Queued before the endpoint was keyed on the SAP code. There is no
        // code to send and inventing one could add the wrong depot, so the
        // request is dropped; the rep can add the depot again.
        await _dao.dequeueAdHocVisit(row.id);
        _logger.warning('visits.adHoc.droppedWithoutSapCode');
        continue;
      }
      AdHocVisitDebugLog.attempt(
        trigger: 'queue retry',
        depotId: row.depotId,
        sk: sk,
        clientRequestId: row.id,
      );
      final result = await _send(
        clientRequestId: row.id,
        depotId: row.depotId,
        sk: sk,
        depotName: row.depotName,
      );
      // A refusal ends *that* request, not the drain: the next one in the
      // queue is a different depot and may well be accepted.
      result.when(
        success: (outcome) {
          if (outcome is! AdHocVisitQueued) delivered.add(outcome);
        },
        failure: (_) {},
      );
    }
    return Success(delivered);
  }

  @override
  ResultFuture<Set<String>> depotIdsOnDay(DateTime day) async {
    try {
      return Success(await _dao.depotIdsOnDay(day));
    } on Object catch (_) {
      // A local read failure must not block the picker — showing every depot
      // is recoverable (the server answers 409 and we route to the stop);
      // showing none is not.
      return const Success(<String>{});
    }
  }

  @override
  Stream<List<PendingAdHocVisit>> watchPending() =>
      _dao.watchPendingAdHocVisits().map((rows) => [
            for (final row in rows)
              PendingAdHocVisit(
                clientRequestId: row.id,
                depotId: row.depotId,
                depotName: row.depotName,
                createdAt: row.createdAt,
                lastErrorCode: row.lastErrorCode,
              ),
          ]);

  /// One attempt, with the queue kept honest about what happened.
  Future<Result<AdHocVisitOutcome>> _send({
    required String clientRequestId,
    required String depotId,
    required String sk,
    required String depotName,
  }) async {
    try {
      final response = await _remote.create(
        sk: sk,
        clientRequestId: clientRequestId,
      );

      await _store(response);
      // Acknowledged — including a `created: false` replay, which is the
      // server telling us this exact request already succeeded.
      await _dao.dequeueAdHocVisit(clientRequestId);

      return Success(AdHocVisitAdded(
        stop: response.stop,
        depot: response.depot,
        visitDate: response.visitDate,
        created: response.created,
      ));
    } on ApiException catch (e) {
      return _interpret(e.error,
          clientRequestId: clientRequestId, depotId: depotId);
    } on ServerException catch (e) {
      // A 200 we could not read. Left queued: the visit may exist, and the
      // replay will tell us — dropping it here could lose a real visit.
      await _dao.markAdHocVisitAttempted(clientRequestId,
          errorCode: ApiErrorCodes.unknown);
      _logger.error('visits.adHoc.unreadableResponse',
          fields: {'detail': e.message});
      return Success(AdHocVisitQueued(
        clientRequestId: clientRequestId,
        depotId: depotId,
        depotName: depotName,
      ));
    }
  }

  /// Turns a refusal into the outcome the rep should actually experience.
  ///
  /// Branches on `code`, never on the status: two of these share 409 and two
  /// share 403 (`ad-hoc-visits-mobile.md` §8). In particular
  /// `Visit.RepNotAuthorized` is a 403 that must **not** sign anyone out.
  Future<Result<AdHocVisitOutcome>> _interpret(
    ApiError error, {
    required String clientRequestId,
    required String depotId,
  }) async {
    // §10: no depot identifiers in logs — a depot id names a real outlet.
    _logger.error('visits.adHoc.refused', fields: {
      'status': error.statusCode,
      'errorCode': error.code,
      'correlationId': error.correlationId,
    });

    switch (error.code) {
      // Both 409s. The depot is on their day either way, so this is "already
      // done", not a red toast — the caller routes to the existing stop.
      case ApiErrorCodes.visitDepotAlreadyPlanned:
      case ApiErrorCodes.visitAdHocAlreadyExists:
        await _dao.dequeueAdHocVisit(clientRequestId);
        return Success(
            AdHocVisitAlreadyOnToday(depotId: depotId, code: error.code));

      // Business refusals. Retrying cannot change any of these, so the request
      // is dropped rather than left to replay forever.
      case ApiErrorCodes.visitDepotNotFound:
      case ApiErrorCodes.visitDepotCodeAmbiguous:
      case ApiErrorCodes.visitDepotNotAccessible:
      case ApiErrorCodes.visitAdHocDateInvalid:
      case ApiErrorCodes.visitRepNotAuthorized:
      case ApiErrorCodes.visitTerritoryNotAssigned:
      case ApiErrorCodes.visitAdHocNotAllowed:
        await _dao.dequeueAdHocVisit(clientRequestId);
        return Failed(AdHocVisitRefusedFailure(
          message: error.message ?? _fallbackMessageKey(error.code),
          code: error.code,
          statusCode: error.statusCode,
          // Master data only support can fix — give the rep something to
          // quote. Every other refusal is self-explanatory.
          supportReference: error.code == ApiErrorCodes.visitDepotCodeAmbiguous
              ? error.correlationId
              : null,
        ));

      default:
        // Transport, 5xx, timeout, 429 — all retryable. Same id next time.
        // A lost race between two simultaneous retries can produce one 5xx;
        // the next retry returns the winner's visit. That is the queue
        // working, not an incident.
        await _dao.markAdHocVisitAttempted(clientRequestId,
            errorCode: error.code);
        final row = await _dao.pendingAdHocVisits();
        final self = row.where((r) => r.id == clientRequestId).firstOrNull;
        return Success(AdHocVisitQueued(
          clientRequestId: clientRequestId,
          depotId: depotId,
          depotName: self?.depotName ?? '',
        ));
    }
  }

  /// The localisation key to show when the server sent no user-safe message.
  /// Never `ApiError.detail`, which is written for developers and can quote
  /// payload values.
  static String _fallbackMessageKey(String code) => switch (code) {
        ApiErrorCodes.visitDepotNotFound => 'my_visits.ad_hoc.error.not_found',
        ApiErrorCodes.visitDepotCodeAmbiguous =>
          'my_visits.ad_hoc.error.ambiguous',
        ApiErrorCodes.visitDepotNotAccessible =>
          'my_visits.ad_hoc.error.suspended',
        ApiErrorCodes.visitRepNotAuthorized =>
          'my_visits.ad_hoc.error.not_a_rep',
        ApiErrorCodes.visitTerritoryNotAssigned =>
          'my_visits.ad_hoc.error.no_territory',
        ApiErrorCodes.visitAdHocNotAllowed => 'my_visits.ad_hoc.error.day_full',
        _ => 'my_visits.ad_hoc.error.generic',
      };

  /// Writes the stop and its depot locally so the card can appear without
  /// waiting for a sync round trip (§6).
  Future<void> _store(AdHocVisitResponse response) async {
    await _dao.upsertAdHocVisit(
      stop: response.stop.toCompanion(response.stop.routeId),
      depot: response.depot.toRouteDepotCompanion(),
      route: RoutesCompanion.insert(
        id: response.stop.routeId,
        name: kAdHocRouteNameKey,
        // Blank rather than invented. The rep and territory are the server's
        // to state, and the next sync replaces this header wholesale.
        repId: '',
        repName: '',
        territory: '',
        visitDate: response.visitDate,
        plannedStart: response.visitDate,
        plannedEnd: response.visitDate,
        status: RouteStatus.inProgress.name,
        syncState: const Value('synced'),
        dirty: const Value(false),
      ),
    );
  }
}
