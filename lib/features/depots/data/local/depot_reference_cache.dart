import 'dart:convert';

import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/features/depots/data/remote/depot_datasources.dart';

/// Hive-backed store for the SAP reference catalogues served by
/// `GET /mobile/depots/references`.
///
/// Hive rather than Drift for the same reason as [MasterDataCache]: these are
/// regenerable ERP lookups, not business records, so they belong in Layer 2 and
/// need no schema migration (ADR-009).
///
/// Fresh / stale / stamp, mirroring [MasterDataCache]. The stale mirror is what
/// makes the offline promise work: once the TTL lapses the fresh read is gone,
/// but a stale copy still beats an empty dropdown for a rep registering a shop
/// with no signal. `synchronisedAt` travels with the payload so staleness stays
/// visible.
class DepotReferenceCache {
  const DepotReferenceCache(this._cache, {this.ttl = const Duration(days: 7)});

  final LocalCache _cache;

  /// SAP org structure changes rarely; a week avoids pointless refetching while
  /// still self-healing without a manual cache clear.
  final Duration ttl;

  static const String _base = 'sap_depot_references';

  /// The active-only and include-inactive responses are **different payloads
  /// and are cached apart.**
  ///
  /// One key for both would mean whichever screen loaded first decided what
  /// the other saw: open a depot's detail page (which needs retired codes
  /// to name a stored value) and the registration form would then offer those
  /// retired codes in its dropdowns. That is a rejected SAP push caused by
  /// nothing more than screen order.
  static String _variant(bool includeInactive) =>
      includeInactive ? '$_base:all' : _base;

  /// Non-expired catalogues, or null once the TTL has lapsed.
  DepotReferenceCatalogue? readFresh({bool includeInactive = false}) =>
      _decode(_cache.get<String>(_variant(includeInactive)));

  /// The last successfully-fetched catalogues regardless of age. Only surfaced
  /// when the network could not be reached.
  DepotReferenceCatalogue? readStale({bool includeInactive = false}) =>
      _decode(_cache.get<String>('${_variant(includeInactive)}:stale'));

  DateTime? cachedAt({bool includeInactive = false}) {
    final raw = _cache.get<int>('${_variant(includeInactive)}:at');
    return raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  Future<void> write(
    DepotReferenceCatalogue catalogue, {
    bool includeInactive = false,
  }) async {
    // Stored as a JSON string rather than a nested map: Hive round-trips
    // `Map<dynamic, dynamic>` for nested structures, and the cast back is where
    // this kind of cache usually starts throwing.
    final encoded = jsonEncode(catalogue.values);
    final key = _variant(includeInactive);
    await _cache.set(key, encoded, ttl: ttl);
    await _cache.set('$key:stale', encoded);
    await _cache.set('$key:at', DateTime.now().millisecondsSinceEpoch);
  }

  /// Drops both variants. Called on sign-out and on a manual refresh — leaving
  /// one behind would resurrect the other screen's copy.
  Future<void> clear() async {
    for (final includeInactive in const [false, true]) {
      final key = _variant(includeInactive);
      await _cache.remove(key);
      await _cache.remove('$key:stale');
      await _cache.remove('$key:at');
    }
  }

  /// Tolerates a shape change in cached JSON by discarding it rather than
  /// throwing — a decode failure must degrade to a refetch, never a crash.
  DepotReferenceCatalogue? _decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return DepotReferenceCatalogue(decoded.cast<String, dynamic>());
    } on Object {
      return null;
    }
  }
}
