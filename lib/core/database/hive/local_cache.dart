import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// General-purpose key/value cache with optional TTL, backed by the plain
/// Hive box. Use it for non-sensitive data you want to avoid re-fetching —
/// catalog pages, inventory snapshots, report results, etc.
///
///   `cache.set('catalog:page1', jsonList, ttl: const Duration(minutes: 10));`
///   `final cached = cache.get<List<dynamic>>('catalog:page1'); // null if expired`
///
/// Values must be JSON-encodable (primitives, maps, lists).
class LocalCache {
  const LocalCache(this._box);
  final Box<dynamic> _box;

  Future<void> set(String key, Object? value, {Duration? ttl}) {
    final expiresAt =
        ttl == null ? null : DateTime.now().add(ttl).millisecondsSinceEpoch;
    return _box.put(key, jsonEncode({'v': value, 'e': expiresAt}));
  }

  T? get<T>(String key) {
    final raw = _box.get(key);
    if (raw is! String) return null;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    final expiresAt = map['e'] as int?;
    if (expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch > expiresAt) {
      _box.delete(key); // lazy eviction
      return null;
    }
    return map['v'] as T?;
  }

  bool has(String key) => get<dynamic>(key) != null;

  Future<void> remove(String key) => _box.delete(key);

  /// Clears everything in the cache box (does NOT touch the session box).
  Future<void> clearAll() => _box.clear();
}
