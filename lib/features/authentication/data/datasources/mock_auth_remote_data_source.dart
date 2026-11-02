// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
// This is an AUTH BYPASS: it accepts any non-empty credentials and never
// contacts the identity server.
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/datasources/demo_rep_fixture.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';

/// [AuthRemoteDataSource] for the backend-less demo (`USE_MOCK_DATA=true`).
///
/// Any non-empty identifier and password sign in as [DemoRep]. Every call
/// stays in memory, so the sign-in path makes no network request. The
/// repository above still persists the token pair and profile through the
/// real local source, so reloading the page restores the session the same
/// way a live build does.
///
/// There is no refresh method to fake here. Refresh lives in the core
/// `AuthInterceptor` and runs only on a 401, which a mock never returns.
class MockAuthRemoteDataSource implements AuthRemoteDataSource {
  MockAuthRemoteDataSource();

  DateTime? _signedInAt;

  @override
  Future<AuthTokenModel> login({
    required String phoneNumber,
    required String password,
    String? pushToken,
    bool rememberDevice = true,
  }) async {
    await MockLatency.tick();
    // The form already requires both fields. This check keeps the
    // wrong-credentials path testable in a demo instead of unreachable.
    if (phoneNumber.trim().isEmpty || password.isEmpty) {
      throw const ApiException(ApiError(
        code: ApiErrorCodes.invalidCredentials,
        statusCode: 400,
      ));
    }
    _signedInAt = DateTime.now().toUtc();
    return DemoRep.issueTokens();
  }

  @override
  Future<AuthProfileModel> getProfile() async {
    await MockLatency.tick();
    return DemoRep.profile(lastLoginAt: _signedInAt);
  }

  @override
  Future<void> logout({
    required String refreshToken,
    bool allDevices = false,
  }) async {
    _signedInAt = null;
  }

  /// Dropped, not stored. A demo has no session list to show a location on,
  /// and holding a GPS trace in memory serves no one.
  @override
  Future<void> sendHeartbeat(
    double lat,
    double lng,
    double accuracy,
    DateTime capturedAt,
  ) async {}

  /// Accepted without a check. There is no stored password to verify
  /// against, and the screens' own validation still runs.
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await MockLatency.tick();
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await MockLatency.tick();
  }
}
