import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';

/// Route argument for `Static.verifyOtp`.
///
/// The code screen serves password reset only — sign-in is a single request
/// with no code step. By default the SMS code is checked against
/// `auth/forgot-password/phone/verify`, which answers with a one-time
/// reset token.
/// When the code was sent through Firebase instead, [phoneVerification]
/// carries the session to confirm it against.
class VerifyOtpArgs {
  const VerifyOtpArgs._({required this.target, this.phoneVerification});

  /// [target] is the phone number the code was sent to.
  factory VerifyOtpArgs.passwordReset({
    required String target,
    PhoneVerificationHandle? phoneVerification,
  }) =>
      VerifyOtpArgs._(target: target, phoneVerification: phoneVerification);

  /// Where the code was sent, for the "we sent a code to …" line.
  final String target;

  /// Set only on the Firebase reset path. Null means the backend sent the code.
  final PhoneVerificationHandle? phoneVerification;
}
