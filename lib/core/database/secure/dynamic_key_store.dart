import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:steelforce/core/database/secure/secure_storage_keys.dart';
import 'package:steelforce/core/error/exceptions.dart';

/// Owns the **dynamic device key** — the hardware-sealed half of the SQLCipher
/// passphrase (Blueprint §3, "Dynamic Cryptographic Key Derivation Flow").
///
/// The key is a 256-bit CSPRNG value generated once per install and committed
/// to the platform Keychain / Keystore via [FlutterSecureStorage]. It never
/// leaves the device, is never logged, and is never combined with the salt here
/// — derivation is [KeyDerivation]'s job. Storing only the device key (not the
/// final key) means a stolen binary alone cannot reconstruct the passphrase.
class DynamicKeyStore {
  const DynamicKeyStore(this._storage);

  final FlutterSecureStorage _storage;

  /// 32 bytes = 256 bits → 64 hex characters.
  static const int _keyLengthBytes = 32;

  /// Returns the device key, generating and hardware-sealing one on first run.
  /// Idempotent: repeated calls return the same key.
  ///
  /// Throws [CacheException] if secure storage is unavailable — the database
  /// must never fall back to an unencrypted or predictable key.
  Future<String> getOrCreateDeviceKey() async {
    try {
      final existing = await _storage.read(key: SecureStorageKeys.kDbDeviceKey);
      if (existing != null && _isValidHexKey(existing)) {
        return existing;
      }

      final key = _generateHexKey();
      await _storage.write(key: SecureStorageKeys.kDbDeviceKey, value: key);
      await _storage.write(
        key: SecureStorageKeys.kDbDeviceKeyVersion,
        value: '1',
      );
      return key;
    } catch (e) {
      if (e is CacheException) rethrow;
      throw CacheException(
        message: 'Failed to access device encryption key: $e',
      );
    }
  }

  /// Current device-key version, or `0` if none exists yet.
  Future<int> currentVersion() async {
    final raw = await _storage.read(key: SecureStorageKeys.kDbDeviceKeyVersion);
    return int.tryParse(raw ?? '') ?? 0;
  }

  /// Whether a device key already exists in secure storage.
  Future<bool> hasKey() async {
    final existing = await _storage.read(key: SecureStorageKeys.kDbDeviceKey);
    return existing != null && _isValidHexKey(existing);
  }

  /// Generates a fresh 256-bit candidate key **without persisting it**. Used by
  /// rotation (T1.6): the candidate is only committed via [replaceDeviceKey]
  /// after the database has been successfully re-encrypted with it.
  String newCandidateKey() => _generateHexKey();

  /// Atomically replaces the stored device key and bumps its version. Called
  /// only after a successful `PRAGMA rekey`, so secure storage never advances
  /// ahead of the on-disk encryption.
  Future<void> replaceDeviceKey(String newKey) async {
    if (!_isValidHexKey(newKey)) {
      throw ArgumentError('newKey must be $_keyLengthBytes bytes of hex');
    }
    final nextVersion = await currentVersion() + 1;
    await _storage.write(key: SecureStorageKeys.kDbDeviceKey, value: newKey);
    await _storage.write(
      key: SecureStorageKeys.kDbDeviceKeyVersion,
      value: '$nextVersion',
    );
  }

  String _generateHexKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      _keyLengthBytes,
      (_) => random.nextInt(256),
    );
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  bool _isValidHexKey(String value) {
    if (value.length != _keyLengthBytes * 2) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(value);
  }
}
