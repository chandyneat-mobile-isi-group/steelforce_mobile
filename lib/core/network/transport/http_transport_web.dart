import 'package:dio/dio.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/transport/api_trust_anchors.dart';

/// See `http_transport.dart`. The browser owns TLS; nothing to configure.
void configureHttpTransport(
  Dio dio,
  AppLogger? logger, {
  List<String> trustAnchorsPem = apiTrustAnchorsPem,
}) {}
