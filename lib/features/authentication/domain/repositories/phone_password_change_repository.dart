import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_proof.dart';
import 'package:steelforce/features/authentication/domain/entities/phone_verification_handle.dart';

/// `Failure.code` values for the signed-in phone password change. The backend
/// sends these as wrapped-envelope codes; they are carried as-is so the
/// presentation layer can tell them apart from an expired session.
abstract final class PhonePasswordChangeCodes {
  /// 400 on start: the account has no phone number to text.
  static const phoneNumberRequired = 'AUTH_PHONE_NUMBER_REQUIRED';

  /// 400 on start: the server is not configured for Firebase phone checks.
  static const channelDisabled = 'AUTH_PHONE_CHANNEL_DISABLED';

  /// 401 on verify or change: the proof is wrong, expired or already spent.
  /// Not a session expiry. Restart from the start call.
  static const proofInvalid = 'AUTH_PHONE_PROOF_INVALID';

  /// The change call failed with no answer from the server, so the proof
  /// may already be spent and the password may already have changed.
  static const outcomeUnknown = 'phone_change.outcome_unknown';
}

/// Changing the signed-in rep's own password without the current one: an SMS
/// to the account's number, sent and checked by Firebase, proves who they are.
///
/// Firebase proves control of the phone; the backend verifies that proof
/// itself and issues the authorization. The device decides neither.
abstract interface class PhonePasswordChangeRepository {
  /// Asks the backend to open a verification for the account's own number,
  /// then has Firebase text that number. Never takes a number from the device.
  ///
  /// Also the resend: the backend allows one SMS per verification, so a new
  /// code always means a new start.
  ResultFuture<PhoneVerificationHandle> startOwnPhoneVerification();

  /// Confirms [otp] with Firebase, then trades Firebase's fresh ID token for
  /// the backend's [PhoneProof]. [otp] is ignored when [handle] is already
  /// verified. The raw code never reaches the backend.
  ResultFuture<PhoneProof> verifyOwnPhone({
    required PhoneVerificationHandle handle,
    required String otp,
  });

  /// Sets [newPassword], authorized by [proof] instead of the current
  /// password. Not retried: [proof] is single-use.
  ResultFuture<void> changePasswordWithPhoneProof({
    required PhoneProof proof,
    required String newPassword,
  });
}
