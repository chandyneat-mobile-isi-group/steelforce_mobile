import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/logging/password_reset_request_trace.dart';
import 'package:steelforce/features/authentication/data/datasources/password_reset_trace_failure.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/authentication/data/models/password_reset_grant_model.dart';

abstract interface class PhoneResetRemoteDataSource {
  /// The first step before Firebase sends the SMS
  /// ([ApiEndpoints.startFirebaseResetEndpoint]). The body is `{phoneNumber}`
  /// only; returns the number to pass to Firebase.
  Future<PhoneResetStartModel> startVerification({required String phoneNumber});

  /// Trades a Firebase ID token proving phone ownership for the one-time
  /// `{verificationId, expiresIn}` the reset call needs.
  Future<PasswordResetGrantModel> exchangeFirebaseToken(String firebaseIdToken);
}

/// What a server `…/phone/start` answers, in both the forgot-password and
/// the signed-in change-password flows.
class PhoneResetStartModel {
  const PhoneResetStartModel({
    required this.phoneNumber,
    required this.expiresIn,
    required this.resendAfter,
  });

  /// Reads a start answer. `auth/otp/request` returns
  /// `{expiresAt, expiresIn, codeLength}` with no number, so Firebase gets
  /// [sentPhoneNumber]; a canonical `phoneNumber` in the answer wins if a
  /// server sends one.
  factory PhoneResetStartModel.fromResponse(
    DataMap data, {
    required String sentPhoneNumber,
  }) {
    final returned = data['phoneNumber'];
    return PhoneResetStartModel(
      phoneNumber: returned is String && _e164.hasMatch(returned)
          ? returned
          : sentPhoneNumber,
      expiresIn: (data['expiresIn'] as num?)?.toInt() ?? 300,
      resendAfter: (data['resendAfter'] as num?)?.toInt() ?? 60,
    );
  }

  static final _e164 = RegExp(r'^\+[1-9]\d{1,14}$');

  final String phoneNumber;
  final int expiresIn;
  final int resendAfter;
}

class PhoneResetRemoteDataSourceImpl implements PhoneResetRemoteDataSource {
  const PhoneResetRemoteDataSourceImpl({required Dio bareClient})
      : _bare = bareClient;

  /// No auth interceptor: the rep is signed out, and a 401 here is an answer,
  /// not a stale token to refresh.
  final Dio _bare;

  @override
  Future<PhoneResetStartModel> startVerification({
    required String phoneNumber,
  }) async {
    final body = {'phoneNumber': phoneNumber.trim()};
    final trace = PasswordResetRequestTrace.start(
      method: 'POST',
      path: ApiEndpoints.startFirebaseResetEndpoint,
      requestBody: body,
    );
    try {
      final res = await _bare.post<DataMap>(
        ApiEndpoints.startFirebaseResetEndpoint,
        data: body,
      );
      final data = ApiEnvelope.fromBody(res.data).data;
      trace.response(status: res.statusCode, body: res.data);
      return PhoneResetStartModel.fromResponse(
        data,
        sentPhoneNumber: body['phoneNumber']!,
      );
    } on DioException catch (e) {
      throw ApiException(trace.dioFailure(e));
    }
  }

  /// The backend verifies the token's signature, issuer, audience and expiry
  /// itself and reads the phone number from its claims. Nothing else is sent:
  /// a phone number from the device would prove nothing.
  @override
  Future<PasswordResetGrantModel> exchangeFirebaseToken(
    String firebaseIdToken,
  ) async {
    final body = {'firebaseIdToken': firebaseIdToken};
    final trace = PasswordResetRequestTrace.start(
      method: 'POST',
      path: ApiEndpoints.verifyFirebaseResetEndpoint,
      requestBody: body,
    );
    try {
      final res = await _bare.post<DataMap>(
        ApiEndpoints.verifyFirebaseResetEndpoint,
        data: body,
      );
      final data = ApiEnvelope.fromBody(res.data).data;
      final grant = PasswordResetGrantModel.fromJson(data);
      if (grant.resetToken.isEmpty) {
        trace.failure(
            status: res.statusCode, type: 'invalid_response', body: res.data);
        throw const ApiException(ApiError(
          code: ApiErrorCodes.unknown,
          detail: 'Phone verified but no reset token returned.',
        ));
      }
      trace.response(status: res.statusCode, body: res.data);
      return grant;
    } on DioException catch (e) {
      throw ApiException(trace.dioFailure(e));
    }
  }
}
