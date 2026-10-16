import 'package:steelforce/core/database/drift/daos/visit_dao.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/platform/storage/captured_media_store.dart'
    as media;
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/local/visit_local_data_source.dart';
import 'package:steelforce/features/my_visits/data/models/visit_capture_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/pending_visit_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_push_summary.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_stop_discard.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_sync_repository.dart';

/// Push side of visit-data sync, mirroring [RouteSyncRepositoryImpl]'s pull
/// side: same `NetworkInfo`-guarded fail-fast pattern, but scoped to
/// [VisitLocalDataSource] instead of [RouteLocalDataSource] — a separate
/// repository since these are genuinely different concerns (route/depot
/// pull vs. visit-capture push).
class VisitSyncRepositoryImpl implements VisitSyncRepository {
  const VisitSyncRepositoryImpl({
    required VisitSyncRemoteDataSource remote,
    required VisitLocalDataSource local,
    required NetworkInfo network,
    AppLogger? logger,
    Future<void> Function()? sendBeforeCaptures,
    void Function(String path) deleteFile = media.deleteCapturedFile,
  })  : _remote = remote,
        _local = local,
        _network = network,
        _logger = logger,
        _sendBeforeCaptures = sendBeforeCaptures,
        _deleteFile = deleteFile;

  final VisitSyncRemoteDataSource _remote;
  final VisitLocalDataSource _local;
  final NetworkInfo _network;

  /// Optional so existing construction sites and tests compile unchanged.
  final AppLogger? _logger;

  /// Sends what belongs between a stop's check-in and its check-out — the
  /// quotations and orders queued at the shop. A callback because they live
  /// in another feature; wired in the composition root.
  ///
  /// Never blocks the visit: if it fails, the check-outs still go.
  final Future<void> Function()? _sendBeforeCaptures;

  /// Removes a discarded photo's file. A seam so tests need no filesystem;
  /// production uses `captured_media_store`, which is a no-op on web.
  final void Function(String path) _deleteFile;

  @override
  ResultFuture<VisitPushSummary> pushPendingVisitData() async {
    final checkIns = await pushPendingCheckIns();
    // Offline or signed out: the next steps would fail the same way.
    if (checkIns is! Success<VisitPushSummary>) return checkIns;

    final before = _sendBeforeCaptures;
    if (before != null) {
      try {
        await before();
      } catch (e, stack) {
        _logger?.error('visit.push.before_captures_failed',
            error: e, stackTrace: stack);
      }
    }

    final captures = await pushPendingCaptures();
    return captures.when(
      success: (c) => Success(VisitPushSummary(
        pushedCount: checkIns.data.pushedCount + c.pushedCount,
        syncedAt: c.syncedAt,
      )),
      failure: Failed.new,
    );
  }

  /// A request of its own, so a check-out or note further down the queue can
  /// never reach the server ahead of the check-in it belongs to.
  @override
  ResultFuture<VisitPushSummary> pushPendingCheckIns() => _guarded(() async {
        final checkIns = await _local.fetchPendingCheckIns();
        return _push(VisitPushBatch(
          checkIns: checkIns,
          checkOuts: const [],
          orderLines: const [],
          stockUpdates: const [],
          returns: const [],
          collections: const [],
          notes: const [],
          photos: const [],
        ));
      });

  @override
  ResultFuture<VisitPushSummary> pushPendingCaptures() => _guarded(() async {
        final pendingStock = await _local.fetchPendingStockUpdates();
        final quarantined = pendingStock.where(_isUnstorable).toList();
        if (quarantined.isNotEmpty) {
          _logger?.warning('visit.push.quarantined', fields: {
            'table': 'visit_stock_updates',
            'count': quarantined.length,
            'ids': [for (final r in quarantined) r.id],
          });
          await _local.markSynced(
            table: 'visit_stock_updates',
            ids: [for (final r in quarantined) r.id],
          );
        }

        // Stops whose check-in is still on the device — not sent yet, or
        // refused for now. Their check-out and captures wait for it; the next
        // push sends the check-in again, then them.
        final waiting = {
          for (final c in await _local.fetchPendingCheckIns()) c.stopId,
        };
        bool ready(String? stopId) => !waiting.contains(stopId);

        final all = VisitPushBatch(
          checkIns: const [],
          checkOuts: await _local.fetchPendingCheckOuts(),
          orderLines: await _local.fetchPendingOrderLines(),
          stockUpdates: pendingStock.where((r) => !_isUnstorable(r)).toList(),
          returns: await _local.fetchPendingReturns(),
          collections: await _local.fetchPendingCollections(),
          notes: await _local.fetchPendingNotes(),
          photos: await _local.fetchPendingPhotos(),
        );
        final batch = VisitPushBatch(
          checkIns: const [],
          checkOuts: all.checkOuts.where((r) => ready(r.stopId)).toList(),
          orderLines: all.orderLines.where((r) => ready(r.stopId)).toList(),
          stockUpdates: all.stockUpdates.where((r) => ready(r.stopId)).toList(),
          returns: all.returns.where((r) => ready(r.stopId)).toList(),
          collections: all.collections.where((r) => ready(r.stopId)).toList(),
          notes: all.notes.where((r) => ready(r.stopId)).toList(),
          photos: all.photos.where((r) => ready(r.stopId)).toList(),
        );

        final held = all.rowCount - batch.rowCount;
        if (held > 0) {
          // Counts only. A row held here is still pending and still counted
          // as unsent work; it is not lost.
          _logger?.info('visit.push.held_for_check_in', fields: {
            'rows': held,
            'stops': waiting.length,
          });
        }
        return _push(batch);
      });

