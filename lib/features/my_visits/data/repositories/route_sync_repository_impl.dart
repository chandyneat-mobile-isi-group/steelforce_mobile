import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/route_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/route_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/remote/route_sync_page.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_sync_repository.dart';

const _routesEntity = 'routes';

/// Mirrors `order`'s `SyncRepositoryImpl` method-for-method — the only
/// repository allowed to touch [RouteRemoteDataSource].
class RouteSyncRepositoryImpl implements RouteSyncRepository {
  const RouteSyncRepositoryImpl({
    required RouteRemoteDataSource remote,
    required RouteLocalDataSource local,
    required NetworkInfo network,
    AppLogger? logger,
  })  : _remote = remote,
        _local = local,
        _network = network,
        _logger = logger;

  final RouteRemoteDataSource _remote;
  final RouteLocalDataSource _local;
  final NetworkInfo _network;

  /// Optional so existing tests construct this unchanged.
  final AppLogger? _logger;

  /// A pull that stored nothing is the ambiguous case worth a line of its own.
  ///
  /// Zero routes means either the rep genuinely has no work today, or the
  /// `territory` filter matches nothing the server holds — and those look
  /// identical from the app: empty dashboard, no stop to check into, and so
  /// nothing for "Complete Visit" to close. Logging the territory asked for
  /// beside the ones the response carried separates them immediately.
  ///
  /// A territory code is a routing value, not PII or revenue
  /// (`docs/skills/security.md` §10), so it is safe to name here — and it is
  /// the single fact needed to tell the two cases apart.
  void _logEmptyPull(RouteSyncScope scope, RouteSyncPage page, String kind) {
    if (page.routes.isNotEmpty) return;
    _logger?.warning('route_sync.empty', fields: {
      'kind': kind,
      'requestedTerritory':
          scope.territory.isEmpty ? '(unscoped)' : scope.territory,
      'serverTerritories': page.territories,
      'depots': page.depots.length,
    });
  }

  static const _pageSize = 50;

  @override
  ResultFuture<DateTime?> lastSyncedAt() async {
    try {
      return Success(await _local.getLastSyncedAt(_routesEntity));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<RouteSyncResult> runInitialSync(RouteSyncScope scope) async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      var page = 0;
      var total = 0;
      DateTime? serverClock;
      while (true) {
        final result = await _remote.fetchInitial(
            scope: scope, page: page, pageSize: _pageSize);
        await _local.upsertDepots(result.depots);
        if (result.routes.isNotEmpty) {
          await _local.upsertRoutes(result.routes);
          total += result.routes.length;
        }
        // The last page read wins: it is the newest view of the server clock,
        // and anything changed mid-pagination is caught by the next delta.
        serverClock = result.generatedAt ?? serverClock;
        if (page == 0) _logEmptyPull(scope, result, 'initial');
        if (!result.hasMore) break;
        page++;
      }

      final syncedAt = _watermark(serverClock);
      await _local.setLastSyncedAt(_routesEntity, syncedAt);
      return Success(
          RouteSyncResult(upserted: total, deleted: 0, syncedAt: syncedAt));
    } on ApiException catch (e) {
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<RouteSyncResult> runDeltaSync(RouteSyncScope scope) async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      final since = await _local.getLastSyncedAt(_routesEntity);
      if (since == null) return runInitialSync(scope);

      final delta = await _remote.fetchDelta(scope: scope, since: since);
      await _local.upsertDepots(delta.depots);
      if (delta.routes.isNotEmpty) await _local.upsertRoutes(delta.routes);

      _logEmptyPull(scope, delta, 'delta');

      if (delta.routes.isEmpty) {
        // **An empty delta must not advance the watermark.**
        //
        // It used to, unconditionally. That made the empty state
        // self-sustaining: each empty pull moved `since` forward, so the next
        // delta asked about an even narrower window, which was also empty. A
        // delta can never reach back past its own `since`, and `runDeltaSync`
        // only falls back to an initial pull when the watermark is *null* —
        // which it never becomes again. A device that once pulled nothing
        // pulls nothing forever, with a 200 and a clean log every time.
        //
        // Holding the watermark still keeps the window widening instead, so a
        // route published just before the last sync is inside the next one.
        if ((await _local.fetchAllRoutes()).isEmpty) {
          // Nothing stored *and* nothing arriving is the stronger signal: the
          // watermark is hiding a route the device has never seen. Only a full
          // pull can reach it.
          //
          // Costs one extra request per dashboard open while the rep genuinely
          // has no routes — an empty initial pull is a single page. That is
          // the right trade against a rep whose day never loads.
          return runInitialSync(scope);
        }
        return Success(
            RouteSyncResult(upserted: 0, deleted: 0, syncedAt: since));
      }

      final syncedAt = _watermark(delta.generatedAt);
      await _local.setLastSyncedAt(_routesEntity, syncedAt);
      return Success(RouteSyncResult(
          upserted: delta.routes.length, deleted: 0, syncedAt: syncedAt));
    } on ApiException catch (e) {
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  /// Maps a transport/API failure onto the domain [Failure] the UI renders.
  ///
  /// **[ApiException] must be caught explicitly.** It is a sibling of
  /// [ServerException], not a subtype — `on ServerException` does not catch it.
  /// The data sources this repository calls throw [ApiException] exclusively,
  /// so without this the exception escaped `runDeltaSync` entirely, past the
  /// cubit, and surfaced as an uncaught zone error that took the app down on a
  /// plain expired session. The fixture source this replaced happened to throw
  /// [ServerException], which is why the gap only appeared against the live API.
  Failure _failure(ApiError error) {
    if (error.code == ApiErrorCodes.network) return const NetworkFailure();

    // A 401 that survived the interceptor means the refresh was refused too,
    // so the session is genuinely gone. Say so, rather than blaming the route
    // feed for what is an authentication problem — the rep needs to sign in
    // again, and "could not sync routes" would send them looking at the wrong
    // thing. Signing them out is the interceptor's job, not this one's.
    if (error.isUnauthenticated) {
      return AuthenticationFailure(
          message:
              error.message ?? 'Your session expired. Please sign in again.');
    }

    return ServerFailure(
      message: error.message ?? 'Could not sync routes. Please try again.',
      statusCode: error.statusCode,
    );
  }

  /// The watermark to persist, preferring the **server's** clock.
  ///
  /// `since` on the next delta is this value, and the API rejects one more
  /// than five minutes in the future with a 400 (api.md §5.2). Storing
  /// `DateTime.now()` — which this used to do unconditionally — meant a
  /// handset running fast poisoned its own watermark: every subsequent delta
  /// failed, and before the API started rejecting it, it instead returned an
  /// empty page that the client stored and never synced from again.
  ///
  /// The device clock remains the fallback for a feed that omits
  /// `generatedAt`. That is the old behaviour, kept deliberately: a mocked or
  /// older server should still sync rather than never advancing its watermark,
  /// and the live contract puts the field on every response anyway.
  static DateTime _watermark(DateTime? serverClock) =>
      serverClock ?? DateTime.now();
}
