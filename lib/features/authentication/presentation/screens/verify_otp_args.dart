/// Route argument for `Static.verifyOtp`.
///
/// The code screen serves password reset only — sign-in is a single request
/// with no code step. The SMS code is checked against
/// `forgot-password/verify-otp`, which answers with a one-time reset token.
class VerifyOtpArgs {
  const VerifyOtpArgs._({required this.target});

  /// [target] is the phone number the code was sent to.
  factory VerifyOtpArgs.passwordReset({required String target}) =>
      VerifyOtpArgs._(target: target);

  /// Where the code was sent, for the "we sent a code to …" line.
  final String target;
}
