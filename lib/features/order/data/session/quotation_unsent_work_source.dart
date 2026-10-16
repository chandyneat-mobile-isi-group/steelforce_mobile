import 'package:steelforce/core/session/unsent_work.dart';
import 'package:steelforce/features/order/data/local/sync_queue_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/quotation_sync_status.dart';

/// Quotations the rep queued that the backend does not have yet.
///
/// Counts what is still waiting to go (`pendingSync`, `syncing`, `submitted`)
/// and what stopped on the way and needs the rep (`failed`, `conflict`) — the
/// Sync Center offers Retry or Discard for those, so a rep is never stuck.
/// `accepted`, `rejected` and `returned` are already on the server.
class QuotationUnsentWorkSource
    implements UnsentWorkSource, UnsentWorkBreakdown {
  const QuotationUnsentWorkSource(this._queue, {required this.send});

  final SyncQueueLocalDataSource _queue;

  /// The sync coordinator's "Sync Now". A callback because the coordinator is
  /// a presentation service this data-layer class must not import.
  final Future<void> Function() send;

  static final unsentStatuses = <String>{
    QuotationSyncStatus.pendingSync.name,
    QuotationSyncStatus.syncing.name,
    QuotationSyncStatus.submitted.name,
    QuotationSyncStatus.failed.name,
    QuotationSyncStatus.conflict.name,
  };

  static const name = 'order.sync_queue';

  @override
  String get debugName => name;

  @override
  Future<int> countUnsent() async {
    final byStatus = await _queue.countsByStatus();
    var total = 0;
    for (final entry in byStatus.entries) {
      if (unsentStatuses.contains(entry.key)) total += entry.value;
    }
    return total;
  }

  /// Only what the coordinator still sends on its own; `failed` and
  /// `conflict` wait for the rep's Retry or Discard.
  static final sendableStatuses = <String>{
    QuotationSyncStatus.pendingSync.name,
    QuotationSyncStatus.syncing.name,
    QuotationSyncStatus.submitted.name,
  };

  @override
  Future<int> countSendable() async {
    final byStatus = await _queue.countsByStatus();
    var total = 0;
    for (final entry in byStatus.entries) {
      if (sendableStatuses.contains(entry.key)) total += entry.value;
    }
    return total;
  }

  @override
  Future<void> sendNow() => send();

  @override
  Future<List<UnsentWorkCount>> breakdown() async {
    final unsent = await countUnsent();
    final sendable = await countSendable();
    return [
      UnsentWorkCount(UnsentWorkKind.quotations, unsent,
          needsAction: unsent - sendable),
    ];
  }
}
