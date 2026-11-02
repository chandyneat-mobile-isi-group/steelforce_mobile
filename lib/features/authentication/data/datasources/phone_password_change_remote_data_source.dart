import 'package:dio/dio.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/password_reset_request_trace.dart';
import 'package:steelforce/features/authentication/data/datasources/password_reset_trace_failure.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/datasources/phone_reset_remote_data_source.dart';

/// The signed-in half of the phone password flow: `auth/password/phone/*`
/// and `auth/password`. Every call carries the bearer token.
abstract interface class PhonePasswordChangeRemoteDataSource {
  /// The first step before Firebase sends the SMS, with the account's own
  /// [phoneNumber] (E.164) as the only body field. Returns the number to
  /// pass to Firebase.
  Future<PhoneResetStartModel> startOwnPhoneVerification({
    required String phoneNumber,
  });

  /// Trades Firebase's ID token for `{phoneProofToken, expiresIn}`.
  Future<({String token, int expiresIn})> verifyOwnPhone(
    String firebaseIdToken,
  );

  /// 204 on success. Sends the proof and never `currentPassword`: the
  /// request must carry exactly one of the two.
  Future<void> changePasswordWithProof({
    required String phoneProofToken,
    required String newPassword,
  });
}

class PhonePasswordChangeRemoteDataSourceImpl
    implements PhonePasswordChangeRemoteDataSource {
  const PhonePasswordChangeRemoteDataSourceImpl({required Dio authedClient})
      : _authed = authedClient;

  /// Carries `AuthInterceptor`, which refreshes a stale bearer token once but
  /// never replays a 401 that refuses the phone proof itself.
  final Dio _authed;

  @override
  Future<PhoneResetStartModel> startOwnPhoneVerification({
    required String phoneNumber,
  }) async {
    const path = ApiEndpoints.startOwnPhoneVerificationEndpoint;
    final body = {'phoneNumber': phoneNumber};
    final trace = PasswordResetRequestTrace.start(
      method: 'POST',
      path: path,
      requestBody: body,
    );
    try {
      final res = await _authed.post<dynamic>(path, data: body);
      final data = _data(res.data);
      trace.response(status: res.statusCode, body: res.data);
      return PhoneResetStartModel.fromResponse(
        data,
        sentPhoneNumber: phoneNumber,
      );
    } on DioException catch (e) {
      throw ApiException(trace.dioFailure(e));
    }
  }

  /// The backend checks the token's signature, audience, expiry and sign-in
  /// time itself, and that its number is this account's.
  @override
  Future<({String token, int expiresIn})> verifyOwnPhone(
    String firebaseIdToken,
  ) async {
    const path = ApiEndpoints.verifyOwnPhoneEndpoint;
    final body = {'firebaseIdToken': firebaseIdToken};
    final trace = PasswordResetRequestTrace.start(
      method: 'POST',
      path: path,
      requestBody: body,
    );
    try {
      final res = await _authed.post<dynamic>(path, data: body);
      final data = _data(res.data);
      final token = data['phoneProofToken'];
      if (token is! String || token.isEmpty) {
        trace.failure(
            status: res.statusCode, type: 'invalid_response', body: res.data);
        throw const ApiException(ApiError(
          code: ApiErrorCodes.unknown,
          detail: 'Phone verified but no phone proof token returned.',
        ));
      }
      trace.response(status: res.statusCode, body: res.data);
      return (
        token: token,
        expiresIn: (data['expiresIn'] as num?)?.toInt() ?? 300,
      );
    } on DioException catch (e) {
      throw ApiException(trace.dioFailure(e));
    }
  }

  /// The body of a 204 is never read.
  @override
  Future<void> changePasswordWithProof({
    required String phoneProofToken,
    required String newPassword,
  }) async {
    const path = ApiEndpoints.changePasswordWithProofEndpoint;
    final body = {
      'phoneProofToken': phoneProofToken,
      'newPassword': newPassword,
    };
    final trace = PasswordResetRequestTrace.start(
      method: 'POST',
      path: path,
      requestBody: body,
    );
    try {
      final res = await _authed.post<dynamic>(path, data: body);
      trace.response(status: res.statusCode, body: res.data);
    } on DioException catch (e) {
      throw ApiException(trace.dioFailure(e));
    }
  }

  /// The envelope's `data`, or an [ApiException] when the body is not one.
  static DataMap _data(Object? body) {
    try {
      return ApiEnvelope.fromBody(body).data;
    } on ServerException catch (e) {
      throw ApiException(ApiError(
        code: ApiErrorCodes.unknown,
        detail: e.message,
      ));
    }
  }
}
