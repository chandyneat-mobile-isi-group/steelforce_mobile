import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/order/domain/entities/admin_submit_result.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/quotation_review.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';
import 'package:steelforce/features/order/domain/services/quotation_admin_gateway.dart';

/// Backoff between retries of a transport failure, after which the item moves
/// to `failed` and waits for the rep. Sized for field connectivity, where a
/// dead zone lasts minutes, not seconds: the old 5s/15s/30s schedule spent all
/// three attempts inside one tunnel. Attempts are only spent while the device
/// is actually online — [SyncQueueProcessor.processAll] returns before trying
/// anything when it is not.
const List<Duration> kSyncRetryBackoffs = [
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
  Duration(minutes: 30),
  Duration(hours: 1),
];

/// Moves saved quotations from the device to the Admin backend for review, and
/// reads the administrator's decisions back.
///
/// It does not schedule itself — `QuotationSyncCoordinator` decides when to
/// run it (reconnect, resume, a new item, a due retry). Every state transition
/// is persisted, so progress survives an app kill. Nothing here navigates or
/// interrupts the rep.
class SyncQueueProcessor {
  SyncQueueProcessor({
    required SyncQueueRepository queue,
    required QuotationRepository quotations,
    required QuotationAdminGateway gateway,
    required NetworkInfo network,
    required String? Function() currentUserId,
  })  : _queue = queue,
        _quotations = quotations,
        _gateway = gateway,
        _network = network,
        _currentUserId = currentUserId;

  final SyncQueueRepository _queue;
  final QuotationRepository _quotations;
  final QuotationAdminGateway _gateway;
  final NetworkInfo _network;

  /// The signed-in rep. Null when nobody is — then nothing is pushed, because
  /// every request would go out under no one's authority.
  final String? Function() _currentUserId;

  bool _running = false;

  /// True while a drain is in progress — lets callers avoid overlapping runs.
  bool get isRunning => _running;

  /// Pushes the rep's ready items oldest-first until the queue is drained or
  /// the device goes offline. Re-entrancy-guarded.
  Future<void> processAll() async {
    if (_running) return;
    final owner = _currentUserId();
    if (owner == null) return;
    _running = true;
    try {
      if (!await _network.isConnected) return;
      // A safety cap so a persistently-rescheduling item cannot spin forever.
      var guard = 0;
      while (guard++ < 1000) {
        if (!await _network.isConnected) break;
        final ready = await _queue.readyItems(owner);
        if (ready.isEmpty) break;
        await _processOne(ready.first, owner);
      }
    } finally {
      _running = false;
    }
  }

  /// Reads back the review state of everything the rep has submitted and the
  /// administrator has not finished with. A transport failure leaves the last
  /// known state in place; the next run tries again.
  Future<void> refreshReviews() async {
    final owner = _currentUserId();
    if (owner == null) return;
    if (!await _network.isConnected) return;

    final open = await _queue.awaitingReview(owner);
    if (open.isEmpty) return;

    final List<QuotationReview> reviews;
    try {
      reviews = await _gateway
          .fetchReviews([for (final i in open) i.remoteQuotationId!]);
    } catch (_) {
      return;
    }
    final byId = {for (final r in reviews) r.remoteId: r};
    for (final item in open) {
      final review = byId[item.remoteQuotationId];
      if (review != null) await _applyReview(item, review);
    }
  }

