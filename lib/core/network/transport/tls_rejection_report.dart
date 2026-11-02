/// Names the certificate a client was shown when TLS verification fails.
///
/// The native side exposes `rejectAndReport`, the `badCertificateCallback`
/// that `configureHttpTransport` installs. **It never weakens verification** — a certificate the platform
/// rejects is still rejected; this only records which one it was.
///
/// Why it exists: a failed handshake reaches Dart as `HandshakeException:
/// CERTIFICATE_VERIFY_FAILED: self signed certificate`, which says *that* the
/// certificate was bad but not *whose* it was. On 2026-10-19 that whose was
/// `CN=Fortiguard SDNS Blocked Page` — an office FortiGate DNS filter
/// answering for the API host — and naming it is the difference between
/// chasing the API's certificate and calling the network administrator.
///
/// * **Native** — a reporting `badCertificateCallback` that always returns
///   false.
/// * **Web** — the browser owns TLS and reveals nothing; nothing to export.
///
/// A conditional export so `dart:io` stays out of the web build.
library;

export 'tls_rejection_report_web.dart'
    if (dart.library.io) 'tls_rejection_report_native.dart';
