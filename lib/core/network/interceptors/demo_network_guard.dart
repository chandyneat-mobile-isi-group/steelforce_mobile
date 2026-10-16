import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// The transport of every `dio` client in a demo build: it sends nothing.
///
/// Demo mode replaces each remote data source with a local one, so in a
/// correct demo build no request ever reaches here. This adapter exists for
/// the case where one does — a data source that was missed, or a new one added
/// later without a demo counterpart. Rather than quietly contacting whatever
/// host the build was compiled against, the request fails as a connection
/// error (so the app degrades as it would offline), and debug builds say
/// loudly which call slipped through.
///
/// TODO(release-gate): demo-only. Installed by `AppNetwork` only when
/// `DataSourceMode.useMocks` is true.
class DemoNetworkGuardAdapter implements HttpClientAdapter {
  const DemoNetworkGuardAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    debugPrint('[isi.demo] BLOCKED network request in demo mode: '
        '${options.method} ${options.path} — this call has no demo data '
        'source.');
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Demo mode: network access is disabled.',
    );
  }

  @override
  void close({bool force = false}) {}
}
