import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_proof.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_password_change_repository.dart';

/// Texts a code to the signed-in rep's own number. Also the resend.
class StartOwnPhoneVerification
    extends UseCase<PhoneVerificationHandle, NoParams> {
  const StartOwnPhoneVerification(this._repository);
  final PhonePasswordChangeRepository _repository;

  @override
  ResultFuture<PhoneVerificationHandle> call(NoParams params) =>
      _repository.startOwnPhoneVerification();
}

/// Confirms the code and obtains the backend's single-use phone proof.
class VerifyOwnPhoneProof extends UseCase<PhoneProof, VerifyOwnPhoneParams> {
  const VerifyOwnPhoneProof(this._repository);
  final PhonePasswordChangeRepository _repository;

  @override
  ResultFuture<PhoneProof> call(VerifyOwnPhoneParams params) =>
      _repository.verifyOwnPhone(handle: params.handle, otp: params.otp);
}

class VerifyOwnPhoneParams extends Equatable {
  const VerifyOwnPhoneParams({required this.handle, required this.otp});

  final PhoneVerificationHandle handle;
  final String otp;

  // The code is left out: props end up in test-failure and debug output.
  @override
  List<Object?> get props => [handle];
}

/// Sets a new password with the phone proof instead of the current password.
class ChangePasswordWithPhoneProof
    extends UseCase<void, ChangePasswordWithPhoneProofParams> {
  const ChangePasswordWithPhoneProof(this._repository);
  final PhonePasswordChangeRepository _repository;

  @override
  ResultFuture<void> call(ChangePasswordWithPhoneProofParams params) =>
      _repository.changePasswordWithPhoneProof(
        proof: params.proof,
        newPassword: params.newPassword,
      );
}

class ChangePasswordWithPhoneProofParams extends Equatable {
  const ChangePasswordWithPhoneProofParams({
    required this.proof,
    required this.newPassword,
  });

  final PhoneProof proof;
  final String newPassword;

  // The password is left out for the same reason.
  @override
  List<Object?> get props => [proof];
}
