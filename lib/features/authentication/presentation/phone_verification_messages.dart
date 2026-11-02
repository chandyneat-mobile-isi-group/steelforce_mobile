import 'package:steelforce/core/error/failure_message.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_ownership_reset_repository.dart';
import 'package:steelforce/features/authentication/domain/repositories/phone_password_change_repository.dart';

/// The rep-facing text for a Firebase phone-check failure carried as
/// `phone.<firebase-code>`, or null when [code] is not one.
String? firebasePhoneMessage(String? code) {
  if (code == null || !code.startsWith(phoneFailurePrefix)) return null;
  return switch (code.substring(phoneFailurePrefix.length)) {
    'invalid-verification-code' => 'auth.invalid_code'.tr,
    'session-expired' || 'code-expired' => 'auth.phone_code_expired'.tr,
    'too-many-requests' ||
    'quota-exceeded' =>
      'auth.phone_too_many_requests'.tr,
    'invalid-phone-number' => 'auth.phone_invalid_number'.tr,
    'network-request-failed' => 'auth.phone_no_connection'.tr,
    // app-not-authorized, missing-client-identifier, unavailable, timeout…:
    // configuration or platform problems the rep cannot fix by retyping.
    _ => 'auth.phone_verification_unavailable'.tr,
  };
}

/// True when the backend refused for rate.
bool isRateLimitFailure(Failure f) =>
    f is ServerFailure &&
    (f.statusCode == 429 || f.code == ApiErrorCodes.tooManyRequests);

/// The rep-facing text for a failure in the signed-in phone password change.
/// Never a raw exception, token or trace id.
String phonePasswordChangeMessage(Failure f) {
  if (f is NetworkFailure) return 'auth.phone_no_connection'.tr;
  if (f is ServerUnreachableFailure) return 'common.server_unreachable'.tr;
  if (isRateLimitFailure(f)) {
    final wait = (f as ServerFailure).retryAfter;
    return wait == null
        ? 'auth.rate_limit_message'.tr
        : 'auth.rate_limit_wait'.trParams({'seconds': wait.inSeconds});
  }
  final code = switch (f) {
    AuthenticationFailure(:final code) => code,
    ServerFailure(:final code) => code,
    _ => null,
  };
  final firebase = firebasePhoneMessage(code);
  if (firebase != null) return firebase;
  switch (code) {
    case PhonePasswordChangeCodes.phoneNumberRequired:
      return 'auth.own_phone_number_missing'.tr;
    case PhonePasswordChangeCodes.channelDisabled:
      return 'auth.own_phone_channel_disabled'.tr;
    case PhonePasswordChangeCodes.proofInvalid:
      return 'auth.own_phone_proof_invalid'.tr;
    case PhonePasswordChangeCodes.outcomeUnknown:
      return 'auth.own_password_outcome_unknown'.tr;
  }
  // A 401 that is not a refused proof: the session itself is gone.
  if (f is AuthenticationFailure) return 'auth.validation.session_expired'.tr;
  if (f.statusCode == 403) return 'auth.own_password_forbidden'.tr;
  // A policy or validation refusal. The server localises these, and the rep
  // needs its reason to pick a better password.
  if (f.statusCode == 400 && f.message.isNotEmpty) return f.userMessage;
  return 'auth.something_went_wrong'.tr;
}
