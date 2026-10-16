import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';
import 'package:steelforce/features/order/domain/usecases/count_products.dart';
import 'package:steelforce/features/order/domain/usecases/get_last_synced_at.dart';
import 'package:steelforce/features/order/domain/usecases/run_delta_sync.dart';
import 'package:steelforce/features/order/domain/usecases/run_initial_sync.dart';
import 'package:steelforce/features/order/presentation/bloc/catalog/sync_state.dart';

/// Drives the sync progress banner. Online-first: every catalog entry pulls
/// from the API — the full catalog when the device has none (first launch, or
/// after sign-out wiped it), a delta otherwise — and the screens read the
/// local copy that pull writes. Offline, the delta fails fast and the screens
/// read what is already on the device without a red banner: being offline is
/// the normal case, not an error.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required RunInitialSync runInitialSync,
    required RunDeltaSync runDeltaSync,
    required GetLastSyncedAt getLastSyncedAt,
    required CountProducts countProducts,
    required SessionManager sessionManager,
  })  : _runInitialSync = runInitialSync,
        _runDeltaSync = runDeltaSync,
        _getLastSyncedAt = getLastSyncedAt,
        _countProducts = countProducts,
        _sessionManager = sessionManager,
        super(const SyncIdle());

  final RunInitialSync _runInitialSync;
  final RunDeltaSync _runDeltaSync;
  final GetLastSyncedAt _getLastSyncedAt;
  final CountProducts _countProducts;
  final SessionManager _sessionManager;

  /// Runs the initial pull when the device has never synced **or** when it has
  /// a sync timestamp but no catalog behind it.
  ///
  /// The timestamp alone is not enough evidence. A device that synced under a
  /// previous taxonomy, or whose catalog was cleared by a migration, carries a
  /// perfectly good "last synced" date over an empty products table — and the
  /// old check read that as "nothing to do", leaving the rep on an empty
  /// category picker with no way to recover. When the timestamp and the
  /// catalog disagree, the catalog wins.
  Future<void> syncIfNeeded() async {
    final lastSynced = await _getLastSyncedAt(const NoParams());
    final neverSynced =
        lastSynced.when(success: (at) => at == null, failure: (_) => true);

    if (neverSynced) return _run(isInitial: true);

    final count = await _countProducts(
      const BrowseProductsParams(page: 0, pageSize: 1),
    );
    final catalogEmpty =
        count.when(success: (n) => n == 0, failure: (_) => false);
    if (catalogEmpty) return _run(isInitial: true);

    // Already have a catalog: still ask the API what changed, so prices and
    // availability are the server's, not whatever the last session left.
    await _run(isInitial: false, quietOffline: true);
  }

  Future<void> refresh() => _run(isInitial: false);

  Future<void> _run(
      {required bool isInitial, bool quietOffline = false}) async {
    if (isClosed) return;
    emit(SyncInProgress(isInitial: isInitial));
    final scope = SyncScope.forCurrentUser(_sessionManager);
    final result =
        isInitial ? await _runInitialSync(scope) : await _runDeltaSync(scope);
    if (isClosed) return;
    result.when(
      success: (r) => emit(SyncSucceeded(
          upserted: r.upserted, deleted: r.deleted, syncedAt: r.syncedAt)),
      failure: (f) => emit(quietOffline && f is NetworkFailure
          ? const SyncIdle()
          : SyncFailed(f.message)),
    );
  }
}