  /// Every stop with **any** unsent row is its own entry — including a stop
  /// whose check-in and check-out already went and only stock counts, notes
  /// or photos are left, so the rep can see and act on it.
  ///
  /// Rows with no stop (a depot's own stock count) are counted in
  /// [PendingVisitSync.otherRecords]. Stops plus that always add up to
  /// `countPendingVisitRecords`, the figure the sign-out guard uses.
  @override
  ResultFuture<PendingVisitSync> fetchPendingVisits() async {
    try {
      final byStop = <String, _PendingStopTally>{};
      _PendingStopTally at(String stopId) =>
          byStop.putIfAbsent(stopId, _PendingStopTally.new);

      for (final c in await _local.fetchPendingCheckIns()) {
        at(c.stopId)
          ..checkIn = c.timestamp
          ..seen(c.timestamp);
      }
      for (final c in await _local.fetchPendingCheckOuts()) {
        at(c.stopId)
          ..checkOut = c.timestamp
          ..seen(c.timestamp);
      }
      for (final r in await _local.fetchPendingOrderLines()) {
        at(r.stopId).orderLines++;
      }
      var unattributed = 0;
      for (final r in await _local.fetchPendingStockUpdates()) {
        final stopId = r.stopId;
        if (stopId == null) {
          unattributed++;
        } else {
          at(stopId).stockUpdates++;
        }
      }
      for (final r in await _local.fetchPendingReturns()) {
        at(r.stopId).returns++;
      }
      for (final r in await _local.fetchPendingCollections()) {
        at(r.stopId).collections++;
      }
      for (final r in await _local.fetchPendingNotes()) {
        at(r.stopId)
          ..notes += 1
          ..seen(r.createdAt);
      }
      for (final r in await _local.fetchPendingPhotos()) {
        at(r.stopId)
          ..photos += 1
          ..seen(r.takenAt);
      }

      final names = await _local.fetchShopNamesForStops(byStop.keys.toSet());
      final ordered = byStop.entries.toList()
        ..sort((a, b) {
          // Oldest first, the order they are sent in. A stop with nothing
          // timed (order lines and stock counts carry no time) goes last.
          final ta = a.value.first, tb = b.value.first;
          if (ta == null && tb == null) return a.key.compareTo(b.key);
          if (ta == null) return 1;
          if (tb == null) return -1;
          return ta.compareTo(tb);
        });
      final stops = [
        for (final MapEntry(key: stopId, value: t) in ordered)
          PendingVisitStop(
            stopId: stopId,
            shopName: names[stopId]?.name,
            shopNameKh: names[stopId]?.nameKh,
            checkInAt: t.checkIn,
            checkOutAt: t.checkOut,
            orderLines: t.orderLines,
            stockUpdates: t.stockUpdates,
            returns: t.returns,
            collections: t.collections,
            notes: t.notes,
            photos: t.photos,
          ),
      ];
      return Success(
          PendingVisitSync(stops: stops, otherRecords: unattributed));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<VisitStopDiscard> discardPendingStop(String stopId) async {
    final DiscardedStopWork work;
    try {
      work = await _local.discardUnsentStopWork(stopId);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
    // After the commit, never inside it: a deleted file cannot be rolled
    // back. Best effort — a file that will not go is an orphan on disk, not a
    // reason to report a discard that did happen as failed.
    for (final path in work.photoPaths) {
      if (path.isEmpty || path.contains('://')) continue;
      try {
        _deleteFile(path);
      } catch (_) {}
    }
    // Counts only — never the stop, the shop or a path (`security.md` §3).
    _logger?.info('visit.discard', fields: {
      'rows': work.rowsDeleted,
      'photos': work.photoPaths.length,
      'reset': work.reset.name,
    });
    return Success(VisitStopDiscard(
      stopId: stopId,
      discardedRecords: work.rowsDeleted,
      reset: switch (work.reset) {
        StopResetKind.unchanged => VisitStopReset.unchanged,
        StopResetKind.notVisited => VisitStopReset.notVisited,
        StopResetKind.checkedIn => VisitStopReset.checkedIn,
      },
    ));
  }

  /// Sends one batch and marks what the server took (or will never take)
  /// synced.
  Future<VisitPushSummary> _push(VisitPushBatch batch) async {
    if (batch.isEmpty) {
      return VisitPushSummary(pushedCount: 0, syncedAt: DateTime.now());
    }

    final result = await _remote.pushVisitData(batch);
    final accepted = result.acceptedIds.toSet();

    // Rows the server will never store (api.md §6.1). They are retired from
    // the queue, because the alternative is not "try again later" — it is
    // every future push carrying them, forever, on a device that is often
    // metered and always battery-bound.
    //
    // Retiring them reuses `markSynced`, which overstates what happened: the
    // row is gone from the queue but never reached the server. A dedicated
    // `sync_status = 'discarded'` is the honest state and wants a table
    // migration in the DAO layer; until then the log line below is the
    // record that this row died rather than landed. Deliberately loud — a
    // discard is the server telling us the client produced something
    // unstorable, which is a bug report, not routine sync noise.
    final discarded = result.discardedIds.toSet();
    if (discarded.isNotEmpty) {
      _logger?.warning('visit.push.discarded', fields: {
        'count': discarded.length,
        'reasons': {
          for (final id in discarded)
            id: result.discardReasons[id] ?? 'unknown',
        },
      });
    }

    final retired = {...accepted, ...discarded};
    for (final entry in batch.idsByTable().entries) {
      final retiredInTable = entry.value.where(retired.contains).toList();
      await _local.markSynced(table: entry.key, ids: retiredInTable);
    }

    // Counts what the server actually holds. A discarded row is not a pushed
    // row, and reporting it as one would show the rep a success total that
    // includes work no one will ever see.
    return VisitPushSummary(
        pushedCount: accepted.length, syncedAt: result.syncedAt);
  }

  /// The connection check and error mapping every push step shares.
  ResultFuture<VisitPushSummary> _guarded(
      Future<VisitPushSummary> Function() body) async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      return Success(await body());
    } on ApiException catch (e) {
      // Same sibling-type trap as the pull side: [ApiException] is not a
      // [ServerException], so without this branch a 401 escaped the repository
      // and crashed the app. Nothing is marked synced on this path, so every
      // captured row stays pending and the next push retries it.
      return Failed(_failure(e.error));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  /// A stock row already on the device that the push endpoint will refuse.
  ///
  /// **This is cleanup for rows written by an earlier build, and it should be
  /// deleted once no install can still be carrying them.** The writer that
  /// produced them is fixed — `_persistStockUpdates` no longer puts a depot
  /// id in `depotId`, and no longer writes the mock catalog at all — but a
  /// fix at the writer does nothing about rows already sitting `pending` in
  /// Drift. Those rows are what turned one bad capture into a total sync
  /// outage: the endpoint rejects the whole envelope on a row-level
  /// validation fault (contrary to api.md §6.1, which reserves 4xx for an
  /// unusable envelope), so twelve unattributable stock rows took every
  /// check-in, check-out and note in the same request down with them, on every
  /// retry, forever.
  ///
  /// Two shapes are unstorable:
  ///
  /// - **Neither `stopId` nor `depotId`.** Nothing to attach the count to.
  /// - **A mock-catalog `productId`.** The audit screen's demo items are
  ///   `'1'`–`'4'`; no such product exists server-side. Crude, and
  ///   deliberately so — it is a literal match on the four ids that were
  ///   actually shipped, not a heuristic that could swallow a real short
  ///   product code later.
  ///
  /// Quarantining costs the rep nothing real: these rows could never have
  /// reached the server. What it buys is every *other* pending capture getting
  /// through on the next push instead of being held hostage.
  static bool _isUnstorable(VisitStockUpdateModel row) {
    if (row.stopId == null && row.depotId == null) return true;
    return const {'1', '2', '3', '4'}.contains(row.productId);
  }

  /// Maps a transport/API failure onto the domain [Failure] the UI renders.
  ///
  /// Pending rows are never at risk here: this repository only marks rows
  /// synced from the ids the server returned in `acceptedIds`, and no failure
  /// path produces any. A failed push therefore costs a retry, never a
  /// capture.
  Failure _failure(ApiError error) {
    if (error.code == ApiErrorCodes.network) return const NetworkFailure();

    if (error.isUnauthenticated) {
      return AuthenticationFailure(
          message:
              error.message ?? 'Your session expired. Please sign in again.');
    }

    return ServerFailure(
      message: error.message ?? 'Could not sync your visits. Please try again.',
      statusCode: error.statusCode,
    );
  }
}

/// One stop's unsent rows while [VisitSyncRepositoryImpl.fetchPendingVisits]
/// counts them.
class _PendingStopTally {
  DateTime? checkIn;
  DateTime? checkOut;
  int orderLines = 0;
  int stockUpdates = 0;
  int returns = 0;
  int collections = 0;
  int notes = 0;
  int photos = 0;

  /// The earliest time any of the stop's rows carries, for ordering.
  DateTime? first;

  void seen(DateTime at) {
    final f = first;
    if (f == null || at.isBefore(f)) first = at;
  }
}
