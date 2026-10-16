import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';

/// One quotation's slot in the outbound queue to the Admin backend. Ordered
/// FIFO by [createdAt]. Sync state lives here (not on the quotation row) so the
/// queue is decoupled from quotation persistence.
///
/// The optional [shopName]/[itemCount]/[total] are display fields hydrated by a
/// join with the `quotations` table when listing the Sync Center — they are
/// null on the bare row read during processing.
class SyncQueueItem extends Equatable {
  const SyncQueueItem({
    required this.id,
    required this.quotationId,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.nextRetryAt,
    this.lastError,
    this.errorCode,
    this.syncDurationMs,
    this.remoteQuotationId,
    this.remoteNumber,
    this.remoteStatus,
    this.decisionReason,
    this.remoteCheckedAt,
    this.ownerUserId,
    this.shopName,
    this.itemCount,
    this.total,
  });

  final String id;
  final String quotationId;
  final QuotationSyncStatus status;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Earliest time this item may be retried (backoff). Null = eligible now.
  final DateTime? nextRetryAt;

  /// Developer detail from the last failure. Logs only — the UI localizes
  /// from [errorCode].
  final String? lastError;

  /// The contract's stable `errorCode` for the last failure.
  final String? errorCode;
  final int? syncDurationMs;

  // ── Admin backend ─────────────────────────────────────────────────────
  /// The backend document this quotation became.
  final String? remoteQuotationId;

  /// The backend's document number, shown to the rep once assigned.
  final String? remoteNumber;

  /// The backend's `status` code as last read (`PendingApproval`, …).
  final String? remoteStatus;

  /// Why an administrator returned or rejected it.
  final String? decisionReason;
  final DateTime? remoteCheckedAt;

  /// The rep whose session queued it; only that rep's session pushes it.
  final String? ownerUserId;

  // ── Display join fields (nullable) ────────────────────────────────────
  final String? shopName;
  final int? itemCount;
  final double? total;

  /// Ready to be picked up by the FIFO processor right now.
  bool isReady(DateTime now) =>
      status == QuotationSyncStatus.pendingSync &&
      (nextRetryAt == null || !nextRetryAt!.isAfter(now));

  SyncQueueItem copyWith({
    QuotationSyncStatus? status,
    int? attemptCount,
    DateTime? updatedAt,
    DateTime? Function()? nextRetryAt,
    String? Function()? lastError,
    String? Function()? errorCode,
    int? Function()? syncDurationMs,
    String? Function()? remoteQuotationId,
    String? Function()? remoteNumber,
    String? Function()? remoteStatus,
    String? Function()? decisionReason,
    DateTime? Function()? remoteCheckedAt,
    String? Function()? ownerUserId,
  }) {
    return SyncQueueItem(
      id: id,
      quotationId: quotationId,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextRetryAt: nextRetryAt != null ? nextRetryAt() : this.nextRetryAt,
      lastError: lastError != null ? lastError() : this.lastError,
      errorCode: errorCode != null ? errorCode() : this.errorCode,
      syncDurationMs:
          syncDurationMs != null ? syncDurationMs() : this.syncDurationMs,
      remoteQuotationId: remoteQuotationId != null
          ? remoteQuotationId()
          : this.remoteQuotationId,
      remoteNumber: remoteNumber != null ? remoteNumber() : this.remoteNumber,
      remoteStatus: remoteStatus != null ? remoteStatus() : this.remoteStatus,
      decisionReason:
          decisionReason != null ? decisionReason() : this.decisionReason,
      remoteCheckedAt:
          remoteCheckedAt != null ? remoteCheckedAt() : this.remoteCheckedAt,
      ownerUserId: ownerUserId != null ? ownerUserId() : this.ownerUserId,
      shopName: shopName,
      itemCount: itemCount,
      total: total,
    );
  }

  @override
  List<Object?> get props => [
        id,
        quotationId,
        status,
        attemptCount,
        createdAt,
        updatedAt,
        nextRetryAt,
        lastError,
        errorCode,
        syncDurationMs,
        remoteQuotationId,
        remoteNumber,
        remoteStatus,
        decisionReason,
        remoteCheckedAt,
        ownerUserId,
        shopName,
        itemCount,
        total,
      ];
}

/// Aggregate counts for the Sync Center badge/header.
class SyncQueueCounts extends Equatable {
  const SyncQueueCounts({
    this.pending = 0,
    this.failed = 0,
    this.conflict = 0,
    this.accepted = 0,
    this.returned = 0,
  });

  final int pending;
  final int failed;
  final int conflict;
  final int accepted;

  /// Sent back by an administrator — the rep's turn again.
  final int returned;

  /// What the MainShell badge shows — everything still demanding attention.
  int get outstanding => pending + failed + conflict + returned;

  @override
  List<Object?> get props => [pending, failed, conflict, accepted, returned];
}
