import 'package:steelforce/features/depots/data/models/depot_model.dart';

/// One page of the initial (full) sync.
class DepotInitialPage {
  const DepotInitialPage({
    required this.items,
    required this.hasMore,
    this.syncTimestamp,
    this.pageSize,
  });

  final List<DepotModel> items;
  final bool hasMore;

  /// The server's clock, from `metadata.syncTimestamp`. The watermark for the
  /// next delta comes from here and **never** from the device clock.
  final DateTime? syncTimestamp;

  /// The size the server actually used. It clamps rather than rejects, so this
  /// may be smaller than what was asked for.
  final int? pageSize;
}

/// One delta response, already split into upserts and tombstones.
class DepotDeltaPage {
  const DepotDeltaPage({
    required this.upserted,
    required this.deletedIds,
    this.hasMore = false,
    this.syncTimestamp,
  });

  final List<DepotModel> upserted;

  /// Ids of rows the server reported as `deleted: true`.
  ///
  /// **These must be applied.** Without tombstones a record deleted on the
  /// server simply stops appearing in the delta and lingers on the phone
  /// indefinitely — the classic offline-sync data leak.
  final List<String> deletedIds;

  final bool hasMore;
  final DateTime? syncTimestamp;
}
