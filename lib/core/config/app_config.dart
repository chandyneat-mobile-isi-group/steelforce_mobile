import 'package:flutter/foundation.dart' show kReleaseMode, visibleForTesting;
import 'package:steelforce/core/config/env.dart';

/// The effective runtime configuration: the compiled [Env] values, with an
/// optional launch-time override on top.
///
/// [Env] is baked in by Envied at build time, so repointing the app at a
/// different host normally means editing `.env` and re-running
/// `build_runner` — a slow round trip for a value that, with a Cloudflare
/// quick tunnel, changes on every restart of the backend. That friction is how
/// a stale host ends up compiled into a build nobody notices is wrong.
///
/// So the host also accepts a `--dart-define`:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=https://new-tunnel.trycloudflare.com
/// ```
///
/// The override is compile-time-constant (`String.fromEnvironment`), so it
/// costs nothing at runtime and is tree-shaken away when unused. **Everything
/// that talks to the API must read these getters rather than [Env] directly**,
/// or the override silently applies to some requests and not others — which is
/// worse than not having it at all.
///
/// Note this deliberately does *not* wrap `Env.dbSalt`: overriding the salt
/// from the command line would make the encrypted database unreadable on the
/// next launch without it, and that is not a thing to leave one flag away.
abstract final class AppConfig {
  const AppConfig._();

  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL');
  static const String _environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development',
  );

  /// Root of the ISI API — scheme and host, no trailing slash and no
  /// `/api/v1`; `ApiEndpoints.apiPrefix` supplies that. Also the target of the
  /// ADR-005 reachability probe: the app talks only to its own API, never to
  /// SAP directly.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _validateApiUrl(_apiBaseUrlOverride, 'API_BASE_URL override');
    }
    final (url, key) = switch (_environment) {
      'development' => (Env.apiBaseUrlDev, 'API_BASE_URL_DEV'),
      'production' => (Env.apiBaseUrlPro, 'API_BASE_URL_PRO'),
      _ => throw StateError(
          'Unknown APP_ENV "$_environment". Use development or production.'),
    };
    return _validateApiUrl(url, key);
  }

  static String _validateApiUrl(String value, String source) =>
      validateApiUrl(value, source, allowHttp: !kReleaseMode);

  /// [allowHttp] is false in release builds: a release talking plain HTTP
  /// sends the bearer token and every depot and order in the clear, so it
  /// refuses to start instead. Debug builds keep `http://` for a LAN backend.
  @visibleForTesting
  static String validateApiUrl(
    String value,
    String source, {
    required bool allowHttp,
  }) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'http' && !allowHttp) {
      throw StateError('$source must use https in a release build.');
    }
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.path.isNotEmpty && uri.path != '/' ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw StateError(
        '$source must contain only an http(s) scheme and host.',
      );
    }
    return trimmed.replaceFirst(RegExp(r'/$'), '');
  }

  static String get environment => _environment;

  /// True when a launch-time override is in play. Logged at startup so a build
  /// pointing somewhere unexpected explains itself in the console.
  static bool get hasOverride => _apiBaseUrlOverride.isNotEmpty;

  /// After the existing backend forgot-password request succeeds, sends the
  /// verification SMS through Firebase Phone Auth.
  ///
  /// Enabled by default for native builds. Disable per build only to fall back
  /// to the legacy backend-SMS verification flow:
  ///
  /// ```
  /// flutter run --dart-define=PASSWORD_RESET_VIA_FIREBASE=false
  /// ```
  ///
  /// Ignored on web, which has no Firebase app in this build (ADR-010).
  static const bool passwordResetViaFirebase =
      bool.fromEnvironment('PASSWORD_RESET_VIA_FIREBASE', defaultValue: true) ||
          firebasePhoneCheckOnly;

  /// Debug only: run the Firebase reset as far as Firebase confirming the
  /// code, then stop — no backend exchange, no password change.
  /// Implies [passwordResetViaFirebase].
  ///
  /// ```
  /// flutter run --dart-define=FIREBASE_PHONE_CHECK_ONLY=true
  /// ```
  // TODO(release-gate): skips the backend exchange that authorises a reset.
  // Forced off in release builds by `kReleaseMode`; remove once the backend
  // endpoint is on staging and the full flow has been tested.
  static const bool firebasePhoneCheckOnly =
      !kReleaseMode && bool.fromEnvironment('FIREBASE_PHONE_CHECK_ONLY');

  /// Features not yet released to reps. Turn one on per build to work on it:
  ///
  /// ```
  /// flutter run --dart-define=ORDERS_COMING_SOON=false
  /// ```
  /// Quotations & Orders — the Orders tab and the `Static.order` route.
  static const bool ordersComingSoon =
      bool.fromEnvironment('ORDERS_COMING_SOON', defaultValue: true);

  /// The KPI screen opened from the home monthly-target card.
  static const bool kpiComingSoon =
      bool.fromEnvironment('KPI_COMING_SOON', defaultValue: true);
}
