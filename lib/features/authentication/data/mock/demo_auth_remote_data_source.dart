import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:steelforce/features/authentication/data/models/auth_profile_model.dart';
import 'package:steelforce/features/authentication/data/models/auth_token_model.dart';
import 'package:steelforce/features/authentication/data/models/password_reset_grant_model.dart';

/// The demo build's identity server: one sales-rep account, no network.
///
/// It answers in the server's own shapes — the same `AuthTokenModel.fromMap`
/// and `AuthProfileModel.fromJson` parse what it returns — and fails with the
/// same `ApiError` codes, so `AuthRepositoryImpl` and every screen behind it
/// run their real success *and* failure paths.
///
/// The password is always [DemoSeed.signInPassword]. Change and reset run
/// their full flows and report success, but never replace it: whoever picks
/// up the demo next can still sign in with the published credentials.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
/// A live build registers `AuthRemoteDataSourceImpl` instead.
class DemoAuthRemoteDataSource implements AuthRemoteDataSource {
  DemoAuthRemoteDataSource(
    this._network, {
    String Function(String key)? translate,
  }) : _translate = translate ?? LocalizationService.instance.translate;

  final DemoNetwork _network;

  /// The real server localises `error_description` against the app's
  /// language. Standing in for it, this source does the same — otherwise a
  /// Khmer demo would show the repository's English fallback.
  final String Function(String key) _translate;

  String? _issuedResetToken;

  static const _accessToken = 'demo-access-token';
  static const _refreshToken = 'demo-refresh-token';
  static const _resetToken = 'demo-reset-token';

  /// Long enough that nothing in a demo session ever sees it lapse. Recorded
  /// for diagnostics only, exactly as with the real token.
  static const _tokenLifetimeSeconds = 12 * 60 * 60;

  static const _territoryCode = 'PP-CENTRAL';
  static const _lineManagerCode = '90000002';

  /// What a field sales representative holds. Both depot spellings, because
  /// the app accepts either (see `Permissions.canReadDepots`). Deliberately
  /// absent, as for a real rep: `depots.readall`, `depots.delete`,
  /// `depots.approve`.
  static const _repPermissions = [
    'depots.read',
    'depots.create',
    'depots.update',
    'outlets.read',
    'outlets.create',
    'outlets.update',
    'visits.read',
    'visits.create',
    'quotations.read',
    'quotations.create',
    'orders.read',
    'orders.create',
    'notifications.read',
  ];

  @override
  Future<AuthTokenModel> login({
    required String phoneNumber,
    required String password,
    String? pushToken,
    bool rememberDevice = true,
  }) async {
    await _network.roundTrip();
    if (!isDemoPhone(phoneNumber) || password != DemoSeed.signInPassword) {
      throw ApiException(_invalidCredentials());
    }
    // The mobile route's wrapped camelCase shape, parsed by the real reader.
    return AuthTokenModel.fromMap(const {
      'data': {
        'accessToken': _accessToken,
        'refreshToken': _refreshToken,
        'tokenType': 'Bearer',
        'expiresIn': _tokenLifetimeSeconds,
        'passwordChangeRequired': false,
      },
    });
  }

  /// True when [raw] is the demo number in any spelling the sign-in field can
  /// produce: it sends `+855` plus the digits typed, and a rep may type the
  /// national `0` prefix too — the real server matches on digits, so this does.
  static bool isDemoPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('855')) digits = digits.substring(3);
    if (digits.startsWith('0')) digits = digits.substring(1);
    return digits == DemoSeed.signInPhone;
  }

  @override
  Future<AuthProfileModel> getProfile() async {
    await _network.roundTrip();
    return AuthProfileModel.fromJson(demoProfileJson());
  }

  /// The `data` of `GET /auth/me` for the demo rep, in the live API's keys.
  static DataMap demoProfileJson() => {
        'userId': DemoSeed.repId,
        'empCode': DemoSeed.repPersonnelNo,
        'englishName': DemoSeed.repName,
        'khmerName': DemoSeed.repNameKm,
        'email': DemoSeed.repEmail,
        'phone': '+855${DemoSeed.signInPhone}',
        'roles': ['Sales Representative'],
        'department': 'Field Sales',
        'company': 'ISI Steel',
        'territoryCode': _territoryCode,
        'permissions': _repPermissions,
        'featureFlags': {'offlineSync': true},
        'timeZone': 'Asia/Phnom_Penh',
        'passwordChangeRequired': false,
        'lastLoginAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'lineManager': {
          'empCode': _lineManagerCode,
          'englishName': DemoSeed.managerName,
        },
        'isAdmin': false,
      };

  @override
  Future<void> logout({
    required String refreshToken,
    bool allDevices = false,
  }) =>
      _network.roundTrip();

  @override
  Future<void> sendHeartbeat(
    double lat,
    double lng,
    double accuracy,
    DateTime capturedAt,
  ) =>
      _network.roundTrip();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _network.roundTrip();
    // Re-verified, as the server does: an unlocked handset alone must not be
    // enough to take the account over.
    if (currentPassword != DemoSeed.signInPassword) {
      throw ApiException(_invalidCredentials());
    }
  }

  /// Succeeds for any number, as the real endpoint does — reporting an
  /// unknown number would make it an account-enumeration oracle.
  @override
  Future<void> forgotPassword(String phoneNumber) => _network.roundTrip();

  @override
  Future<PasswordResetGrantModel> verifyResetCode({
    required String phoneNumber,
    required String otp,
  }) async {
    await _network.roundTrip();
    if (otp.trim() != DemoSeed.resetCode) {
      throw ApiException(ApiError(
        code: ApiErrorCodes.invalidVerificationCode,
        message: _translate('auth.invalid_code'),
        statusCode: 400,
      ));
    }
    _issuedResetToken = _resetToken;
    return PasswordResetGrantModel.fromJson(const {
      'resetToken': _resetToken,
      'expiresIn': 600,
      'passwordPolicy': {
        'minLength': 8,
        'maxLength': 64,
        'requireUppercase': true,
        'requireLowercase': true,
        'requireNumber': true,
        'requireSpecial': false,
      },
    });
  }

  @override
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _network.roundTrip();
    // One use per verified code, as on the server.
    if (_issuedResetToken == null || resetToken != _issuedResetToken) {
      throw const ApiException(ApiError(
        code: ApiErrorCodes.verificationNotFound,
        statusCode: 400,
      ));
    }
    _issuedResetToken = null;
  }

  /// RFC 6749 answers a rejected grant with 400, not 401 — see [ApiError].
  ApiError _invalidCredentials() => ApiError(
        code: ApiErrorCodes.invalidCredentials,
        message: _translate('auth.invalid_credentials'),
        statusCode: 400,
      );
}
