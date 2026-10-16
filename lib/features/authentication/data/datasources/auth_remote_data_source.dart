import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/data/models/password_reset_grant_model.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';

abstract interface class AuthRemoteDataSource {
  /// Signs in with a personnel number **or** an e-mail address.
  ///
  /// The server resolves whichever arrives, which is why the login form has a
  /// single field labelled "Employee ID or e-mail": field representatives know
  /// their personnel number — it is on their badge and payslip — and often
  /// have no company e-mail, while portal users keep using theirs.
  Future<AuthTokenModel> login({
    required String phoneNumber,
    required String password,
    String? pushToken,
    bool rememberDevice,
  });

  /// The signed-in employee's profile, including permissions and feature flags.
  Future<AuthProfileModel> getProfile();

  /// Ends this session, or every session when [allDevices] is true.
  Future<void> logout({required String refreshToken, bool allDevices});

  Future<void> sendHeartbeat(
      double lat, double lng, double accuracy, DateTime capturedAt);

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  /// Password reset, step 1: texts a code to [phoneNumber].
  Future<void> forgotPassword(String phoneNumber);

  /// Step 2: trades the 6-digit code for a one-time reset token and the
  /// password policy.
  Future<PasswordResetGrantModel> verifyResetCode({
    required String phoneNumber,
    required String otp,
  });

  /// Step 3: sets the new password with the token from step 2.
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl({
    required Dio authedClient,
    required Dio bareClient,
    required DeviceIdentity device,
    LocationFixProvider? Function()? getFixProvider,
  })  : _authed = authedClient,
        _bare = bareClient,
        _device = device,
        _getFixProvider = getFixProvider;

  /// Carries [AuthInterceptor]. Used for everything that needs a bearer token.
  final Dio _authed;

  /// No auth interceptor. Used for the endpoints that establish or recover a
  /// session — sending a stale bearer token to `/auth/login` would at best be
  /// pointless and at worst trip the refresh path on a 401 that is really
  /// "wrong password".
  final Dio _bare;

  final DeviceIdentity _device;

  final LocationFixProvider? Function()? _getFixProvider;

