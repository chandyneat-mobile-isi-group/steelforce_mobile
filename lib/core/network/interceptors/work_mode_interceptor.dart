import 'package:dio/dio.dart';
import 'package:steelforce/core/network/work_mode/work_mode_service.dart';

/// The error inside a request refused because the rep chose
/// [WorkMode.offline]. Raised before any byte leaves the device, so it is a
/// proven "never sent" (`request_reach.dart`): a write refused here is safe to
/// queue and resend.
class WorkModeBlocked implements Exception {
  const WorkModeBlocked();

  @override
  String toString() => 'WorkModeBlocked: offline mode is on';
}

/// Refuses API requests while the rep works in [WorkMode.offline].
///
/// The guarantee behind the mode: a screen or data source that does not check
/// connectivity still cannot reach the server, and it fails *instantly* with
/// the same `connectionError` a dead network produces — so every existing
/// offline path (save locally, queue, show the saved copy) handles it with no
/// new branch, and nothing waits out a timeout on a weak signal.
///
/// Session endpoints (`/auth/…`) pass: signing out, the profile check and the
/// token refresh are not business data, and blocking them would strand the
/// rep's session rather than protect their work.
class WorkModeInterceptor extends Interceptor {
  const WorkModeInterceptor(this._workMode);

  final WorkModeService _workMode;

  static bool isSessionPath(String path) => path.contains('/auth/');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_workMode.isOffline || isSessionPath(options.path)) {
      handler.next(options);
      return;
    }
    handler.reject(
      DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: const WorkModeBlocked(),
        message: 'Offline mode is on',
      ),
    );
  }
}
