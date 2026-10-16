import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/authentication/presentation/screens/verify_otp_args.dart';

/// The code screen serves password reset only: sign-in is a single request
/// with no code step.
void main() {
  test('carries the number the reset code went to', () {
    final args = VerifyOtpArgs.passwordReset(target: '+85512345209');
    expect(args.target, '+85512345209');
  });
}
