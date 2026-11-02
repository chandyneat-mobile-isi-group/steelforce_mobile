import 'package:dio/dio.dart';
import 'package:steelforce/core/logging/password_reset_request_trace.dart';
import 'package:steelforce/core/network/api/api_error.dart';

extension PasswordResetTraceFailure on PasswordResetRequestTrace {
  /// Records a failed backend call with the server's answer, and returns the
  /// mapped error for the caller to throw.
  ApiError dioFailure(DioException e) {
    final error = ApiError.fromDio(e);
    failure(
      status: e.response?.statusCode,
      type: e.type.name,
      errorCode: error.code,
      serverCode: error.serverCode,
      message: error.detail ?? error.message,
      correlationId: error.correlationId,
      fieldErrors: error.fieldErrors.keys,
      body: e.response?.data,
    );
    return error;
  }
}
