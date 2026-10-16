import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/interceptors/demo_network_guard.dart';

void main() {
  group('DemoNetwork', () {
    test('roundTrip completes while online', () async {
      await DemoNetwork().roundTrip();
    });

    test('roundTrip fails as a network error while offline', () async {
      final network = DemoNetwork(online: false);
      await expectLater(
        network.roundTrip(),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCodes.network)),
      );
    });

    test('toggle flips the state', () {
      final network = DemoNetwork()..toggle();
      expect(network.isOnline, isFalse);
      network.toggle();
      expect(network.isOnline, isTrue);
    });
  });

  group('DemoConnectivity', () {
    test('reports the radio from the demo switch and emits changes', () async {
      final network = DemoNetwork();
      final connectivity = DemoConnectivity(network);

      expect(await connectivity.checkConnectivity(), [ConnectivityResult.wifi]);

      final next = connectivity.onConnectivityChanged.first;
      network.setOnline(false);
      expect(await next, [ConnectivityResult.none]);
    });
  });

  test('DemoReachabilityProbe follows the switch', () async {
    final network = DemoNetwork();
    final probe = DemoReachabilityProbe(network);
    expect(await probe.isReachable(), isTrue);
    network.setOnline(false);
    expect(await probe.isReachable(), isFalse);
  });

  test('DemoNetworkGuardAdapter refuses every request as a connection error',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://unreachable.invalid'))
      ..httpClientAdapter = const DemoNetworkGuardAdapter();

    await expectLater(
      dio.get<void>('/api/v1/anything'),
      throwsA(isA<DioException>()
          .having((e) => e.type, 'type', DioExceptionType.connectionError)),
    );
  });

  test('DemoSeed depots have unique ids and codes', () {
    final ids = DemoSeed.depots.map((d) => d.id).toSet();
    final codes = DemoSeed.depots.map((d) => d.code).toSet();
    expect(ids.length, DemoSeed.depots.length);
    expect(codes.length, DemoSeed.depots.length);
    expect(DemoSeed.depotById(DemoSeed.depots.first.code),
        same(DemoSeed.depots.first));
  });
}
