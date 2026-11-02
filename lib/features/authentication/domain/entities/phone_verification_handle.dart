import 'package:equatable/equatable.dart';

/// Where a phone-ownership check stands after the code was requested: what the
/// code screen needs to confirm it, or — when the platform verified the number
/// with no code to type — the proof itself.
///
/// Held in route arguments for the life of the reset only, never persisted.
/// The fields are provider-specific and opaque to the domain.
class PhoneVerificationHandle extends Equatable {
  const PhoneVerificationHandle.codeSent({
    required this.phoneNumber,
    required String this.verificationId,
    this.resendToken,
    this.resendAfter = 60,
    this.expiresIn = 300,
    this.automaticProof,
  }) : instantProof = null;

  /// Android can confirm a number without an SMS round trip (instant
  /// verification). There is then no code to type.
  const PhoneVerificationHandle.verified({
    required this.phoneNumber,
    required String this.instantProof,
    this.resendAfter = 60,
    this.expiresIn = 300,
  })  : verificationId = null,
        resendToken = null,
        automaticProof = null;

  /// E.164, as the code was requested for.
  final String phoneNumber;

  /// Identifies the code that was sent. Null when [isVerified].
  final String? verificationId;

  /// Lets "resend" reuse the same verification session.
  final int? resendToken;

  /// Backend-provided cooldown and validity window for this verification.
  final int resendAfter;
  final int expiresIn;

  /// Completes when Android retrieves the SMS after the entry screen opens.
  /// Not serialized, persisted, or included in equality/debug output.
  final Future<String>? automaticProof;

  /// Proof of ownership obtained without a code. Never shown, never logged.
  final String? instantProof;

  bool get isVerified => instantProof != null;

  // The proof is left out on purpose: two handles for the same session are the
  // same handle, and props end up in test-failure and debug output.
  @override
  List<Object?> get props => [
        phoneNumber,
        verificationId,
        resendAfter,
        expiresIn,
      ];
}
