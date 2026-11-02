part of 'visit_plan_repository_impl.dart';

/// A 401 reaching here means the interceptor's one refresh already failed;
/// it ends the session itself, so this only has to say so. A 403 is never a
/// sign-out — the account is simply not a sales employee.
Failure _planFailure(ApiError error,
    {String Function(ApiError error)? messageFor}) {
  if (error.code == ApiErrorCodes.network) return const NetworkFailure();
  if (error.isUnauthenticated) {
    return AuthenticationFailure(
      message: 'my_visits.plans.error.session',
      statusCode: error.statusCode,
      code: error.code,
    );
  }
  if (error.isPermissionDenied) {
    return ServerFailure(
      message: 'my_visits.plans.error.forbidden',
      statusCode: error.statusCode,
      code: error.serverCode ?? error.code,
    );
  }
  if (messageFor != null) {
    return ServerFailure(
      message: messageFor(error),
      statusCode: error.statusCode,
      code: error.serverCode ?? error.code,
      retryAfter: error.retryAfter,
    );
  }
  return ServerFailure(
    message: error.message ?? 'my_visits.plans.error.load_failed',
    statusCode: error.statusCode,
    code: error.serverCode ?? error.code,
    retryAfter: error.retryAfter,
  );
}
