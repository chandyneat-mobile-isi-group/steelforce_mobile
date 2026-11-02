import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/logging/debug_trace.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_ownership_verifier.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_password_change_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/phone_number_format.dart';
import 'package:steelforce/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_proof.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_ownership_reset_repository.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_password_change_repository.dart';

class PhonePasswordChangeRepositoryImpl
    implements PhonePasswordChangeRepository {
  PhonePasswordChangeRepositoryImpl({
    required PhoneOwnershipVerifier verifier,
    required PhonePasswordChangeRemoteDataSource remote,
    required Future<String?> Function() ownPhoneNumber,
    required NetworkInfo networkInfo,
    DateTime Function()? now,
    AppLogger? logger,
  })  : _verifier = verifier,
        _remote = remote,
        _ownPhoneNumber = ownPhoneNumber,
        _network = networkInfo,
        _now = now ?? DateTime.now,
        _logger = logger;

  final PhoneOwnershipVerifier _verifier;
  final PhonePasswordChangeRemoteDataSource _remote;

  /// The signed-in account's own number, from the cached profile. Never
  /// typed by the rep: the code must go to the account's phone.
  final Future<String?> Function() _ownPhoneNumber;
  final NetworkInfo _network;
  final DateTime Function() _now;

  /// Outcome codes only — never the number, the code, or a token.
  final AppLogger? _logger;

  /// Server codes the screen must tell apart. Every other code goes through
  /// [AuthRepositoryImpl.failureFrom] like the rest of the auth feature.
  static const _passThroughCodes = {
    PhonePasswordChangeCodes.phoneNumberRequired,
    PhonePasswordChangeCodes.channelDisabled,
    PhonePasswordChangeCodes.proofInvalid,
  };

  @override
  ResultFuture<PhoneVerificationHandle> startOwnPhoneVerification() =>
      _guard(() async {
        debugTrace('password-change.flow', 'starting own-phone verification');
        final stored = await _ownPhoneNumber();
        if (stored == null || stored.trim().isEmpty) {
          // Same code the server used for an account with no number, so the
          // screen's "ask an administrator" message applies unchanged.
          throw const ApiException(ApiError(
            code: ApiErrorCodes.validation,
            statusCode: 400,
            serverCode: PhonePasswordChangeCodes.phoneNumberRequired,
            message: 'Your account has no phone number.',
          ));
        }
        final start = await _remote.startOwnPhoneVerification(
          phoneNumber: toE164(stored),
        );
        // No resend token: the backend allows one SMS per verification, so a
        // resend is a new start and a fresh Firebase request.
        final dispatch = await _verifier.sendCode(start.phoneNumber);
        _logger?.info('auth.own_phone_code_requested', fields: {
          'outcome':
              dispatch.idToken != null ? 'verified_instantly' : 'code_sent',
        });
        final proof = dispatch.idToken;
        return proof != null
            ? PhoneVerificationHandle.verified(
                phoneNumber: start.phoneNumber,
                instantProof: proof,
                resendAfter: start.resendAfter,
                expiresIn: start.expiresIn,
              )
            : PhoneVerificationHandle.codeSent(
                phoneNumber: start.phoneNumber,
                verificationId: dispatch.verificationId!,
                resendAfter: start.resendAfter,
                expiresIn: start.expiresIn,
                automaticProof: dispatch.automaticProof,
              );
      });

  @override
  ResultFuture<PhoneProof> verifyOwnPhone({
    required PhoneVerificationHandle handle,
    required String otp,
  }) =>
      _guard(() async {
        final idToken = handle.instantProof ??
            (otp.isEmpty && handle.automaticProof != null
                ? await handle.automaticProof!
                : await _verifier.confirmCode(
                    verificationId: handle.verificationId!,
                    code: otp,
                  ));
        debugTrace('password-change.flow', 'exchanging Firebase proof');
        final issued = await _remote.verifyOwnPhone(idToken);
        return PhoneProof(
          token: issued.token,
          issuedAt: _now(),
          expiresIn: issued.expiresIn,
        );
      });

  @override
  ResultFuture<void> changePasswordWithPhoneProof({
    required PhoneProof proof,
    required String newPassword,
  }) =>
      _guard(
        () => _remote.changePasswordWithProof(
          phoneProofToken: proof.token,
          newPassword: newPassword,
        ),
        // No answer is not "not done": the server may have spent the proof
        // and changed the password before the connection dropped.
        ambiguousTransport: true,
      );

  Future<Result<T>> _guard<T>(
    Future<T> Function() action, {
    bool ambiguousTransport = false,
  }) async {
    // Checked first, so this failure always means nothing was sent.
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      return Success(await action());
    } on PhoneOwnershipException catch (e) {
      _logger?.warning('auth.own_phone_verification_failed', fields: {
        'code': e.code,
      });
      return Failed(AuthenticationFailure(
        message: 'Phone verification failed.',
        code: '$phoneFailurePrefix${e.code}',
      ));
    } on ApiException catch (e) {
      final error = e.error;
      final server = error.serverCode;
      _logger?.warning('auth.own_phone_backend_failed', fields: {
        'status': error.statusCode,
        'code': server ?? error.code,
      });
      if (ambiguousTransport && error.code == ApiErrorCodes.network) {
        return const Failed(ServerFailure(
          message: 'The server did not answer.',
          code: PhonePasswordChangeCodes.outcomeUnknown,
        ));
      }
      if (server == PhonePasswordChangeCodes.proofInvalid) {
        return Failed(AuthenticationFailure(
          message: error.message ?? 'Verification failed or expired.',
          statusCode: error.statusCode,
          code: server,
        ));
      }
      if (_passThroughCodes.contains(server)) {
        return Failed(ServerFailure(
          message: error.message ?? 'Phone verification is unavailable.',
          statusCode: error.statusCode,
          code: server,
        ));
      }
      return Failed(AuthRepositoryImpl.failureFrom(error));
    }
  }
}
