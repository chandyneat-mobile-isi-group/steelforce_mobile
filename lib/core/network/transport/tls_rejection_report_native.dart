import 'dart:io';

import 'package:steelforce/core/logging/app_logger.dart';

/// Records the presented certificate and **rejects it**. Installed as the
/// `badCertificateCallback` by `configureHttpTransport`
/// (`http_transport_native.dart`); see `tls_rejection_report.dart`. Public for
/// tests.
///
/// Only public certificate fields are logged — subject, issuer, validity —
/// never anything from the request.
bool rejectAndReport(
  X509Certificate cert,
  String host,
  int port,
  AppLogger logger,
) {
  logger.error('api.tls.rejected', fields: {
    'host': host,
    'port': port,
    'subject': cert.subject,
    'issuer': cert.issuer,
    'selfSigned': cert.subject == cert.issuer,
    'validFrom': cert.startValidity.toUtc().toIso8601String(),
    'validTo': cert.endValidity.toUtc().toIso8601String(),
  });
  return false;
}
