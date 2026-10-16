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
  /// Base URL every Dio client is constructed against (`AppNetwork`).
  ///
  /// This is what makes environment switching work: swapping the `.env` file
  /// (see `.env.development` / `.env.staging` / `.env.production`) repoints the
  /// whole app without a source change (docs/release/environment.md).
  /// It is also the target of the ADR-005 reachability probe. It previously lived as a hardcoded
  /// literal in `AppConstants.baseUrl`, which silently pinned every build to
  /// production.
  @EnviedField(varName: 'API_BASE_URL', obfuscate: true)
  static final String apiBaseUrl = _Env.apiBaseUrl;

  /// Salt mixed into the database-key derivation. Defense-in-depth only.
  @EnviedField(varName: 'DB_SALT', obfuscate: true)
  static final String dbSalt = _Env.dbSalt;
}