  Future<void> _processOne(SyncQueueItem queued, String owner) async {
    final startedAt = DateTime.now();
    var item = queued.copyWith(
      status: QuotationSyncStatus.syncing,
      updatedAt: startedAt,
      ownerUserId: queued.ownerUserId == null ? () => owner : null,
    );
    await _queue.save(item);

    final quotation = await _loadQuotation(item.quotationId);
    if (quotation == null) {
      // The draft is gone — nothing to push; drop it from the queue.
      await _queue.remove(item.quotationId);
      return;
    }

    final attemptsMade = item.attemptCount + 1;
    final result = await _gateway.submit(
      quotation,
      remoteId: item.remoteQuotationId ?? quotation.remoteId,
      onRemoteCreated: (remoteId) async {
        // Persisted on both sides before any line is sent: if the app dies
        // now, the next attempt finds this document instead of opening
        // another.
        await _quotations.linkRemote(quotation.id, remoteId);
        item = item.copyWith(remoteQuotationId: () => remoteId);
        await _queue.save(item);
      },
    );
    final durationMs = DateTime.now().difference(startedAt).inMilliseconds;
    final now = DateTime.now();

    switch (result) {
      case AdminSubmitted(:final remoteId, :final number, :final remoteStatus):
        if (quotation.remoteId != remoteId) {
          await _quotations.linkRemote(quotation.id, remoteId);
        }
        await _queue.save(item.copyWith(
          status: QuotationSyncStatus.accepted,
          attemptCount: attemptsMade,
          updatedAt: now,
          nextRetryAt: () => null,
          lastError: () => null,
          errorCode: () => null,
          syncDurationMs: () => durationMs,
          remoteQuotationId: () => remoteId,
          remoteNumber: () => number,
          remoteStatus: () => remoteStatus,
          decisionReason: () => null,
          remoteCheckedAt: () => now,
        ));
      case AdminRejected(:final errorCode, :final message, :final remoteId):
        await _queue.save(item.copyWith(
          status: QuotationSyncStatus.rejected,
          attemptCount: attemptsMade,
          updatedAt: now,
          nextRetryAt: () => null,
          lastError: () => message,
          errorCode: () => errorCode,
          syncDurationMs: () => durationMs,
          remoteQuotationId: remoteId == null ? null : () => remoteId,
        ));
      case AdminNeedsReview(:final errorCode, :final message, :final remoteId):
        await _queue.save(item.copyWith(
          status: QuotationSyncStatus.conflict,
          attemptCount: attemptsMade,
          updatedAt: now,
          nextRetryAt: () => null,
          lastError: () => message,
          errorCode: () => errorCode,
          syncDurationMs: () => durationMs,
          remoteQuotationId: () => remoteId,
          // Unread on purpose: [refreshReviews] picks up a conflict with no
          // status, and notices when the rep resolves it on the document.
          remoteStatus: () => null,
        ));
      case AdminTransportFailure(:final message, :final errorCode):
        await _applyRetryOrFail(
            item, attemptsMade, message, errorCode, durationMs);
    }
  }

  Future<void> _applyReview(SyncQueueItem item, QuotationReview review) {
    final now = DateTime.now();
    final status = review.status;

    final QuotationSyncStatus next;
    String? errorCode;
    if (status == null) {
      // The backend no longer shows it to this rep.
      next = QuotationSyncStatus.rejected;
      errorCode = 'Quotation.NotFound';
    } else if (status == QuotationRemoteStatus.returned) {
      next = QuotationSyncStatus.returned;
    } else if (status == QuotationRemoteStatus.rejected ||
        status == QuotationRemoteStatus.cancelled) {
      next = QuotationSyncStatus.rejected;
      errorCode = 'Quotation.$status';
    } else if (status == QuotationRemoteStatus.draft) {
      // Still a draft: only a conflict can be here (a submitted document does
      // not go back to Draft). The rep has not resolved it yet.
      next = item.status;
      errorCode = item.errorCode;
    } else {
      // In review or past it — Approved and the SAP phases the portal drives.
      next = QuotationSyncStatus.accepted;
    }

    return _queue.save(item.copyWith(
      status: next,
      updatedAt: now,
      errorCode: () => errorCode,
      lastError: next == QuotationSyncStatus.accepted ? () => null : null,
      remoteStatus: () => status,
      remoteNumber: review.number == null ? null : () => review.number,
      decisionReason: () => review.decisionReason,
      remoteCheckedAt: () => now,
    ));
  }

  Future<void> _applyRetryOrFail(SyncQueueItem item, int attemptsMade,
      String message, String? errorCode, int durationMs) {
    // attemptsMade maps to a backoff slot; past the last one the item fails.
    if (attemptsMade > kSyncRetryBackoffs.length) {
      return _queue.save(item.copyWith(
        status: QuotationSyncStatus.failed,
        attemptCount: attemptsMade,
        updatedAt: DateTime.now(),
        nextRetryAt: () => null,
        lastError: () => message,
        errorCode: () => errorCode,
        syncDurationMs: () => durationMs,
      ));
    }
    final backoff = kSyncRetryBackoffs[attemptsMade - 1];
    return _queue.save(item.copyWith(
      status: QuotationSyncStatus.pendingSync,
      attemptCount: attemptsMade,
      updatedAt: DateTime.now(),
      nextRetryAt: () => DateTime.now().add(backoff),
      lastError: () => message,
      errorCode: () => errorCode,
      syncDurationMs: () => durationMs,
    ));
  }

  Future<Quotation?> _loadQuotation(String id) async {
    final result = await _quotations.getQuotationById(id);
    return result.when(success: (q) => q, failure: (_) => null);
  }
}