  @override
  Future<AuthTokenModel> login({
    required String phoneNumber,
    required String password,
    String? pushToken,
    bool rememberDevice = true,
  }) async {
    try {
      final res = await _bare.post<DataMap>(
        // `/mobile/auth/login`, not `/auth/login`. Both currently accept this
        // body, but the mobile route is the one the backend team designates
        // for this client — and it is the same URL the OTP exchange used, so
        // this is a change of request body, not of routing.
        ApiEndpoints.loginEndpoint,
        data: {
          // `employeeId` accepts an e-mail address too; the server resolves it.
          // It does **not** accept a phone number — verified against staging,
          // where a phone identifier returns `invalid_grant`.
          'phoneNumber': phoneNumber.trim(),
          'password': password,
          // Sent flat as well as inside `device`: the mobile route reads the
          // flat key, while the richer object is what makes the sessions list
          // legible when a rep loses a handset.
          'deviceId': await _device.deviceId(),
          // Optional, but always sent: it is what turns the session list into
          // something a rep can act on when they lose a handset.
          'device': await _device.describe(
            pushToken: pushToken,
            rememberDevice: rememberDevice,
          ),
        },
        options: await _locationHeaders(),
      );

      final token = AuthTokenModel.fromMap(res.data ?? const {});
      if (!token.isUsable) {
        throw const ApiException(ApiError(
          code: ApiErrorCodes.unknown,
          detail: 'Login succeeded but returned no usable token pair.',
        ));
      }
      return token;
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<AuthProfileModel> getProfile() async {
    try {
      final res = await _authed.get<DataMap>(ApiEndpoints.currentUserEndpoint);
      // Wrapped, unlike the token endpoints above.
      return AuthProfileModel.fromJson(ApiEnvelope.fromBody(res.data).data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  /// Server-side revocation. Returns 204.
  ///
  /// The caller clears secure storage regardless of the outcome here — a token
  /// discarded locally is unusable whether or not the server was told.
  @override
  Future<void> logout({
    required String refreshToken,
    bool allDevices = false,
  }) async {
    try {
      await _authed.post<void>(
        ApiEndpoints.logoutEndpoint,
        data: {'refreshToken': refreshToken, 'allDevices': allDevices},
        options: Options(
          // By the time this runs the session may already be gone locally, so
          // a 401 is expected and uninteresting. Letting it come back as a
          // plain response keeps it out of the interceptor's refresh path,
          // which would otherwise burn a connect timeout re-authenticating a
          // session that no longer exists.
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<void> sendHeartbeat(
    double lat,
    double lng,
    double accuracy,
    DateTime capturedAt,
  ) async {
    try {
      await _authed.post<void>(
        '${ApiEndpoints.sessionsEndpoint}/current/location',
        data: {
          'latitude': lat,
          'longitude': lng,
          'accuracyMeters': accuracy,
          'capturedAt': capturedAt.toUtc().toIso8601String(),
        },
      );
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  /// Re-verifies [currentPassword] even though the caller is already
  /// authenticated. That is deliberate on the server's part: it is what stops
  /// a borrowed unlocked handset from becoming a permanent account takeover.
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _post(
        _authed,
        ApiEndpoints.changePasswordEndpoint,
        {'currentPassword': currentPassword, 'newPassword': newPassword},
      );

  /// Always succeeds for a well-formed number, whether or not an account
  /// has it.
  ///
  /// Do not "improve" the UX by reporting an unknown number — that turns the
  /// endpoint into an account-enumeration oracle. Show "if that number is
  /// registered, a code is on its way". Also serves as "resend": the server
  /// enforces its own cooldown and hourly limit.
  @override
  Future<void> forgotPassword(String phoneNumber) =>
      _post(_bare, ApiEndpoints.sendOtpEndpoint, {
        'recoveryMethod': _phoneRecovery,
        // As the user typed it, matching sign-in: the server matches on digits.
        'phoneNumber': phoneNumber.trim(),
      });

  /// Only the newest code for the number is accepted. A wrong code answers
  /// 400 with `attemptsRemaining`; the last allowed attempt locks the code
  /// until a new one is requested.
  @override
  Future<PasswordResetGrantModel> verifyResetCode({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final res = await _bare.post<DataMap>(
        ApiEndpoints.verifyOtpEndpoint,
        data: {
          'recoveryMethod': _phoneRecovery,
          'phoneNumber': phoneNumber.trim(),
          'otp': otp,
        },
      );
      final grant =
          PasswordResetGrantModel.fromJson(ApiEnvelope.fromBody(res.data).data);
      if (grant.resetToken.isEmpty) {
        throw const ApiException(ApiError(
          code: ApiErrorCodes.unknown,
          detail: 'Code accepted but no reset token returned.',
        ));
      }
      return grant;
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  /// The token works once, but a password that fails the policy leaves it
  /// usable so the rep can try again. Success signs the account out
  /// everywhere.
  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) =>
      _post(_bare, ApiEndpoints.resetOtpEndpoint, {
        'resetToken': resetToken,
        'newPassword': newPassword,
        // The form already checked both fields match; the API wants both.
        'confirmPassword': newPassword,
      });

  static const _phoneRecovery = 'phone';

  Future<void> _post(Dio client, String path, DataMap body) async {
    try {
      await client.post<void>(path, data: body);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  Future<Options?> _locationHeaders() async {
    if (_getFixProvider == null) return null;
    final provider = _getFixProvider();
    if (provider == null) return null;
    try {
      final fix = await provider.currentFix(
        precise: false,
        timeout: const Duration(seconds: 3),
      );
      if (fix == null || (fix.latitude == 0 && fix.longitude == 0)) return null;
      return Options(
        headers: {
          'X-Location-Lat': fix.latitude.toStringAsFixed(6),
          'X-Location-Lng': fix.longitude.toStringAsFixed(6),
          'X-Location-Accuracy': fix.accuracyMeters.toStringAsFixed(1),
          'X-Location-At': fix.timestamp.toUtc().toIso8601String(),
        },
      );
    } catch (_) {
      return null;
    }
  }
}
