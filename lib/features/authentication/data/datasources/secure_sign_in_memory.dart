import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:steelforce/core/database/secure/secure_storage_keys.dart';
import 'package:steelforce/features/authentication/domain/repositories/sign_in_memory.dart';

/// [SignInMemory] in secure storage (Keychain / Keystore): a phone number is
/// PII, so it never goes to Hive or plain preferences.
///
/// Deliberately outside the session: sign-out clears the tokens and the
/// cached user, but not this — remembering the number across sign-outs is
/// the whole point.
class SecureSignInMemory implements SignInMemory {
  const SecureSignInMemory(this._storage);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> readPhone() =>
      _storage.read(key: SecureStorageKeys.kRememberedPhone);

  @override
  Future<void> rememberPhone(String phone) =>
      _storage.write(key: SecureStorageKeys.kRememberedPhone, value: phone);

  @override
  Future<void> forgetPhone() =>
      _storage.delete(key: SecureStorageKeys.kRememberedPhone);
}
