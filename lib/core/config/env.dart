import 'package:envied/envied.dart';

part 'env.g.dart';

/// Compile-time environment configuration (Blueprint §3, "Config Isolation via
/// Envied"). Values are read from the git-ignored `.env` file at build time and
/// obfuscated into Dart byte-code, so no endpoint or salt appears as a literal
/// string in the shipped binary.
///
/// [dbSalt] is deliberately *not* a standalone secret: it is combined with the
/// hardware-sealed device key (see `DynamicKeyStore`) to derive the SQLCipher
/// passphrase, so recovering it from the binary alone does not expose the DB.
@Envied(path: '.env', obfuscate: true)
abstract class Env {
  /// Compatibility accessor; new code should select the environment through
  /// [AppConfig.apiBaseUrl].
  static String get apiBaseUrl => apiBaseUrlDev;

  @EnviedField(varName: 'API_BASE_URL_DEV', obfuscate: true)
  static final String apiBaseUrlDev = _Env.apiBaseUrlDev;

  @EnviedField(varName: 'API_BASE_URL_PRO', obfuscate: true)
  static final String apiBaseUrlPro = _Env.apiBaseUrlPro;

  /// Salt mixed into the database-key derivation. Defense-in-depth only.
  @EnviedField(varName: 'DB_SALT', obfuscate: true)
  static final String dbSalt = _Env.dbSalt;
}
