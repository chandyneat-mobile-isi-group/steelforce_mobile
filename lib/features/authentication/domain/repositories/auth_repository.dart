import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/auth_profile.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';

/// The contract the domain depends on. The data layer provides the
/// implementation; the domain never knows about Dio, JSON, or storage.
abstract interface class AuthRepository {
  /// [identifier] is a personnel number **or** an e-mail address — the server
  /// resolves whichever arrives, so the login form carries a single field.
  ResultFuture<AuthProfile> login({
    required String identifier,
    required String password,
    String? pushToken,
    bool rememberDevice,
  });

  /// The persisted session, resolved from cache so a cold start on no signal
  /// still boots into the app.
  ResultFuture<AuthProfile> getCurrentUser();

  /// Re-reads `GET /auth/me`, falling back to the cached copy when offline or
  /// when the call fails — a stale permission set beats an empty screen.
  ResultFuture<AuthProfile> refreshProfile();

  /// The cached profile without any network call. Null when signed out.
  ResultFuture<AuthProfile?> cachedProfile();

  /// Ends the local session, and best-effort revokes it server-side.
  /// [allDevices] ends every session — offer it after a password change or a
  /// suspected compromise.
  ResultFuture<void> logout({bool allDevices});

  ResultFuture<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Forgets the temporary-password flag on the cached session after the rep
  /// has set their own password.
  ResultFuture<void> markPasswordChanged();

  /// Password reset by SMS, step 1: texts a code to [phoneNumber]. Always
  /// reports success for a well-formed number, whether or not it is
  /// registered — anything else would make this an account-enumeration
  /// oracle. Calling it again is "resend".
  ResultFuture<void> forgotPassword(String phoneNumber);

  /// Step 2: checks the code and returns the one-time reset token with the
  /// password policy the new password must meet.
  ResultFuture<PasswordResetGrant> verifyResetCode({
    required String phoneNumber,
    required String otp,
  });

  /// Step 3: sets the new password with the token from [verifyResetCode].
  ResultFuture<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });
}
