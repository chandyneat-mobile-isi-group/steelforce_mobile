import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/sync_queue_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/quotation_review.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';
import 'package:steelforce/features/order/domain/repositories/sync_queue_repository.dart';

class SyncQueueRepositoryImpl implements SyncQueueRepository {
  SyncQueueRepositoryImpl(this._local);
  final SyncQueueLocalDataSource _local;

  final StreamController<List<SyncQueueItem>> _controller =
      StreamController<List<SyncQueueItem>>.broadcast();

  @override
  Stream<List<SyncQueueItem>> watchQueue() async* {
    yield await _loadAll();
    yield* _controller.stream;
  }

  Future<List<SyncQueueItem>> _loadAll() async {
    final rows = await _local.fetchAllJoined();
    return rows.map(_fromJoinedRow).toList();
  }

  Future<void> _emit() async {
    if (!_controller.hasListener) return;
    _controller.add(await _loadAll());
  }

  @override
  Future<void> enqueue(String quotationId, {String? ownerUserId}) async {
    final now = DateTime.now();
    final existing = await _local.getByQuotationId(quotationId);
    final SyncQueueItem item;
    if (existing != null) {
      // Re-submit: reuse the row and its backend link, reset retry bookkeeping
      // and the last decision — it is about to be superseded.
      item = _fromRow(existing).copyWith(
        status: QuotationSyncStatus.pendingSync,
        attemptCount: 0,
        updatedAt: now,
        nextRetryAt: () => null,
        lastError: () => null,
        errorCode: () => null,
        decisionReason: () => null,
        ownerUserId: ownerUserId == null ? null : () => ownerUserId,
      );
    } else {
      item = SyncQueueItem(
        id: _newId(),
        quotationId: quotationId,
        status: QuotationSyncStatus.pendingSync,
        attemptCount: 0,
        createdAt: now,
        updatedAt: now,
        ownerUserId: ownerUserId,
      );
    }
    await _local.upsert(_toRow(item));
    await _emit();
  }

  @override
  Future<List<SyncQueueItem>> readyItems(String ownerUserId) async {
    final rows =
        await _local.fetchReady(DateTime.now().toIso8601String(), ownerUserId);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<SyncQueueItem>> awaitingReview(String ownerUserId) async {
    final rows = await _local.fetchAwaitingReview(
        ownerUserId, QuotationRemoteStatus.waiting);
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> save(SyncQueueItem item) async {
    await _local.upsert(_toRow(item));
    await _emit();
  }

  @override
  Future<SyncQueueCounts> counts() async {
    final byStatus = await _local.countsByStatus();
    int count(QuotationSyncStatus status) => byStatus[status.name] ?? 0;
    return SyncQueueCounts(
      pending: count(QuotationSyncStatus.pendingSync) +
          count(QuotationSyncStatus.syncing) +
          count(QuotationSyncStatus.submitted),
      failed: count(QuotationSyncStatus.failed) +
          count(QuotationSyncStatus.rejected),
      conflict: count(QuotationSyncStatus.conflict),
      accepted: count(QuotationSyncStatus.accepted),
      returned: count(QuotationSyncStatus.returned),
    );
  }

  @override
  Future<void> remove(String quotationId) async {
    await _local.deleteByQuotationId(quotationId);
    await _emit();
  }

  // ── Mapping ────────────────────────────────────────────────────────────
  //
  // `upsert` is INSERT OR REPLACE over the full column list, so every column
  // must be written here — one left out is silently nulled on the next save.
  // The legacy `sap_*` columns are written as null: nothing produces them now.
  DataMap _toRow(SyncQueueItem item) => {
        'id': item.id,
        'quotation_id': item.quotationId,
        'status': item.status.name,
        'attempt_count': item.attemptCount,
        'next_retry_at': item.nextRetryAt?.toIso8601String(),
        'last_error': item.lastError,
        'error_code': item.errorCode,
        'sap_document_number': null,
        'sap_message': null,
        'sap_timestamp': null,
        'sync_duration_ms': item.syncDurationMs,
        'remote_quotation_id': item.remoteQuotationId,
        'remote_number': item.remoteNumber,
        'remote_status': item.remoteStatus,
        'decision_reason': item.decisionReason,
        'remote_checked_at': item.remoteCheckedAt?.toIso8601String(),
        'owner_user_id': item.ownerUserId,
        'created_at': item.createdAt.toIso8601String(),
        'updated_at': item.updatedAt.toIso8601String(),
      };

  SyncQueueItem _fromRow(DataMap row) => SyncQueueItem(
        id: row['id'] as String,
        quotationId: row['quotation_id'] as String,
        status: QuotationSyncStatus.fromName(row['status'] as String?),
        attemptCount: (row['attempt_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
        nextRetryAt: _parseDate(row['next_retry_at']),
        lastError: row['last_error'] as String?,
        errorCode: row['error_code'] as String?,
        syncDurationMs: (row['sync_duration_ms'] as num?)?.toInt(),
        remoteQuotationId: row['remote_quotation_id'] as String?,
        remoteNumber: row['remote_number'] as String?,
        remoteStatus: row['remote_status'] as String?,
        decisionReason: row['decision_reason'] as String?,
        remoteCheckedAt: _parseDate(row['remote_checked_at']),
        ownerUserId: row['owner_user_id'] as String?,
      );

  SyncQueueItem _fromJoinedRow(DataMap row) {
    final base = _fromRow(row);
    final linesJson = row['lines_json'] as String?;
    int? itemCount;
    if (linesJson != null) {
      try {
        itemCount = (jsonDecode(linesJson) as List).length;
      } catch (_) {
        itemCount = null;
      }
    }
    return SyncQueueItem(
      id: base.id,
      quotationId: base.quotationId,
      status: base.status,
      attemptCount: base.attemptCount,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      nextRetryAt: base.nextRetryAt,
      lastError: base.lastError,
      errorCode: base.errorCode,
      syncDurationMs: base.syncDurationMs,
      remoteQuotationId: base.remoteQuotationId,
      remoteNumber: base.remoteNumber,
      remoteStatus: base.remoteStatus,
      decisionReason: base.decisionReason,
      remoteCheckedAt: base.remoteCheckedAt,
      ownerUserId: base.ownerUserId,
      shopName: row['shop_name'] as String?,
      itemCount: itemCount,
      total: (row['q_total'] as num?)?.toDouble(),
    );
  }

  static DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  static final Random _random = Random.secure();
  static String _newId() => 'SQ-${DateTime.now().microsecondsSinceEpoch}-'
      '${_random.nextInt(0x7fffffff).toRadixString(36)}';
}
