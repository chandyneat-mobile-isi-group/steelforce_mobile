import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/connectivity/connectivity_service.dart';

/// An adapter that never answers — a host blackholing SYN packets, which is
/// what a dead tunnel or a drop-rather-than-refuse firewall looks like.
class _BlackholeAdapter implements HttpClientAdapter {
  final _never = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? stream,
          Future<void>? cancelFuture) =>
      _never.future;

  @override
  void close({bool force = false}) {}
}

/// The regression: bootstrap awaited this probe before `runApp`, and the probe
/// had no `connectTimeout` — only `sendTimeout` / `receiveTimeout`, which never
/// start counting because they require a connection that never happens. The app
/// rendered no first frame at all and sat on the launch screen.
void main() {
  const logger = ConsoleAppLogger(verbose: false);

  test('a connect timeout is set, since Options cannot carry one', () {
    // `connectTimeout` lives on BaseOptions, not on per-request Options. That
    // asymmetry is how it came to be missing, so pin it where it belongs.
    final dio = Dio();
    HttpReachabilityProbe(
      dio: dio,
      logger: logger,
      timeout: const Duration(milliseconds: 200),
    );

    expect(dio.options.connectTimeout, const Duration(milliseconds: 200));
  });

  test('a caller-supplied connect timeout is respected', () {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));
    HttpReachabilityProbe(dio: dio, logger: logger);

    expect(dio.options.connectTimeout, const Duration(seconds: 30),
        reason: 'a pre-configured client keeps its own value');
  });

  test('an unreachable host resolves to offline instead of hanging', () async {
    final dio = Dio()..httpClientAdapter = _BlackholeAdapter();
    final probe = HttpReachabilityProbe(
      dio: dio,
      logger: logger,
      timeout: const Duration(milliseconds: 200),
    );

    // The assertion is that this completes at all. Before the fix it never did,
    // and `main()` was awaiting it.
    final reachable = await probe.isReachable().timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              fail('the probe hung — boot would never reach runApp'),
        );

    expect(reachable, isFalse, reason: 'unreachable is offline, not an error');
  });
}
