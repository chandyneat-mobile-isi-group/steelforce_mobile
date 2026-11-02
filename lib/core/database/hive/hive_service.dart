import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/database/secure/app_secure_storage.dart';
import 'package:steelforce/core/database/secure/secure_storage_keys.dart';

/// Owns Hive setup and the opened boxes.
///
/// Two boxes:
///  • [secureBox]  — AES-encrypted, for sensitive data (the session/user).
///  • [cacheBox]   — plain, for non-sensitive settings and general caching.
///
/// The AES key itself is the only thing kept in platform secure storage;
/// everything else lives in Hive. Call [init] once, before `runApp`.
class HiveService {
  HiveService._();

  static const String secureBoxName = 'kic_secure_box';
  static const String cacheBoxName = 'kic_cache_box';
  static const String _encryptionKeyName = SecureStorageKeys.kHiveEncryptionKey;

  static late final Box<dynamic> secureBox;
  static late final Box<dynamic> cacheBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    final encryptionKey = await _readOrCreateEncryptionKey();
    secureBox = await Hive.openBox<dynamic>(
      secureBoxName,
      encryptionCipher: HiveAesCipher(encryptionKey),
    );
    cacheBox = await Hive.openBox<dynamic>(cacheBoxName);
  }

  /// Closes all boxes (e.g. on logout-and-wipe or in tests).
  static Future<void> dispose() => Hive.close();

  static Future<List<int>> _readOrCreateEncryptionKey() async {
    final storage = appSecureStorage();

    final existing = await storage.read(key: _encryptionKeyName);
    if (existing != null) {
      return base64Url.decode(existing);
    }

    final key = Hive.generateSecureKey(); // 32 secure random bytes
    await storage.write(key: _encryptionKeyName, value: base64UrlEncode(key));
    return key;
  }
}
