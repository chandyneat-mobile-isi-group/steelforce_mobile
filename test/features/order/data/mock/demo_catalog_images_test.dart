import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/features/order/data/remote/mock_product_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';

/// The bundled catalog points every row at an internet placeholder service.
/// A demo build must make no request at all, so it syncs the rows without
/// image URLs; a live build keeps them unchanged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final scope = SyncScope(
    repId: 'rep-1',
    territory: 'Phnom Penh',
    warehouseCodes: const ['WH-PP01'],
    businessUnit: 'ISI Steel',
    pricingGroup: 'STANDARD',
  );

  test('a demo catalog carries no remote image URL, through a delta too',
      () async {
    final remote = MockProductRemoteDataSource(remoteImages: false);
    final initial =
        await remote.fetchInitial(scope: scope, page: 0, pageSize: 200);
    expect(initial.items, isNotEmpty);
    expect(initial.items.every((p) => p.imageUrl.isEmpty), isTrue);

    final delta =
        await remote.fetchDelta(scope: scope, since: DateTime.utc(2026, 9, 1));
    expect(delta.upserted.every((p) => p.imageUrl.isEmpty), isTrue);
  });

  test('the default (live) catalog keeps its image URLs', () async {
    final initial = await MockProductRemoteDataSource()
        .fetchInitial(scope: scope, page: 0, pageSize: 200);
    expect(initial.items.any((p) => p.imageUrl.isNotEmpty), isTrue);
  });
}
