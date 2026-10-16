/// Keys under which values live in `flutter_secure_storage` (Keychain /
/// Keystore) — tokens, the cached user, the remembered sign-in phone, the
/// device id and the database device key. Nothing else belongs in secure storage (`.claude/rules/security.md`).
/// Split out of the former catch-all `AppConstants`.
abstract final class SecureStorageKeys {
  static const String kAccessToken = 'isi.access_token';

  static const String kRefreshToken = 'isi.refresh_token';

  static const String kCachedUser = 'isi.cached_user';

  /// The phone number kept by the login screen's "Remember me" — never the
  /// password. Survives sign-out on purpose; PII, hence secure storage.
  static const String kRememberedPhone = 'isi.remembered_phone';

  /// Per-installation device identifier sent with login and refresh. Survives
  /// restarts, may change on reinstall, never used for authorisation.
  static const String kDeviceId = 'isi.device_id';

  /// Secure-storage key holding the hardware-sealed 256-bit device key. This
  /// is the dynamic half of the composite SQLCipher passphrase — never the
  /// final key, which is derived at runtime and never persisted.
  static const String kDbDeviceKey = 'isi.db_device_key';

  /// Secure-storage key holding the device-key version (for rotation).
  static const String kDbDeviceKeyVersion = 'isi.db_device_key_version';
}
