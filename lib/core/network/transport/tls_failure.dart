/// Whether a failed request died in the TLS handshake.
///
/// Both sides expose `bool isTlsFailure(Object? error)`, taking the
/// `DioException.error` of a request that got no response.
///
/// * **Native** — dio surfaces a failed handshake as `DioExceptionType.unknown`
///   wrapping a `HandshakeException` (a `TlsException`). It is not a
///   `connectionError`, so without this it reads as `Client.Unknown`. The usual
///   causes on a phone are a wrong clock (the certificate is "not yet valid" or
///   "expired"), a TLS-intercepting network, or a missing root certificate.
/// * **Web** — the browser hides the cause of every failed request, so nothing
///   can be identified and the answer is always false.
///
/// A conditional export so `dart:io` stays out of the web build.
library;

export 'tls_failure_web.dart' if (dart.library.io) 'tls_failure_native.dart';
