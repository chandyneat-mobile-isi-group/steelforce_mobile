import 'package:dio/dio.dart';
import 'package:steelforce/core/config/app_config.dart';
import 'package:steelforce/core/config/data_source_mode.dart';
import 'package:steelforce/core/network/api/api_defaults.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/interceptors/api_headers_interceptor.dart';
import 'package:steelforce/core/network/interceptors/auth_interceptor.dart';
import 'package:steelforce/core/network/interceptors/api_log_interceptor.dart';
import 'package:steelforce/core/network/interceptors/demo_network_guard.dart';

/// Factory for the app's Dio clients. Keeping construction here means the
/// timeout / header policy lives in exactly one place.
class AppNetwork {
  AppNetwork._();

  static BaseOptions get _baseOptions => BaseOptions(
        // Environment-driven, never a literal: the target gateway comes from
        // the `.env` compiled in at build time, so a QA/staging build is a
        // different `.env` rather than a different source tree.
        // Via [AppConfig], not [Env] directly, so a
        // `--dart-define=API_BASE_URL=…` launch override reaches every client.
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: ApiDefaults.connectTimeout,
        receiveTimeout: ApiDefaults.receiveTimeout,
        responseType: ResponseType.json,
        headers: const {'Accept': 'application/json'},
      );

  /// Bare client with no auth interceptor. Used for the refresh flow and
  /// public endpoints (login, forgot-password, reset-password).
  ///
  /// It still carries [ApiHeadersInterceptor]: `Accept-Language` decides
  /// whether a rejected login is explained in Khmer or English, and a login
  /// that fails is exactly the request support most wants a correlation id
  /// for.
  ///
  /// [logger] is optional so the refresh client can be built without one;
  /// when supplied, every call through this client is traced.
  static Dio createBareClient({AppLogger? logger}) =>
      _guarded(Dio(_baseOptions))
        ..interceptors.addAll([
          const ApiHeadersInterceptor(),
          if (logger != null) ApiLogInterceptor(logger),
        ]);

  /// Authenticated client used by feature data sources. Auto-attaches and
  /// refreshes the bearer token.
  ///
  /// The refresh client is deliberately a *bare* client: replaying through a
  /// client that carries [AuthInterceptor] would recurse on the next 401.
  static Dio createAuthedClient({
    required TokenStore tokenStore,
    required DeviceIdReader deviceId,
    AppLogger? logger,
    void Function()? onSessionExpired,
  }) {
    return _guarded(Dio(_baseOptions))
      ..interceptors.addAll([
        const ApiHeadersInterceptor(),
        // Ahead of [AuthInterceptor] so a 401 is logged as it happens, before
        // the refresh-and-replay swallows it. Otherwise a successfully
        // recovered request looks like it never failed, and the refresh path —
        // the part most likely to be misbehaving — leaves no trace at all.
        if (logger != null) ApiLogInterceptor(logger),
        AuthInterceptor(
          tokenStore: tokenStore,
          refreshClient: createBareClient(logger: logger),
          deviceId: deviceId,
          onSessionExpired: onSessionExpired,
        ),
      ]);
  }

  /// A demo build sends nothing: every client gets a transport that refuses
  /// the request, so a data source without a demo counterpart fails as offline
  /// instead of contacting a real host.
  static Dio _guarded(Dio dio) {
    if (DataSourceMode.useMocks) {
      dio.httpClientAdapter = const DemoNetworkGuardAdapter();
    }
    return dio;
  }
}
