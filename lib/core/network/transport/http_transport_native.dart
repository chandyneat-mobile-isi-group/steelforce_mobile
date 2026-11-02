import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/transport/api_trust_anchors.dart';
import 'package:steelforce/core/network/transport/tls_rejection_report_native.dart';

/// See `http_transport.dart`.
void configureHttpTransport(
  Dio dio,
  AppLogger? logger, {
  List<String> trustAnchorsPem = apiTrustAnchorsPem,
}) {
  if (logger == null && trustAnchorsPem.isEmpty) return;

  // Built once: parsing the anchors per connection is wasted work, and a
  // malformed PEM should fail here, at client construction, not mid-request.
  final context =
      trustAnchorsPem.isEmpty ? null : pinnedSecurityContext(trustAnchorsPem);

  dio.httpClientAdapter = IOHttpClientAdapter(
    // Dio's own default client (`IOHttpClientAdapter._createHttpClient`) plus
    // the pinned context and the reporting callback.
    createHttpClient: () {
      final client = HttpClient(context: context)
        ..idleTimeout = const Duration(seconds: 3);
      if (logger != null) {
        client.badCertificateCallback =
            (cert, host, port) => rejectAndReport(cert, host, port, logger);
      }
      return client;
    },
  );
}

/// A context that trusts **only** [pems] — not the platform's root store.
/// Public for tests.
SecurityContext pinnedSecurityContext(List<String> pems) {
  final context = SecurityContext(withTrustedRoots: false);
  for (final pem in pems) {
    context.setTrustedCertificatesBytes(utf8.encode(pem));
  }
  return context;
}
