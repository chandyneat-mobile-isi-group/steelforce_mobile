import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';

/// Prefix on `AuthenticationFailure.code` for a failure the phone-verification
/// provider reported, e.g. `phone.invalid-verification-code`. The presentation
/// layer localises by code; the provider's own messages are English-only and
/// sometimes technical. Failures from the backend exchange carry the backend's
/// codes unprefixed.
const String phoneFailurePrefix = 'phone.';

/// Password reset where a phone-verification provider (Firebase Phone Auth),
/// not the SteelForce backend, texts and checks the code.
///
/// An alternative to steps 1–2 of `AuthRepository`'s SMS reset that ends in the
/// same [PasswordResetGrant], so step 3 is unchanged:
/// `AuthRepository.resetPassword`.
///
/// The device never decides the rep is allowed to reset. It only obtains
/// provider-signed proof of phone ownership; the backend verifies that proof
/// itself and decides whether an eligible account goes with the number.
abstract interface class PhoneOwnershipResetRepository {
  /// Texts a code to [phoneNumber] (E.164). Pass [previous] to resend within
  /// the same verification session.
  ///
  /// The returned handle may already be verified — Android can confirm a
  /// number with no code — in which case [verifyResetCode] needs no code.
  ResultFuture<PhoneVerificationHandle> sendResetCode(
    String phoneNumber, {
    PhoneVerificationHandle? previous,
  });

  /// Confirms [otp] with the provider, then trades the provider's proof for
  /// the backend's one-time reset grant. [otp] is ignored when [handle] is
  /// already verified.
  ResultFuture<PasswordResetGrant> verifyResetCode({
    required PhoneVerificationHandle handle,
    required String otp,
  });

  /// Confirms [otp] with the provider only — no backend call, no grant.
  ///
  /// For the debug check-only mode (`AppConfig.firebasePhoneCheckOnly`), so
  /// sending and confirming a code can be tested before the backend exchange
  /// exists. Proves nothing to the backend and must never gate a reset.
  ResultFuture<void> confirmOwnership({
    required PhoneVerificationHandle handle,
    required String otp,
  });
}
