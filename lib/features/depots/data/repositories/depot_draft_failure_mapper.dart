import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';

/// Turns an [ApiError] from a depot-draft route into a [Failure] whose message
/// is a translation key — the server's own text is never the message, so a
/// Khmer-speaking rep never reads an English server sentence or a trace.
abstract final class DepotDraftFailureMapper {
  static const _prefix = 'depots.draft.error';

  static Failure map(ApiError error) {
    if (error.code == ApiErrorCodes.network) return const NetworkFailure();
    if (error.code == ApiErrorCodes.secureConnection) {
      return const ServerUnreachableFailure();
    }
    // A 401 here means the interceptor's one refresh already failed and the
    // session is ending; this only has to say so.
    if (error.isUnauthenticated) {
      return AuthenticationFailure(
        message: '$_prefix.session',
        statusCode: error.statusCode,
        code: error.serverCode ?? error.code,
      );
    }

    final status = error.statusCode;
    final code = error.serverCode ?? error.code;
    final key = _keyFor(code, status);
    if (key == null) {
      return ServerFailure(
        message: '$_prefix.server',
        statusCode: status,
        code: code,
        retryAfter: error.retryAfter,
      );
    }
    return DepotDraftRejectedFailure(
      message: '$_prefix.$key',
      code: code,
      statusCode: status,
      fieldErrors: key == 'validation' ? fieldErrorsOf(error) : const {},
      retryAfter: error.retryAfter,
      supportReference: error.correlationId,
    );
  }

  /// The refusals the contract names. Null for a 5xx or anything unknown,
  /// which stays a retryable [ServerFailure].
  static String? _keyFor(String code, int? status) => switch ((code, status)) {
        ('DEPOT_ATTACHMENT_INVALID_FILE', _) => 'invalid_file',
        ('DEPOT_ATTACHMENT_LIMIT_REACHED', _) => 'limit_reached',
        ('DEPOT_DRAFT_ID_IN_USE', _) => 'id_in_use',
        ('DEPOT_DRAFT_NOT_FOUND', _) || (_, 404) => 'not_found',
        (_, 403) => 'forbidden',
        (_, 413) => 'too_large',
        (_, 429) => 'rate_limited',
        (_, 400) => 'validation',
        (_, 409) => 'conflict',
        _ => null,
      };

  /// Field errors from whichever place the body put them. This backend's
  /// wrapped envelope uses `error.details` (`{"salesAreas[0].salesOrg":
  /// ["…"]}`), which the shared parser keeps raw rather than in
  /// [ApiError.fieldErrors].
  static Map<String, List<String>> fieldErrorsOf(ApiError error) {
    if (error.fieldErrors.isNotEmpty) return error.fieldErrors;
    final details = error.details;
    if (details == null) return const {};
    return {
      for (final entry in details.entries)
        entry.key: switch (entry.value) {
          final List<dynamic> list => [for (final m in list) '$m'],
          null => const <String>[],
          final Object value => ['$value'],
        },
    };
  }
}
