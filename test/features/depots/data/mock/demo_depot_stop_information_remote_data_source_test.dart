import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_stop_information_remote_data_source.dart';

void main() {
  late DemoNetwork network;
  late DemoDepotStopInformationRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    source =
        DemoDepotStopInformationRemoteDataSource(network, DemoDepotDirectory());
  });

  test('a seeded depot parses, by id or by code', () async {
    final byId = await source.fetch('demo-depot-001');
    final byCode = await source.fetch('1000000101');

    expect(byId.outlet.code, '1000000101');
    expect(byId.outlet.nameKh, isNotNull);
    expect(byId.outlet.contact, 'Sok Dara');
    expect(byId.credit.paymentTermDisplay, '30 days due net');
    expect(byId.credit.availableCredit.amount, 50000 - 18250);
    expect(byCode, byId);
  });

  test('an unknown depot is a 404', () async {
    await expectLater(
      source.fetch('nope'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('offline fails as a network error', () async {
    network.setOnline(false);

    await expectLater(
      source.fetch('demo-depot-001'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.network)),
    );
  });
}
