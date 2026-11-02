import 'package:dio/dio.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/interceptors/api_headers_interceptor.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';

/// The lifecycle of one `POST /mobile/plans/{id}/check-in`, through the app
/// logger (`isi.debug` / `isi.info` / `isi.error`). Filter on `checkIn.`.
///
/// Records only presence, counts, codes and rounded numbers: never the
/// coordinates, a photo's name or bytes, the notes or reason text, or any
/// token. The logger drops debug and info in release builds and redacts
/// whatever slips through.
class PlanCheckInLog {
  const PlanCheckInLog(this._logger);

  final AppLogger? _logger;

  void started(PlanCheckInRequest r, String path) =>
      _logger?.debug('checkIn.request.started', fields: {
        'method': 'POST',
        'path': path,
        'planId': r.planId,
        'checkInId': r.checkInId,
        'contentType': 'multipart/form-data',
        'hasPosition': r.latitude.isFinite && r.longitude.isFinite,
        'accuracyMeters': r.accuracyMeters?.round(),
        'photoCount': r.photoPaths.length,
        'reasonCode': r.reason?.apiValue,
        'hasReasonDescription': r.reasonDescription?.trim().isNotEmpty ?? false,
        'hasNotes': r.notes?.trim().isNotEmpty ?? false,
      });

  void succeeded(
    PlanCheckInRequest r,
    Response<Object?> res,
    PlanCheckInResult result,
    Duration took,
  ) =>
      _logger?.info('checkIn.request.succeeded', fields: {
        'planId': r.planId,
        'checkInId': result.checkInId,
        'status': res.statusCode,
        'durationMs': took.inMilliseconds,
        'zone': result.zone,
        'distanceMeters': result.distanceMeters?.round(),
        'correlationId': _correlationId(res.requestOptions),
      });

  void failed(
    PlanCheckInRequest r,
    DioException e,
    ApiError error,
    Duration took,
  ) =>
      _logger?.error('checkIn.request.failed',
          error: error,
          stackTrace: e.stackTrace,
          fields: {
            'planId': r.planId,
            'checkInId': r.checkInId,
            'category': category(e),
            'status': error.statusCode,
            'errorCode': error.code,
            'serverCode': error.serverCode,
            'message': _sanitize(error.message),
            'retryAfterSeconds': error.retryAfter?.inSeconds,
            'durationMs': took.inMilliseconds,
            'correlationId':
                error.correlationId ?? _correlationId(e.requestOptions),
          });

  /// A 2xx whose body did not match the contract — the check-in may well
  /// have landed, so this is not reported as a refusal.
  void unreadable(PlanCheckInRequest r, Object error, Duration took) =>
      _logger?.error('checkIn.response.unreadable', error: error, fields: {
        'planId': r.planId,
        'checkInId': r.checkInId,
        'durationMs': took.inMilliseconds,
      });

  /// What went wrong, in the terms a support person searches for.
  static String category(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'timeout';
      case DioExceptionType.connectionError:
        return 'network';
      default:
    }
    final status = e.response?.statusCode;
    if (status == null) return 'unknown';
    return switch (status) {
      400 || 413 || 422 => 'validation',
      401 => 'authentication',
      403 => 'authorization',
      404 => 'not_found',
      409 => 'conflict',
      429 => 'rate_limited',
      >= 500 => 'server_error',
      _ => 'unknown',
    };
  }

  static String? _correlationId(RequestOptions options) {
    final id = options.headers[ApiHeadersInterceptor.correlationHeader];
    return id is String ? id : null;
  }

  /// The server's message, one line, capped. It is the server's wording
  /// about the request, never a field the rep typed.
  static String? _sanitize(String? message) {
    final text = message?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text == null || text.isEmpty) return null;
    return text.length <= 160 ? text : '${text.substring(0, 157)}...';
  }
}
