// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
// These bypass phone-ownership proof: any code is accepted, and no SMS is
// sent through Firebase Phone Auth.
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_ownership_verifier.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_password_change_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_reset_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/password_reset_grant_model.dart';
import 'package:steelforce/features/authentication/domain/entities/password_reset_grant.dart';

/// The phone-proof flows (forgot password, signed-in change by SMS) for the
/// backend-less demo (`USE_MOCK_DATA=true`).
///
/// On web the router never offers these flows, because `_resetViaFirebase` is
/// false there. They matter for a native build run with mocks. Without them,
/// that build would still send a real SMS through Firebase and then post the
/// proof to a backend that does not exist.
///
/// Every step succeeds with the values a real server answers with. The
/// screens' own policy checks and confirmation matching still run.
abstract final class _DemoPhoneProof {
  static const expiresIn = 300;
  static const resendAfter = 60;
  static const verificationId = 'demo-verification';
  static const firebaseIdToken = 'demo-firebase-id-token';
  static const phoneProofToken = 'demo-phone-proof';
  static const resetToken = 'demo-reset-token';
}

class MockPhoneOwnershipVerifier implements PhoneOwnershipVerifier {
  const MockPhoneOwnershipVerifier();

  @override
  Future<PhoneCodeDispatch> sendCode(
    String phoneNumber, {
    int? resendToken,
  }) async {
    await MockLatency.tick();
    return PhoneCodeDispatch.sent(
      _DemoPhoneProof.verificationId,
      (resendToken ?? 0) + 1,
    );
  }

  /// Any code is accepted, so a demo never needs an SMS to get through.
  @override
  Future<String> confirmCode({
    required String verificationId,
    required String code,
  }) async {
    await MockLatency.tick();
    return _DemoPhoneProof.firebaseIdToken;
  }
}

class MockPhoneResetRemoteDataSource implements PhoneResetRemoteDataSource {
  const MockPhoneResetRemoteDataSource();

  @override
  Future<PhoneResetStartModel> startVerification({
    required String phoneNumber,
  }) async {
    await MockLatency.tick();
    return PhoneResetStartModel(
      phoneNumber: phoneNumber.trim(),
      expiresIn: _DemoPhoneProof.expiresIn,
      resendAfter: _DemoPhoneProof.resendAfter,
    );
  }

  @override
  Future<PasswordResetGrantModel> exchangeFirebaseToken(
    String firebaseIdToken,
  ) async {
    await MockLatency.tick();
    return const PasswordResetGrantModel(
      resetToken: _DemoPhoneProof.resetToken,
      expiresIn: _DemoPhoneProof.expiresIn,
      policy: PasswordPolicy.productionReset,
    );
  }
}

class MockPhonePasswordChangeRemoteDataSource
    implements PhonePasswordChangeRemoteDataSource {
  const MockPhonePasswordChangeRemoteDataSource();

  @override
  Future<PhoneResetStartModel> startOwnPhoneVerification({
    required String phoneNumber,
  }) async {
    await MockLatency.tick();
    return PhoneResetStartModel(
      phoneNumber: phoneNumber,
      expiresIn: _DemoPhoneProof.expiresIn,
      resendAfter: _DemoPhoneProof.resendAfter,
    );
  }

  @override
  Future<({String token, int expiresIn})> verifyOwnPhone(
    String firebaseIdToken,
  ) async {
    await MockLatency.tick();
    return (
      token: _DemoPhoneProof.phoneProofToken,
      expiresIn: _DemoPhoneProof.expiresIn,
    );
  }

  @override
  Future<void> changePasswordWithProof({
    required String phoneProofToken,
    required String newPassword,
  }) async {
    await MockLatency.tick();
  }
}
