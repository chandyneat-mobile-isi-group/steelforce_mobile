import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase App Check once, before foreground Firebase services.
///
/// Android release builds use the Android reCAPTCHA Enterprise site key
/// registered for this Firebase app. Debug builds use the App Check debug
/// provider so local devices can be allowlisted without consuming assessments.
abstract final class FirebaseAppCheckInitializer {
  static const _androidRecaptchaSiteKey =
      '6Lf_rvktAAAAALTlHnUXajoiXnY23dGcxeEHhcvo';

  static Future<void>? _initialization;

  static Future<void> initialize() async {
    _initialization ??= _initialize();
    try {
      await _initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  static Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();

    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? AndroidDebugProvider(debugToken: _debugToken)
          : const AndroidReCaptchaProvider(_androidRecaptchaSiteKey),
      providerApple: kDebugMode
          ? AppleDebugProvider(debugToken: _debugToken)
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }

  /// Debug builds only: one App Check debug token, registered once in the
  /// Firebase console for each app, instead of a random one per install
  /// (which iOS prints only to the native log). Passed on the command line,
  /// never committed — it lets a build pass App Check:
  ///
  /// ```
  /// flutter run --dart-define=APP_CHECK_DEBUG_TOKEN=<uuid>
  /// ```
  ///
  /// Null (unset) keeps the SDK's own random token.
  static String? get _debugToken {
    const token = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');
    return token.isEmpty ? null : token;
  }
}
