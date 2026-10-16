import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/remote/pricing_remote_data_source.dart';

/// `GET /mobile/pricing/depots/{depotId}` for a demo build.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// Answers the `items[]` rows of the live contract
/// (`docs/feature/order/pricing/api/mobile.md`) from [DemoMaterialBook], so the
/// price on a finder card is the price a quotation line is snapshotted at. A
/// material the book does not know is omitted, exactly as SAP omits a
/// material with no condition record — the repository then reports it as
/// "no price", not as an error.
class DemoPricingRemoteDataSource implements PricingRemoteDataSource {
  DemoPricingRemoteDataSource(this._network, this._book);

  final DemoNetwork _network;
  final DemoMaterialBook _book;

  @override
  Future<List<DataMap>> fetchPrices({
    required String depotId,
    required List<String> materials,
  }) async {
    final wanted = materials
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    if (wanted.isEmpty) return const [];
    await _network.roundTrip();

    final found = await Future.wait(wanted.map(_book.lookup));
    final today = DateTime.now();
    final validFrom = DateTime(today.year, today.month);
    return [
      for (final material in found.whereType<DemoMaterial>())
        {
          'material': material.number,
          'price': material.price,
          'currency': 'USD',
          'conditionUnit': material.unit,
          'pricingUnit': 1,
          'validFrom': _date(validFrom),
          'validTo': '9999-12-31',
          'raw': null,
        },
    ];
  }

  static String _date(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
