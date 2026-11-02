import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';

/// Reads the unwrapped `data` of `auth/forgot-password/phone/verify`:
/// `{resetToken, expiresIn, passwordPolicy}`. The server's policy wins; the
/// production rules apply only when a server sends none.
class PasswordResetGrantModel extends PasswordResetGrant {
  const PasswordResetGrantModel({
    required super.resetToken,
    super.expiresIn,
    super.policy,
  });

  factory PasswordResetGrantModel.fromJson(DataMap json) {
    final policy = json['passwordPolicy'];
    return PasswordResetGrantModel(
      resetToken: json['resetToken'] as String? ?? '',
      expiresIn: (json['expiresIn'] as num?)?.toInt(),
      policy: policy is Map
          ? _policy(DataMap.from(policy))
          : PasswordPolicy.productionReset,
    );
  }

  static PasswordPolicy _policy(DataMap json) => PasswordPolicy(
        minLength: (json['minLength'] as num?)?.toInt() ?? 0,
        maxLength: (json['maxLength'] as num?)?.toInt() ?? 0,
        requireUppercase: json['requireUppercase'] == true,
        requireLowercase: json['requireLowercase'] == true,
        requireNumber: json['requireNumber'] == true,
        requireSpecial: json['requireSpecial'] == true,
        minDistinctCharacters:
            (json['minDistinctCharacters'] as num?)?.toInt() ?? 0,
      );
}
