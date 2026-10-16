import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/depots/domain/usecases/browse_depots.dart';
import 'package:steelforce/features/depots/domain/usecases/depot_params.dart';
import 'package:steelforce/features/depots/domain/usecases/get_depot_last_synced_at.dart';
import 'package:steelforce/features/depots/domain/usecases/run_depot_initial_sync.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/usecases/get_route_last_synced_at.dart';
import 'package:steelforce/features/my_visits/domain/usecases/push_pending_visit_data.dart';
import 'package:steelforce/features/my_visits/domain/usecases/run_route_delta_sync.dart';
import 'package:steelforce/features/my_visits/domain/usecases/run_route_initial_sync.dart';
import 'package:steelforce/features/my_visits/presentation/bloc/state/route_sync_state.dart';

/// Mirrors `order`'s `SyncCubit` shape exactly. Also owns the visit-data
/// *push* side ([pushPending]) — kept on the same cubit rather than a
/// parallel one since this is already the feature's single sync
/// orchestrator the UI talks to.
class RouteSyncCubit extends Cubit<RouteSyncState> {
  RouteSyncCubit({
    required RunRouteInitialSync runInitialSync,
    required RunRouteDeltaSync runDeltaSync,
    required GetRouteLastSyncedAt getLastSyncedAt,
    required PushPendingVisitData pushPendingVisitData,
    required RunDepotInitialSync runDepotInitialSync,
    required GetDepotLastSyncedAt getDepotLastSyncedAt,
    required BrowseDepots browseDepots,
    required SessionManager sessionManager,
  })  : _runInitialSync = runInitialSync,
        _runDeltaSync = runDeltaSync,
        _getLastSyncedAt = getLastSyncedAt,
        _pushPendingVisitData = pushPendingVisitData,
        _runDepotInitialSync = runDepotInitialSync,
        _getDepotLastSyncedAt = getDepotLastSyncedAt,
        _browseDepots = browseDepots,
        _sessionManager = sessionManager,
        super(const RouteSyncIdle());

  final RunRouteInitialSync _runInitialSync;
  final RunRouteDeltaSync _runDeltaSync;
  final GetRouteLastSyncedAt _getLastSyncedAt;
  final PushPendingVisitData _pushPendingVisitData;
  final RunDepotInitialSync _runDepotInitialSync;
  final GetDepotLastSyncedAt _getDepotLastSyncedAt;
  final BrowseDepots _browseDepots;
  final SessionManager _sessionManager;

  /// Pulls routes whenever the dashboard opens.
  ///
  /// Unlike `order`'s catalog (date-agnostic products, synced once), routes are
  /// **day-scoped**: the dashboard filters strictly to the selected day, so a
  /// watermark left by *any* prior sync must NOT suppress pulling the current
  /// day's routes — otherwise a returning rep sees an empty "today" until they
  /// manually pull-to-refresh. So: run an **initial** sync when there's no
  /// watermark yet, and a **delta** on every subsequent open (a real backend
  /// returns routes published since the watermark; the mock returns the current
  /// day's set). Either way today's routes always land locally.
  ///
  /// Online-first: callers await this *before* rendering, and it now also runs
  /// every time the tab is shown again, so concurrent calls share one pull
  /// rather than stacking page loops.
  Future<void> syncIfNeeded() =>
      _inFlight ??= _pullLatest().whenComplete(() => _inFlight = null);

  Future<void>? _inFlight;

  Future<void> _pullLatest() async {
    final lastSynced = await _getLastSyncedAt(const NoParams());
    final needsInitial =
        lastSynced.when(success: (at) => at == null, failure: (_) => true);
    await _run(isInitial: needsInitial);
  }

  Future<void> refresh() => _run(isInitial: false);

  /// True when the SAP depot directory has to be pulled before routes can
  /// be.
  ///
  /// Two independent facts have to agree: a watermark saying we pulled once,
  /// and rows actually being there. Either one alone is a false negative —
  /// this is the same "timestamp says synced, table says empty" trap the
  /// catalog's `SyncCubit` guards against, and it costs one indexed read of a
  /// single row to close.
  Future<bool> _depotDirectoryNeedsPull() async {
    final watermark = await _getDepotLastSyncedAt(const NoParams());
    final neverSynced =
        watermark.when(success: (at) => at == null, failure: (_) => true);
    if (neverSynced) return true;

    final page = await _browseDepots(
      const BrowseDepotsParams(page: 0, pageSize: 1),
    );
    return page.when(
      success: (depots) => depots.items.isEmpty,
      // A read failure is not evidence of emptiness; re-pulling on every open
      // would be worse than trusting the watermark we already have.
      failure: (_) => false,
    );
  }

  Future<void> _run({required bool isInitial}) async {
    if (isClosed) return;
    emit(RouteSyncInProgress(isInitial: isInitial));

    // Hard ordering dependency (ADR-001): `route_stops.depot_id` is a real
    // FK into the SAP-owned depot directory, and route sync can never
    // invent a depot — the directory must exist locally before any route
    // pull. The shell kicks depot sync off asynchronously at startup, so on
    // a fresh install (empty DB, no watermark) a rep can reach this screen
    // before it lands — which surfaced as a FOREIGN KEY / "run Depot Sync
    // first" failure on first launch. Awaiting the depot initial sync here
    // closes that race on every entry point (first open, pull-to-refresh,
    // retry). Skipped entirely once the depot watermark exists; at worst it
    // races the shell's own sync into a double-run of an idempotent upsert.
    // The watermark alone is not enough evidence that the directory is there.
    // A device that synced depots under an older build, or whose depot
    // rows were cleared by a migration, keeps a perfectly valid timestamp over
    // an empty table — and this gate then skipped the pull, after which the
    // route feed (which rebases stops onto real depot ids) failed with
    // "run Depot Sync first" and every Visit screen came up blank. When the
    // watermark and the table disagree, the table wins.
    if (await _depotDirectoryNeedsPull()) {
      final depotSync = await _runDepotInitialSync(const NoParams());
      if (isClosed) return;
      final blocked = depotSync.when(
        success: (_) => false,
        failure: (f) {
          emit(RouteSyncFailed(f.message));
          return true;
        },
      );
      if (blocked) return;
    }

    final scope = RouteSyncScope.forCurrentUser(_sessionManager);
    final result =
        isInitial ? await _runInitialSync(scope) : await _runDeltaSync(scope);
    if (isClosed) return;
    result.when(
      success: (r) =>
          emit(RouteSyncSucceeded(upserted: r.upserted, syncedAt: r.syncedAt)),
      failure: (f) => emit(RouteSyncFailed(f.message)),
    );
  }

  /// Pushes locally-pending visit-capture rows (check-ins, stock counts,
  /// notes, photos, ...). Reuses the same state hierarchy as the pull side
  /// — no dedicated push states, since the UI only needs "in progress /
  /// succeeded / failed" either way.
  Future<void> pushPending() async {
    emit(const RouteSyncInProgress(isInitial: false));
    final result = await _pushPendingVisitData(const NoParams());
    result.when(
      success: (summary) => emit(RouteSyncSucceeded(
          upserted: summary.pushedCount, syncedAt: summary.syncedAt)),
      failure: (f) => emit(RouteSyncFailed(f.message)),
    );
  }
}
