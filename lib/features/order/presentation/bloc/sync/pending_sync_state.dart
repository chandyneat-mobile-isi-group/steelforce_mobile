import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/sync_queue_item.dart';

/// Snapshot of the outbound SAP sync queue for the Pending Sync badge/center.
class PendingSyncState extends Equatable {
  const PendingSyncState({
    this.items = const [],
    this.counts = const SyncQueueCounts(),
    this.isSyncing = false,
    this.loaded = false,
  });

  /// FIFO-ordered queue (all statuses), hydrated with quotation display fields.
  final List<SyncQueueItem> items;
  final SyncQueueCounts counts;

  /// True while a drain (Sync Now / retry) is in flight.
  final bool isSyncing;

  /// Whether the first queue snapshot has arrived (distinguishes "empty" from
  /// "not loaded yet" for skeletons).
  final bool loaded;

  PendingSyncState copyWith({
    List<SyncQueueItem>? items,
    SyncQueueCounts? counts,
    bool? isSyncing,
    bool? loaded,
  }) {
    return PendingSyncState(
      items: items ?? this.items,
      counts: counts ?? this.counts,
      isSyncing: isSyncing ?? this.isSyncing,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  List<Object?> get props => [items, counts, isSyncing, loaded];
}
