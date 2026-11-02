import 'package:equatable/equatable.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';

/// Where the signed-in phone password change stands. No state carries the
/// Firebase token or the phone proof: states reach observers and test output.
sealed class PhonePasswordChangeState extends Equatable {
  const PhonePasswordChangeState();

  @override
  List<Object?> get props => const [];
}

/// Asking the backend to open a verification and Firebase to send the SMS.
final class PhonePasswordChangeStarting extends PhonePasswordChangeState {
  const PhonePasswordChangeStarting();
}

/// A code is on its way to [phoneNumber], the account's own number.
final class PhonePasswordChangeCodeSent extends PhonePasswordChangeState {
  const PhonePasswordChangeCodeSent({
    required this.phoneNumber,
    required this.resendAfter,
    required this.attempt,
    this.verifiedWithoutCode = false,
  });

  /// E.164, as the backend returned it. Mask it before showing it.
  final String phoneNumber;
  final Duration resendAfter;

  /// Counts starts, so a resend is a new state even for the same number.
  final int attempt;

  /// Android confirmed the number with no code to type.
  final bool verifiedWithoutCode;

  @override
  List<Object?> get props =>
      [phoneNumber, resendAfter, attempt, verifiedWithoutCode];
}

/// The backend issued a phone proof; the rep picks the new password.
final class PhonePasswordChangeEnteringPassword
    extends PhonePasswordChangeState {
  const PhonePasswordChangeEnteringPassword(this.policy);

  final PasswordPolicy policy;

  @override
  List<Object?> get props => [policy];
}

/// The password changed. The rep's other sessions were ended by the server.
final class PhonePasswordChangeSucceeded extends PhonePasswordChangeState {
  const PhonePasswordChangeSucceeded();
}

/// Stopped. Any proof was dropped; [canRestart] says whether a new code can
/// help.
final class PhonePasswordChangeHalted extends PhonePasswordChangeState {
  const PhonePasswordChangeHalted(this.failure, {required this.canRestart});

  final Failure failure;
  final bool canRestart;

  @override
  List<Object?> get props => [failure, canRestart];
}
