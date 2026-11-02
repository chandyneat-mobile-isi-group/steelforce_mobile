import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:steelforce/core/firebase/firebase_app_check.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/logging/password_reset_request_trace.dart';

/// What came back from asking for a code: either a code is on its way
/// ([verificationId] set), or the platform verified the number on the spot
/// ([idToken] set).
class PhoneCodeDispatch {
  const PhoneCodeDispatch.sent(
    String this.verificationId,
    this.resendToken, {
    this.automaticProof,
  }) : idToken = null;
  const PhoneCodeDispatch.verified(String this.idToken)
      : verificationId = null,
        resendToken = null,
        automaticProof = null;

  final String? verificationId;
  final int? resendToken;
  final String? idToken;

  /// Completes if Android retrieves the SMS after `codeSent` has already
  /// opened the OTP screen. It remains pending when manual entry is required.
  final Future<String>? automaticProof;
}

/// A phone check that failed. [code] is the provider's stable error code
/// (`invalid-verification-code`, `session-expired`, `too-many-requests`, …),
/// never a message — the presentation layer localises it.
class PhoneOwnershipException implements Exception {
  const PhoneOwnershipException(this.code);

  final String code;

  @override
  String toString() => 'PhoneOwnershipException($code)';
}

/// Proves the rep holds a phone number and hands back a provider-signed ID
/// token the backend can verify. Nothing else: it never signs anyone in to
/// SteelForce and never sees a password.
abstract interface class PhoneOwnershipVerifier {
  Future<PhoneCodeDispatch> sendCode(String phoneNumber, {int? resendToken});

  /// Checks [code] against the session [verificationId] names and returns the
  /// ID token.
  Future<String> confirmCode({
    required String verificationId,
    required String code,
  });
}

/// [PhoneOwnershipVerifier] over Firebase Phone Auth.
///
/// Firebase is used only as an SMS-and-proof service. The Firebase session it
/// creates is signed out as soon as the ID token is in hand — the token stays
/// valid for the backend to verify, and no Firebase user lingers on the device.
class FirebasePhoneOwnershipVerifier implements PhoneOwnershipVerifier {
  FirebasePhoneOwnershipVerifier({
    FirebaseAuth Function()? auth,
    AppLogger? logger,
  })  : _auth = auth ?? (() => FirebaseAuth.instance),
        _log = logger;

  /// Step-by-step trace of the Firebase exchange, printed in debug builds
  /// (`ConsoleAppLogger` drops debug/info in release). Never the phone number,
  /// the code, or a token — only events, Firebase error codes and messages.
  final AppLogger? _log;

  /// Resolved lazily: touching `FirebaseAuth.instance` before
  /// `Firebase.initializeApp` throws, and on web there is no app at all.
  final FirebaseAuth Function() _auth;

  /// How long Android waits to read the SMS itself before leaving it to the
  /// rep. Firebase's own maximum is 120 seconds.
  static const _autoRetrievalTimeout = Duration(seconds: 60);

  /// Upper bound on the whole request, so a callback Firebase never fires
  /// cannot leave the button spinning forever.
  static const _requestTimeout = Duration(seconds: 90);

  @override
  Future<PhoneCodeDispatch> sendCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    final trace = PasswordResetRequestTrace.start(
      method: 'FirebaseAuth.verifyPhoneNumber',
      path: 'Firebase Phone Auth',
      // Masked by the trace: `+855•••••678`.
      requestBody: {
        'phoneNumber': phoneNumber,
        'timeoutSeconds': _autoRetrievalTimeout.inSeconds,
        'resend': resendToken != null,
      },
    );
    debugTrace('password-reset.firebase', 'verifyPhoneNumber started');
    _log?.debug('auth.phone_send_started', fields: {
      'resend': resendToken != null,
    });
    final auth = await _ready();
    final outcome = Completer<PhoneCodeDispatch>();
    final automaticProof = Completer<String>();

