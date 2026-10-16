import 'package:equatable/equatable.dart';

/// What `forgot-password/verify-otp` hands back once the SMS code checks out:
/// a one-time [resetToken] for the reset call, and the [policy] the new
/// password must meet.
class PasswordResetGrant extends Equatable {
  const PasswordResetGrant({
    required this.resetToken,
    this.expiresIn,
    this.policy = const PasswordPolicy(),
  });

  final String resetToken;

  /// Seconds until [resetToken] stops working.
  final int? expiresIn;

  final PasswordPolicy policy;

  @override
  List<Object?> get props => [resetToken, expiresIn, policy];
}

/// The server's password rules. Checked on the device only so the rep hears
/// about a weak password before the round trip — the server re-checks, and a
/// rejected password leaves the reset token usable.
class PasswordPolicy extends Equatable {
  const PasswordPolicy({
    this.minLength = 0,
    this.maxLength = 0,
    this.requireUppercase = false,
    this.requireLowercase = false,
    this.requireNumber = false,
    this.requireSpecial = false,
  });

  final int minLength;

  /// Zero means no upper bound was sent.
  final int maxLength;
  final bool requireUppercase;
  final bool requireLowercase;
  final bool requireNumber;
  final bool requireSpecial;

  /// The first rule [password] breaks, or null when it meets them all.
  PasswordRule? firstViolation(String password) {
    if (password.length < minLength) return PasswordRule.minLength;
    if (maxLength > 0 && password.length > maxLength) {
      return PasswordRule.maxLength;
    }
    if (requireUppercase && !password.contains(RegExp('[A-Z]'))) {
      return PasswordRule.uppercase;
    }
    if (requireLowercase && !password.contains(RegExp('[a-z]'))) {
      return PasswordRule.lowercase;
    }
    if (requireNumber && !password.contains(RegExp('[0-9]'))) {
      return PasswordRule.number;
    }
    if (requireSpecial && !password.contains(RegExp('[^A-Za-z0-9]'))) {
      return PasswordRule.special;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        minLength,
        maxLength,
        requireUppercase,
        requireLowercase,
        requireNumber,
        requireSpecial,
      ];
}

enum PasswordRule {
  minLength,
  maxLength,
  uppercase,
  lowercase,
  number,
  special
}
