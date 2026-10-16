import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';

/// Read access to the SAP Depot Helper master-data lists, cache-first.
///
/// There is intentionally **no `parent` parameter** on [fetch]: the Helper API
/// exposes no parent-scoped filter and its rows carry no foreign keys, so a
/// cascade cannot be expressed against it (ADR-009, findings 1–2). Should the
/// backend later gain sales-area scoping, adding an optional parameter here is
/// additive and breaks no caller.
abstract interface class MasterDataRepository {
  /// Returns [type]'s rows, preferring valid cached data and falling back to the
  /// remote source only on a cache miss or expiry.
  ///
  /// Never throws for want of connectivity: if the network is unavailable and a
  /// cached copy exists — even a stale one — the cached copy is returned, because
  /// a usable stale dropdown beats a blocked screen (`docs/blueprint/offline-architecture.md` §1).
  Future<MasterDataResult> fetch(MasterDataType type);

  /// Forces a network read and rewrites the cache. Used by explicit
  /// pull-to-refresh only — never automatically, so static reference data is not
  /// re-fetched on every screen open.
  Future<MasterDataResult> refresh(MasterDataType type);

  /// Drops every cached master-data list (e.g. on logout or `conId` change).
  Future<void> clearCache();
}

/// A master-data read plus the provenance the UI needs to badge it honestly.
class MasterDataResult {
  const MasterDataResult({
    required this.items,
    required this.fromCache,
    required this.isStale,
    this.cachedAt,
  });

  final List<MasterDataItem> items;

  /// True when these rows came from Hive rather than the network.
  final bool fromCache;

  /// True when the cache was served *because* the network was unreachable or
  /// failed, rather than because it was still fresh. Drives the "offline" badge.
  final bool isStale;

  final DateTime? cachedAt;
}
