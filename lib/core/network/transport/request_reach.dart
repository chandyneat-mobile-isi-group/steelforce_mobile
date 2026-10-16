/// Whether a failed request provably never reached the server.
///
/// Both sides expose `bool neverReachedServer(Object? error)`, taking the
/// `DioException.error` of a `connectionError`. The distinction decides whether
/// a non-idempotent write may be resent automatically:
///
/// * **Native** — only a `SocketException` (connection refused, no route, DNS
///   failure) proves nothing was delivered. dio *also* reports
///   `HttpException: Connection closed before full header was received` as
///   `connectionError`, and that one is raised after the whole body was sent:
///   the server may well have acted on it.
/// * **Web** — the browser reports every XHR failure the same way, so nothing
///   can be proved and the answer is always false.
///
/// A conditional export so `dart:io` stays out of the web build.
library;

export 'request_reach_web.dart'
    if (dart.library.io) 'request_reach_native.dart';