    void fail(Object error) {
      _logFailure('auth.phone_send_failed', error);
      trace.failure(status: null, type: _mapped(error).code);
      debugTrace(
        'password-reset.firebase',
        'verification request failed (${_mapped(error).code})',
      );
      if (!outcome.isCompleted) outcome.completeError(_mapped(error));
    }

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        timeout: _autoRetrievalTimeout,
        // Fires for instant verification (no SMS at all) and for Android
        // auto-retrieval of an SMS that already arrived. Only the first case
        // completes the request: once `codeSent` has fired the code screen is
        // up and the rep confirms the code there.
        verificationCompleted: (credential) async {
          debugTrace(
            'password-reset.firebase',
            'verificationCompleted; afterCodeSent=${outcome.isCompleted}',
          );
          _log?.debug('auth.phone_auto_verified', fields: {
            // After `codeSent` this is SMS auto-retrieval, which is ignored:
            // the rep confirms the code on the code screen.
            'afterCodeSent': outcome.isCompleted,
          });
          trace.event(
            outcome.isCompleted
                ? 'auto_verified_after_code_sent'
                : 'instant_verified',
          );
          if (outcome.isCompleted) {
            if (automaticProof.isCompleted) return;
            try {
              automaticProof.complete(await _idTokenFor(auth, credential));
            } catch (e) {
              // Keep manual OTP entry available if automatic sign-in fails.
              _logFailure('auth.phone_auto_verify_failed', e);
            }
            return;
          }
          try {
            final token = await _idTokenFor(auth, credential);
            if (!outcome.isCompleted) {
              outcome.complete(PhoneCodeDispatch.verified(token));
            }
          } catch (e) {
            fail(e);
          }
        },
        verificationFailed: fail,
        codeSent: (verificationId, token) {
          trace.event('code_sent', fields: {
            'to': PasswordResetRequestTrace.maskPhone(phoneNumber),
          });
          debugTrace('password-reset.firebase', 'codeSent callback received');
          _log?.debug('auth.phone_code_sent', fields: {
            'canResend': token != null,
          });
          if (!outcome.isCompleted) {
            outcome.complete(PhoneCodeDispatch.sent(
              verificationId,
              token,
              automaticProof: automaticProof.future,
            ));
          }
        },
        codeAutoRetrievalTimeout: (_) {
          trace.event('auto_retrieval_timeout');
          debugTrace('password-reset.firebase', 'auto-retrieval timed out');
          _log?.debug('auth.phone_auto_retrieval_timeout');
        },
      );
    } catch (e) {
      fail(e);
    }

    return outcome.future.timeout(
      _requestTimeout,
      onTimeout: () {
        trace.failure(status: null, type: 'callback_timeout');
        debugTrace('password-reset.firebase', 'verification request timed out');
        _log?.warning('auth.phone_send_timeout', fields: {
          'seconds': _requestTimeout.inSeconds,
          'hint': 'no codeSent/verificationFailed callback — on iOS check the '
              'reCAPTCHA return reached Firebase (SceneDelegate)',
        });
        throw const PhoneOwnershipException('timeout');
      },
    );
  }

  @override
  Future<String> confirmCode({
    required String verificationId,
    required String code,
  }) async {
    final trace = PasswordResetRequestTrace.start(
      method: 'FirebaseAuth.signInWithCredential',
      path: 'Firebase Phone Auth',
      // The code prints as «hidden · 6 chars»; the verificationId is left
      // out entirely — with the code it signs in.
      requestBody: {'smsCode': code},
    );
    debugTrace('password-reset.firebase', 'manual code confirmation started');
    _log?.debug('auth.phone_confirm_started');
    final auth = await _ready();
    try {
      final token = await _idTokenFor(
        auth,
        PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        ),
      );
      trace.event('code_accepted_and_id_token_obtained', fields: {
        'idToken': '${token.length} chars',
      });
      return token;
    } catch (e) {
      trace.failure(status: null, type: _mapped(e).code);
      _logFailure('auth.phone_confirm_failed', e);
      debugTrace(
        'password-reset.firebase',
        'manual code confirmation failed (${_mapped(e).code})',
      );
      throw _mapped(e);
    }
  }

  Future<FirebaseAuth> _ready() async {
    try {
      // Normally already done by push start-up; a no-op then.
      if (Firebase.apps.isEmpty) {
        _log?.debug('auth.phone_firebase_initializing');
      }
      await FirebaseAppCheckInitializer.initialize();
      final auth = _auth();
      _log?.debug('auth.phone_firebase_ready', fields: {
        'project': auth.app.options.projectId,
      });
      return auth;
    } catch (e) {
      _logFailure('auth.phone_firebase_unavailable', e);
      throw const PhoneOwnershipException('unavailable');
    }
  }

  void _logFailure(String event, Object error) {
    _log?.warning(event, fields: {
      'code': _mapped(error).code,
      // Firebase's own explanation, e.g. "This app is not authorized to use
      // Firebase Authentication…". The logger redacts any digit run.
      if (error is FirebaseException) 'message': error.message,
      'type': error.runtimeType.toString(),
    });
  }

  Future<String> _idTokenFor(
    FirebaseAuth auth,
    AuthCredential credential,
  ) async {
    try {
      final signedIn = await auth.signInWithCredential(credential);
      // Force a fresh token: the backend validates Firebase auth_time against
      // the short verification window.
      final token = await signedIn.user?.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const PhoneOwnershipException('no-id-token');
      }
      // No fields: the token is a credential, and the logger redacts any
      // field named like one anyway.
      _log?.debug('auth.phone_id_token_obtained');
      debugTrace('password-reset.firebase', 'fresh Firebase ID token obtained');
      return token;
    } finally {
      // Best effort: the token is already minted and the backend verifies it
      // on its own. A failed sign-out leaves only an inert Firebase session.
      try {
        await auth.signOut();
        debugTrace(
            'password-reset.firebase', 'temporary Firebase session signed out');
      } catch (_) {}
    }
  }

  static PhoneOwnershipException _mapped(Object error) => switch (error) {
        PhoneOwnershipException() => error,
        FirebaseAuthException(:final code) => PhoneOwnershipException(code),
        FirebaseException(:final code) => PhoneOwnershipException(code),
        TimeoutException() => const PhoneOwnershipException('timeout'),
        _ => const PhoneOwnershipException('unknown'),
      };
}
