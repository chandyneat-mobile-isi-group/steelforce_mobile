import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_code_lookup.dart';
import 'package:steelforce/features/depots/domain/entities/depot_draft.dart';
import 'package:steelforce/features/depots/domain/entities/depot_status.dart';

void main() {
  late DemoNetwork network;
  late DemoDepotRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    source = DemoDepotRemoteDataSource(network, DemoDepotDirectory());
  });

  test('initial sync pages through every seeded depot', () async {
    final first = await source.fetchInitial(page: 1, pageSize: 5);
    final second = await source.fetchInitial(page: 2, pageSize: 5);
    final last = await source.fetchInitial(page: 3, pageSize: 5);

    expect([first.hasMore, second.hasMore, last.hasMore], [true, true, false]);
    final ids = [...first.items, ...second.items, ...last.items]
        .map((d) => d.id)
        .toSet();
    expect(ids, DemoSeed.depots.map((d) => d.id).toSet());
    expect(first.syncTimestamp, isNotNull);
    expect(first.pageSize, 5);
  });

  test('list rows carry the shared identity, parsed by the real mapper',
      () async {
    final page = await source.fetchInitial(page: 1, pageSize: 200);
    final mekong = page.items.firstWhere((d) => d.id == 'demo-depot-001');

    expect(mekong.depotCode, '1000000101');
    expect(mekong.khName, 'ឃ្លាំងដែកមេគង្គ');
    expect(mekong.status, DepotStatus.active);
    expect(mekong.hasCoordinates, isTrue);
    // Detail-only fields stay off the list row, as they do live.
    expect(mekong.contacts, isEmpty);
  });

  test('detail carries contacts and the SAP block; unknown id is a 404',
      () async {
    final depot = await source.fetchById('demo-depot-004');
    expect(depot.contacts, isNotEmpty);
    expect(depot.salesOrg, DemoSeed.salesOrg);

    await expectLater(
      source.fetchById('nope'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'status', 404)
          .having((e) => e.code, 'code', ApiErrorCodes.depotNotFound)),
    );
  });

  test('offline fails as a network error', () async {
    network.setOnline(false);

    await expectLater(
      source.fetchInitial(page: 1, pageSize: 10),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.network)),
    );
  });

  test('a created depot reaches fetchById and the next delta', () async {
    final watermark =
        (await source.fetchInitial(page: 1, pageSize: 200)).syncTimestamp!;

    final created = await source.create(const DepotDraft(
      depotCode: 'FIELD-001',
      shopName: 'Demo Field Shop',
      type: 'Retailer',
      phone: '012 000 999',
      addressLine1: 'No. 1, Street 2004',
      city: 'Phnom Penh',
    ));

    expect(created.status, DepotStatus.draft);
    expect((await source.fetchById(created.id)).shopName, 'Demo Field Shop');

    final delta = await source.fetchDelta(since: watermark);
    expect(delta.upserted.map((d) => d.id), [created.id]);
    expect(delta.deletedIds, isEmpty);
  });

  test('a duplicate code is refused with 409', () async {
    await expectLater(
      source.create(const DepotDraft(
        depotCode: '1000000101',
        shopName: 'Copy',
        type: 'Retailer',
        phone: '012 000 998',
        addressLine1: 'x',
        city: 'Phnom Penh',
      )),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
  });

  test('lookup by code distinguishes found, absent and ERP-unavailable',
      () async {
    final found = await source.lookupByCode('1000000103');
    expect(found, isA<DepotCodeFound>());
    expect((found as DepotCodeFound).depot.id, 'demo-depot-003');

    expect(await source.lookupByCode('1234567890'), isA<DepotCodeAbsent>());
    expect(
      await source.lookupByCode(DemoDepotRemoteDataSource.erpUnavailableCode),
      isA<DepotCodeUnavailable>(),
    );
  });
}
