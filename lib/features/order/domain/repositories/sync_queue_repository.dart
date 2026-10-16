import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';

/// The outbound queue to the Admin backend — the single source of truth for
/// which quotations are waiting to be submitted for review, and what the
/// backend has said about the ones already submitted. Event-driven (a live
/// [watchQueue] stream) rather than `Result`-wrapped: the sync subsystem is
/// internal plumbing, and callers react to the stream.
abstract interface class SyncQueueRepository {
  /// Live, FIFO-ordered queue (initial snapshot then updates on every change).
  Stream<List<SyncQueueItem>> watchQueue();

  /// Enqueues [quotationId] as `pendingSync` for [ownerUserId]. If it is
  /// already queued it is reset to `pendingSync` (attempt 0) — e.g. the rep
  /// resubmitting a failed or returned quotation. The backend link is kept, so
  /// the resubmit reuses the same document.
  Future<void> enqueue(String quotationId, {String? ownerUserId});

  /// Items [ownerUserId] may push right now (FIFO), backoff respected.
  Future<List<SyncQueueItem>> readyItems(String ownerUserId);

  /// Items [ownerUserId] submitted whose review is still open on the backend.
  Future<List<SyncQueueItem>> awaitingReview(String ownerUserId);

  /// Persists a state transition produced by the processor.
  Future<void> save(SyncQueueItem item);

  /// Aggregate counts for the pending badge.
  Future<SyncQueueCounts> counts();

  /// Removes a quotation from the queue (e.g. draft discarded).
  Future<void> remove(String quotationId);
}
