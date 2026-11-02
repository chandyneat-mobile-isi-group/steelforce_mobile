import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/logging/password_reset_request_trace.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_ownership_verifier.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_reset_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/phone_number_format.dart';
import 'package:steelforce/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_ownership_reset_repository.dart';

class PhoneOwnershipResetRepositoryImpl
    implements PhoneOwnershipResetRepository {
  const PhoneOwnershipResetRepositoryImpl({
    required PhoneOwnershipVerifier verifier,
    required PhoneResetRemoteDataSource remote,
    required NetworkInfo networkInfo,
    AppLogger? logger,
  })  : _verifier = verifier,
        _remote = remote,
        _network = networkInfo,
        _logger = logger;

  final PhoneOwnershipVerifier _verifier;
  final PhoneResetRemoteDataSource _remote;
  final NetworkInfo _network;

  /// Records the provider's outcome codes — the only way to tell *why* no SMS
  /// arrived, since the screen shows a localised summary. Never the number.
  final AppLogger? _logger;

  @override
  ResultFuture<PhoneVerificationHandle> sendResetCode(
    String phoneNumber, {
    PhoneVerificationHandle? previous,
  }) =>
      _guard(() async {
        debugTrace(
          'password-reset.flow',
          previous == null
              ? 'starting new SMS verification'
              : 'resending SMS code',
        );
        // The backend's first step, with its per-number limits, before
        // Firebase sends the SMS. App Check guards the SMS request inside
        // Firebase Auth.
        debugTrace(
            'password-reset.flow', '① asking the backend first (otp/request)');
        final start = await _remote.startVerification(
          phoneNumber: toE164(phoneNumber),
        );
        // The server's canonical number when it returns one, else ours.
        final phone = start.phoneNumber;
        final masked = PasswordResetRequestTrace.maskPhone(phone);
        debugTrace('password-reset.flow',
            '① ✓ backend accepted the request for $masked');
        debugTrace('password-reset.flow',
            '② sending phone $masked to Firebase (verifyPhoneNumber)');
        final dispatch = await _verifier.sendCode(
          phone,
          resendToken: previous?.resendToken,
        );
        debugTrace(
          'password-reset.flow',
          dispatch.idToken == null
              ? '② ✓ Firebase sent the SMS code to $masked'
              : '② ✓ Firebase verified $masked instantly (no code needed)',
        );
        final proof = dispatch.idToken;
        _logger?.info('auth.phone_code_requested', fields: {
          'outcome': proof != null ? 'verified_instantly' : 'code_sent',
          'resend': previous != null,
        });
        return proof != null
            ? PhoneVerificationHandle.verified(
                phoneNumber: phone,
                instantProof: proof,
                resendAfter: start.resendAfter,
                expiresIn: start.expiresIn,
              )
            : PhoneVerificationHandle.codeSent(
                phoneNumber: phone,
                verificationId: dispatch.verificationId!,
                resendAfter: start.resendAfter,
                expiresIn: start.expiresIn,
                automaticProof: dispatch.automaticProof,
                resendToken: dispatch.resendToken,
              );
      });

  @override
  ResultFuture<PasswordResetGrant> verifyResetCode({
    required PhoneVerificationHandle handle,
    required String otp,
  }) =>
      _guard(() async {
        debugTrace(
          'password-reset.flow',
          otp.isEmpty
              ? 'using Android automatic verification proof'
              : 'confirming entered OTP',
        );
        debugTrace('password-reset.flow',
            '③ verifying the code with Firebase (signInWithCredential)');
        final proof = await _proof(handle, otp);
        debugTrace('password-reset.flow',
            '③ ✓ Firebase verified the code — ID token received (${proof.length} chars)');
        _logger?.debug('auth.phone_backend_exchange_started');
        debugTrace('password-reset.flow',
            '④ sending the Firebase ID token to the backend (phone/verify)');
        final grant = await _remote.exchangeFirebaseToken(proof);
        debugTrace('password-reset.flow',
            '④ ✓ backend accepted the Firebase token — reset token received');
        return grant;
      });

  @override
  ResultFuture<void> confirmOwnership({
    required PhoneVerificationHandle handle,
    required String otp,
  }) =>
      _guard(() async {
        debugTrace(
            'password-reset.flow', 'confirming phone in check-only mode');
        await _proof(handle, otp);
        _logger?.info('auth.phone_check_only_verified', fields: {
          'backendExchange': 'skipped',
        });
      });

  /// The provider's ID token for [handle]: already in hand after instant
  /// verification, otherwise obtained by confirming [otp].
  Future<String> _proof(PhoneVerificationHandle handle, String otp) async =>
      handle.instantProof ??
      (otp.isEmpty && handle.automaticProof != null
          ? await handle.automaticProof!
          : await _verifier.confirmCode(
              verificationId: handle.verificationId!,
              code: otp,
            ));

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    if (!await _network.isConnected) {
      debugTrace('password-reset.flow', 'stopped: device is offline');
      return const Failed(NetworkFailure());
    }
    try {
      return Success(await action());
    } on PhoneOwnershipException catch (e) {
      debugTrace(
        'password-reset.flow',
        '✗ Firebase refused (${e.code})',
      );
      _logger?.warning('auth.phone_verification_failed', fields: {
        'code': e.code,
      });
      return Failed(AuthenticationFailure(
        message: 'Phone verification failed.',
        code: '$phoneFailurePrefix${e.code}',
      ));
    } on ApiException catch (e) {
      debugTrace(
        'password-reset.flow',
        '✗ backend refused (${e.error.serverCode ?? e.error.code}, '
            'status ${e.error.statusCode ?? 'none'})',
      );
      return Failed(AuthRepositoryImpl.failureFrom(e.error));
    }
  }
}
