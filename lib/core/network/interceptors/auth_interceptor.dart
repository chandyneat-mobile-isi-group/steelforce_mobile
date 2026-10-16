import 'dart:async';

import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';

/// The subset of token operations the interceptor needs. Implemented by the
/// auth local data source — declared here as an interface to avoid a
/// circular dependency between the network layer and the auth feature.
abstract interface class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();

  /// Persists a rotated pair.
  ///
  /// Implementations **must write the refresh token before the access token**.
  /// Refresh tokens are single-use: the moment the new access token is in
  /// play the old refresh token is dead, so a crash between the two writes
  /// with the order reversed loses the session entirely.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clear();
}

/// Supplies the per-installation `deviceId` that must accompany a refresh so
/// the rotation stays attached to the session opened at sign-in.
typedef DeviceIdReader = Future<String> Function();

/// Attaches the bearer token to every request and transparently refreshes it
/// exactly once on a 401, then replays the original request.
///
/// Three rules this encodes, each of which is a bug if broken:
///
///  * **Refresh reactively, on 401 — never on a timer.** A timer keeps waking
///    a phone asleep in a pocket and drifts against the server clock.
///  * **Retry exactly once.** A second 401 after a successful refresh means
///    the problem is authorisation, not expiry, and retrying again just loops.
///  * **403 is not 401.** A 403 means this user may never do this; signing
///    them out and showing a login screen would be wrong and confusing. Only
///    a 401 is handled here at all.
///  * **Only a rejected grant ends the session.** A 400/401 from the refresh
///    endpoint signs the rep out; a transport failure (offline, timeout, 5xx)
///    keeps the session and fails the request as a network error, so the
///    offline-first flows carry on and the next 401 online tries again.
///
/// [QueuedInterceptor] serialises handler execution, and [_refreshCompleter]
/// coalesces concurrent 401s into a single refresh call. Without that, two
/// screens hitting 401 at once would both refresh, the second would present an
/// already-rotated token, and the server's reuse detection would read that as
/// token theft and revoke the whole session.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStore tokenStore,
    required Dio refreshClient,
    required DeviceIdReader deviceId,
    this.onSessionExpired,
  })  : _store = tokenStore,
        _refreshClient = refreshClient,
        _deviceId = deviceId;

  final TokenStore _store;

  /// A bare Dio WITHOUT this interceptor — used for the refresh call and
  /// for replaying the original request, so we never recurse.
  final Dio _refreshClient;

  final DeviceIdReader _deviceId;

  /// Invoked once when the refresh token is gone or **definitively rejected**
  /// by the server and the session is unrecoverable. The app uses this to drop
  /// to the login screen; without it the user would sit on an authenticated
  /// screen that silently fails.
  ///
  /// Never invoked for a transport failure (offline, timeout, 5xx): a rep in a
  /// steel yard with no signal must keep their session and their queued work.
  final void Function()? onSessionExpired;

  Completer<_RefreshOutcome>? _refreshCompleter;

  static const _retriedFlag = '__auth_retried__';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _store.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRefresh(err)) return handler.next(err);

    // [QueuedInterceptor] runs these handlers one at a time, so a request that
    // 401'd alongside others reaches here only after an earlier handler has
    // already refreshed (or ended the session). Reuse that outcome instead of
    // spending another single-use refresh token.
    final current = await _readAccessTokenSafely();
    final sent = _bearerOf(err.requestOptions);
    final _RefreshOutcome outcome;
    if (current != null && current.isNotEmpty && current != sent) {
      outcome = _Refreshed(current);
    } else if ((current == null || current.isEmpty) &&
        !await _hasRefreshToken()) {
      // The session was already ended by an earlier queued handler (or never
      // existed). Fail with the original 401 without re-notifying.
      return handler.next(err);
    } else {
      outcome = await _refreshToken();
    }

    switch (outcome) {
      case _Refreshed(:final accessToken):
        final options = err.requestOptions
          ..headers['Authorization'] = 'Bearer $accessToken'
          ..extra[_retriedFlag] = true;
        try {
          final response = await _refreshClient.fetch<dynamic>(options);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }

      case _Rejected():
        // Definitive: the server refused the grant, or there is nothing to
        // refresh with. Only this path ends the session.
        await _store.clear();
        onSessionExpired?.call();
        return handler.next(err);

      case _Unavailable(:final cause):
        // Transport failure. Keep the session; surface a network error so the
        // caller degrades to local data exactly as it would offline.
        return handler.next(
          DioException(
            requestOptions: err.requestOptions,
            type: DioExceptionType.connectionError,
            error: cause,
            message: 'Token refresh unavailable; session kept.',
          ),
        );
    }
  }

  bool _shouldRefresh(DioException err) {
    // Only a 401 says "your token is stale". A 403 is a permission verdict and
    // a 400 from an OAuth endpoint is a rejected grant — refreshing on either
    // would burn a rotation and, on the 400 path, could spend one of the five
    // login attempts that lock the account.
    if (err.response?.statusCode != 401) return false;
    if (err.requestOptions.extra[_retriedFlag] == true) return false;

    // A 401 from /auth/login or /auth/refresh is the answer, not a symptom.
    final path = err.requestOptions.path;
    return !ApiEndpoints.authRoutes.any(path.endsWith);
  }

  static String? _bearerOf(RequestOptions options) {
    final header = options.headers['Authorization'];
    if (header is! String || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  Future<String?> _readAccessTokenSafely() async {
    try {
      return await _store.readAccessToken();
    } catch (_) {
      // Unreadable store: fall through to a normal refresh attempt, whose own
      // failure handling decides the outcome.
      return null;
    }
  }

  Future<bool> _hasRefreshToken() async {
    try {
      final refresh = await _store.readRefreshToken();
      return refresh != null && refresh.isNotEmpty;
    } catch (_) {
      // Cannot tell — assume a session exists so the refresh path (which
      // treats a storage error as transient) runs rather than silently failing.
      return true;
    }
  }

  /// Single-flight refresh: concurrent callers share one outcome.
  Future<_RefreshOutcome> _refreshToken() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<_RefreshOutcome>();
    _refreshCompleter = completer;

    _performRefresh()
        .then(completer.complete)
        .catchError((Object e) => completer.complete(_classify(e)))
        .whenComplete(() => _refreshCompleter = null);

    return completer.future;
  }

  /// Only a 400/401 from the refresh endpoint is the server saying "this grant
  /// is dead" (`invalid_grant`, `docs/feature/authentication/api.md` §2.2).
  /// Everything else — no connectivity, a timeout, a 5xx, a captive portal's
  /// HTML, a storage hiccup — says nothing about the session's validity.
  static _RefreshOutcome _classify(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 400 || status == 401) return const _Rejected();
    }
    return _Unavailable(error);
  }

  Future<_RefreshOutcome> _performRefresh() async {
    final refresh = await _store.readRefreshToken();
    if (refresh == null || refresh.isEmpty) return const _Rejected();

    // camelCase body and the same deviceId supplied at sign-in — the server
    // keys the rotation to the session that id opened.
    final res = await _refreshClient.post<Map<String, dynamic>>(
      ApiEndpoints.refreshEndpoint,
      data: {'refreshToken': refresh, 'deviceId': await _deviceId()},
    );

    // `/mobile/auth/refresh-token` answers camelCase inside the standard
    // `{data: …}` envelope. The raw OAuth shape (snake_case, unwrapped) is
    // still read, so an older gateway keeps working.
    final body = res.data ?? const <String, dynamic>{};
    final data = body['data'] is Map
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;
    final access = (data['accessToken'] ?? data['access_token']) as String?;
    // A 2xx without a token is not a server verdict on the grant (the contract
    // rejects with 400/401) — most likely an intermediary. Keep the session.
    if (access == null || access.isEmpty) {
      return _Unavailable(StateError('Refresh response carried no token.'));
    }

    // saveTokens persists the refresh half first; see [TokenStore].
    // The mobile route always rotates; keeping the old token is only a
    // fallback for a response that omits it.
    final newRefresh =
        (data['refreshToken'] ?? data['refresh_token']) as String? ?? refresh;
    await _store.saveTokens(accessToken: access, refreshToken: newRefresh);
    return _Refreshed(access);
  }
}

/// Result of one refresh attempt, shared by every request queued behind it.
sealed class _RefreshOutcome {
  const _RefreshOutcome();
}

/// A new access token is stored; replay with it.
final class _Refreshed extends _RefreshOutcome {
  const _Refreshed(this.accessToken);
  final String accessToken;
}

/// The server definitively rejected the refresh token (or none is stored).
/// The session is over.
final class _Rejected extends _RefreshOutcome {
  const _Rejected();
}

/// The refresh could not be completed for a reason unrelated to the grant's
/// validity. The session is kept.
final class _Unavailable extends _RefreshOutcome {
  const _Unavailable(this.cause);
  final Object cause;
}
