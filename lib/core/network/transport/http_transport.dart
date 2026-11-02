/// Configures the TLS transport of an app API client.
///
/// Both sides expose the same `configureHttpTransport` function.
///
/// * **Native** — installs dio's default `HttpClient`, plus:
///   * certificate pinning when [apiTrustAnchorsPem] is non-empty — only
///     chains ending at one of those CAs complete the handshake;
///   * a reporting `badCertificateCallback` when a logger is given, naming the
///     certificate that was rejected (see `tls_rejection_report.dart`). It
///     always returns false: reporting never turns into trusting.
/// * **Web** — the browser owns TLS and exposes neither hook; a no-op.
///
/// A conditional export so `dart:io` stays out of the web build.
library;

export 'http_transport_web.dart'
    if (dart.library.io) 'http_transport_native.dart';
