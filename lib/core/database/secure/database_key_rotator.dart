import 'package:steelforce/core/database/secure/dynamic_key_store.dart';
import 'package:steelforce/core/database/secure/key_derivation.dart';

/// Re-encrypts the live database with a freshly derived passphrase. Kept free of
/// any Drift import so the secure layer stays persistence-agnostic; the actual
/// `PRAGMA rekey` is delegated to a [DatabaseRekeyExecutor] adapter.
abstract interface class DatabaseRekeyExecutor {
  /// Runs `PRAGMA rekey = "x'<rawKeyHex>'"` on the open connection, re-writing
  /// every page with the new key. Throws if the DB is not open/encrypted.
  Future<void> rekey(String rawKeyHex);
}

/// Rotates the database encryption key (T1.6 / Blueprint §3 "key must never be
/// static").
///
/// Rotation regenerates the hardware-sealed **device key**; because
/// `FinalKey = SHA256(salt + deviceKey)`, a new device key yields a new
/// SQLCipher passphrase. The sequence is deliberately **rekey-then-persist**:
/// the new device key is committed to secure storage only after the on-disk
/// re-encryption succeeds, so a failed rekey leaves the old, still-valid key in
/// place.
///
/// NOTE (crash-window): if the process dies between a successful `rekey` and
/// [DynamicKeyStore.replaceDeviceKey], the file is on the new key while storage
/// holds the old one. A follow-up hardening task should make this two-phase
/// (pending-key marker + try-both on open); documented here rather than hidden.
class DatabaseKeyRotator {
  const DatabaseKeyRotator({
    required DynamicKeyStore deviceKeyStore,
    required KeyDerivation keyDerivation,
    required DatabaseRekeyExecutor executor,
    required String salt,
  })  : _deviceKeyStore = deviceKeyStore,
        _keyDerivation = keyDerivation,
        _executor = executor,
        _salt = salt;

  final DynamicKeyStore _deviceKeyStore;
  final KeyDerivation _keyDerivation;
  final DatabaseRekeyExecutor _executor;
  final String _salt;

  /// Performs one rotation. Returns the new device-key version on success.
  Future<int> rotate() async {
    final newDeviceKey = _deviceKeyStore.newCandidateKey();
    final newPassphrase = _keyDerivation.deriveDatabaseKey(
      salt: _salt,
      deviceKey: newDeviceKey,
    );

    // Re-encrypt the live database first; if this throws, the old key is intact
    // and nothing has been persisted.
    await _executor.rekey(newPassphrase);

    // Commit only after a successful rekey.
    await _deviceKeyStore.replaceDeviceKey(newDeviceKey);
    return _deviceKeyStore.currentVersion();
  }
}
