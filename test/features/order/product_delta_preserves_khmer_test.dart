import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/data/remote/mock_product_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';

/// A delta rebuilds each changed row from scratch, so any field the rebuild
/// forgets is **erased**, not left alone.
///
/// `ProductModel` defaults `nameKh`, `color` and `specification`, so omitting
/// them compiled cleanly and silently wiped the Khmer name off every row a
/// delta touched (~5% per sync). A correctly-synced bilingual catalog therefore
/// decayed back towards English-only the longer the app ran — visible only to
/// someone reading Khmer, days after the change that caused it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a delta sync preserves the Khmer name on every row it rewrites',
      () async {
    final remote = MockProductRemoteDataSource();
    final scope = SyncScope(
      repId: 'rep-1',
      territory: 'Phnom Penh',
      warehouseCodes: const ['WH-PP01', 'WH-PP02', 'WH-PP03'],
      businessUnit: 'ISI Steel',
      pricingGroup: 'STANDARD',
    );

    // Seed the in-memory catalog the same way a real sync would.
    final initial =
        await remote.fetchInitial(scope: scope, page: 0, pageSize: 500);
    expect(initial.items, isNotEmpty);

    final before = {
      for (final p in initial.items)
        if (p.nameKh.trim().isNotEmpty) p.id: p.nameKh,
    };
    expect(before, isNotEmpty,
        reason: 'the fixture must carry Khmer names, or this test proves '
            'nothing — regenerate assets/mock/products.json');

    final delta =
        await remote.fetchDelta(scope: scope, since: DateTime.utc(2026, 7, 1));
    expect(delta.upserted, isNotEmpty);

    final wiped = delta.upserted
        .where((p) => before.containsKey(p.id) && p.nameKh.trim().isEmpty)
        .toList();

    expect(wiped, isEmpty,
        reason: '${wiped.length} rows came back from the delta with their '
            'Khmer name blanked — the rebuild is dropping nameKh');

    // And the value is the same one, not merely non-empty.
    for (final p in delta.upserted) {
      if (before.containsKey(p.id)) expect(p.nameKh, before[p.id]);
    }
  });
}
