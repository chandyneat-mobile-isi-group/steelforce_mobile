import 'package:steelforce/core/database/secure/dynamic_key_store.dart';
import 'package:steelforce/core/database/secure/key_derivation.dart';

/// Composes the SQLCipher passphrase at runtime from its two halves, per the
/// Blueprint §3 derivation flow:
///
/// * the hardware-sealed device key ([DynamicKeyStore]), and
/// * the obfuscated build salt (`Env.dbSalt`, injected as [salt]).
///
/// The final key is derived on demand and never persisted anywhere.
class AppDatabaseKeyProvider {
  const AppDatabaseKeyProvider({
    required DynamicKeyStore deviceKeyStore,
    required KeyDerivation keyDerivation,
    required String salt,
  })  : _deviceKeyStore = deviceKeyStore,
        _keyDerivation = keyDerivation,
        _salt = salt;

  final DynamicKeyStore _deviceKeyStore;
  final KeyDerivation _keyDerivation;
  final String _salt;

  /// Resolves the 64-hex-char SQLCipher passphrase for this device+build.
  Future<String> databasePassphrase() async {
    final deviceKey = await _deviceKeyStore.getOrCreateDeviceKey();
    return _keyDerivation.deriveDatabaseKey(salt: _salt, deviceKey: deviceKey);
  }
}
