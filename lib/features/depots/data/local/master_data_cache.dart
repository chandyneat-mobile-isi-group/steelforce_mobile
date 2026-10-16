import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';

/// Hive-backed store for the SAP Helper dropdown lists.
///
/// Hive rather than Drift is deliberate: `ARCHITECTURE.md` §3 assigns Layer 2 to
/// "cached lookups the user can regenerate", which is exactly what this is. It
/// also keeps non-business reference data out of the encrypted relational store
/// and — importantly — means this feature needs no schema migration (ADR-009).
///
/// Two entries are written per list: the rows themselves under a TTL'd key, and
/// an untimed mirror. The mirror is what makes the offline promise work — once
/// the TTL lapses the fresh read is gone, but a *stale* copy survives to serve
/// an offline user rather than leaving them with an empty dropdown.
class MasterDataCache {
  const MasterDataCache(this._cache, {this.ttl = const Duration(days: 7)});

  final LocalCache _cache;

  /// SAP org structure changes rarely; a week avoids pointless refetching while
  /// still self-healing without a manual cache clear.
  final Duration ttl;

  static const String _prefix = 'sap_master_data';

  String _freshKey(MasterDataType type) => '$_prefix:${type.cacheKey}';
  String _staleKey(MasterDataType type) => '$_prefix:${type.cacheKey}:stale';
  String _stampKey(MasterDataType type) => '$_prefix:${type.cacheKey}:at';

  /// Non-expired rows, or null once the TTL has lapsed.
  List<MasterDataItem>? readFresh(MasterDataType type) =>
      _decode(_cache.get<List<dynamic>>(_freshKey(type)));

  /// The last successfully-fetched rows regardless of age. Only ever surfaced
  /// when the network could not be reached — always badge it as stale.
  List<MasterDataItem>? readStale(MasterDataType type) =>
      _decode(_cache.get<List<dynamic>>(_staleKey(type)));

  DateTime? cachedAt(MasterDataType type) {
    final raw = _cache.get<int>(_stampKey(type));
    return raw == null ? null : DateTime.fromMillisecondsSinceEpoch(raw);
  }

  Future<void> write(MasterDataType type, List<MasterDataItem> items) async {
    final encoded = items
        .map((i) => <String, String>{'code': i.code, 'name': i.name})
        .toList();
    await _cache.set(_freshKey(type), encoded, ttl: ttl);
    await _cache.set(_staleKey(type), encoded);
    await _cache.set(_stampKey(type), DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clear() async {
    for (final type in MasterDataType.values) {
      await _cache.remove(_freshKey(type));
      await _cache.remove(_staleKey(type));
      await _cache.remove(_stampKey(type));
    }
  }

  /// Tolerates a shape change in cached JSON by discarding it rather than
  /// throwing — a decode failure must degrade to a refetch, never a crash.
  List<MasterDataItem>? _decode(List<dynamic>? raw) {
    if (raw == null) return null;
    try {
      return raw
          .cast<Map<String, dynamic>>()
          .map(
            (m) => MasterDataItem(
              code: m['code'] as String? ?? '',
              name: m['name'] as String? ?? '',
            ),
          )
          .where((i) => i.code.isNotEmpty)
          .toList(growable: false);
    } on Object {
      return null;
    }
  }
}
