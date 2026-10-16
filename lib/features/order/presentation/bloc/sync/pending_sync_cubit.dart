import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';
import 'package:steelforce/features/order/presentation/bloc/sync/pending_sync_state.dart';
import 'package:steelforce/features/order/presentation/services/quotation_sync_coordinator.dart';

/// Drives the Pending Sync badge and Sync Center.
///
/// Sync is automatic — [QuotationSyncCoordinator] pushes queued quotations to
/// the Admin backend on its own and reads decisions back. This cubit starts it
/// for the signed-in shell, mirrors whether a run is in progress, and exposes
/// the rep's explicit actions: **Sync Now**, **Retry**, and **discard**.
class PendingSyncCubit extends Cubit<PendingSyncState> {
  PendingSyncCubit({
    required SyncQueueRepository repository,
    required QuotationSyncCoordinator coordinator,
    required String? Function() currentUserId,
  })  : _repository = repository,
        _coordinator = coordinator,
        _currentUserId = currentUserId,
        super(const PendingSyncState()) {
    _subscription = _repository.watchQueue().listen(_onQueue);
    _runningSub = _coordinator.running.listen((running) {
      if (!isClosed) emit(state.copyWith(isSyncing: running));
    });
    _coordinator.start();
  }

  final SyncQueueRepository _repository;
  final QuotationSyncCoordinator _coordinator;
  final String? Function() _currentUserId;
  late final StreamSubscription<List<SyncQueueItem>> _subscription;
  late final StreamSubscription<bool> _runningSub;

  void _onQueue(List<SyncQueueItem> items) {
    if (isClosed) return;
    emit(state.copyWith(items: items, counts: _countsOf(items), loaded: true));
  }

  /// Pushes now instead of waiting for the next automatic trigger.
  Future<void> syncNow() => _coordinator.runNow();

  /// Queues a saved quotation for Admin review. The coordinator picks it up on
  /// its own as soon as the device is online.
  Future<void> enqueue(String quotationId) =>
      _repository.enqueue(quotationId, ownerUserId: _currentUserId());

  /// Re-queues a failed/rejected/returned item and tries again straight away.
  Future<void> retry(String quotationId) async {
    await enqueue(quotationId);
    await syncNow();
  }

  /// Removes an item from the queue entirely (rep chose not to sync it).
  Future<void> discard(String quotationId) => _repository.remove(quotationId);

  static SyncQueueCounts _countsOf(List<SyncQueueItem> items) {
    var pending = 0, failed = 0, conflict = 0, accepted = 0, returned = 0;
    for (final item in items) {
      switch (item.status) {
        case QuotationSyncStatus.pendingSync:
        case QuotationSyncStatus.syncing:
        case QuotationSyncStatus.submitted:
          pending++;
        case QuotationSyncStatus.failed:
        case QuotationSyncStatus.rejected:
          failed++;
        case QuotationSyncStatus.conflict:
          conflict++;
        case QuotationSyncStatus.accepted:
          accepted++;
        case QuotationSyncStatus.returned:
          returned++;
        case QuotationSyncStatus.draft:
        case QuotationSyncStatus.readyToSubmit:
          break;
      }
    }
    return SyncQueueCounts(
      pending: pending,
      failed: failed,
      conflict: conflict,
      accepted: accepted,
      returned: returned,
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _runningSub.cancel();
    await _coordinator.stop();
    return super.close();
  }
}
