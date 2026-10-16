import 'package:dio/dio.dart';
import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/utils/uuid.dart';

/// Attaches headers every request must carry.
///
/// Both are cheap and both are load-bearing:
///
///  * `Accept-Language` is what makes the server return `shopName`,
///    `statusDisplay` and every `message` already translated — the client
///    never picks between language columns.
///  * `X-Correlation-Id` makes a request traceable end to end. Quote the id
///    from a bug report and support can find the exact call in the logs.
class ApiHeadersInterceptor extends Interceptor {
  const ApiHeadersInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Read live rather than at construction: the language can change mid
    // session and the next request must follow it.
    options.headers['Accept-Language'] = ActiveLanguage.acceptLanguageTag;
    options.headers['X-Correlation-Id'] = Uuid.v4();
    handler.next(options);
  }
}
