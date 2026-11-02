import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/material_availability.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/repositories/material_availability_repository.dart';
import 'package:steelforce/features/order/domain/repositories/pricing_repository.dart';
import 'package:steelforce/features/order/practice/order_practice_data.dart';

/// Depot prices during practice: the demo catalog's figures
/// ([OrderPracticeData.priceFor]), never a call to `/pricing/depots/{id}` —
/// the demo depot does not exist on the backend.
///
/// Keeps the real repository's one settled answer: a walk-in with no depot
/// gets `unavailable`, because there is nobody to price for. Once
/// [PracticeWorld.isClosed] every call goes to [_real].
class PracticePricingRepository implements PricingRepository {
  PracticePricingRepository({
    required PricingRepository real,
    required PracticeWorld world,
    required OrderPracticeData data,
  })  : _real = real,
        _world = world,
        _data = data;

  final PricingRepository _real;
  final PracticeWorld _world;
  final OrderPracticeData _data;

  @override
  ResultFuture<List<MobilePrice>> getPrices({
    required String depotId,
    required List<String> materials,
  }) async {
    if (_world.isClosed) {
      return _real.getPrices(depotId: depotId, materials: materials);
    }
    final wanted = materials
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    if (depotId.trim().isEmpty) {
      return Success([
        for (final material in wanted)
          MobilePrice(
            material: material,
            state: PricingState.unavailable,
            errorKind: PricingErrorKind.depotNotFound,
          ),
      ]);
    }
    final now = _data.now();
    return Success([
      for (final material in wanted)
        MobilePrice(
          material: material,
          state: PricingState.loaded,
          price: OrderPracticeData.priceFor(material),
          currency: OrderPracticeData.currency,
          validFrom: now,
          updatedAt: now,
        ),
    ]);
  }
}

/// SAP's sellability check during practice: every material is sellable with
/// plenty of stock, so a lesson is never blocked on a sales-area problem the
/// rep cannot fix. Nothing reaches the middleware. Once
/// [PracticeWorld.isClosed] every call goes to [_real].
class PracticeMaterialAvailabilityRepository
    implements MaterialAvailabilityRepository {
  PracticeMaterialAvailabilityRepository({
    required MaterialAvailabilityRepository real,
    required PracticeWorld world,
    required OrderPracticeData data,
  })  : _real = real,
        _world = world,
        _data = data;

  final MaterialAvailabilityRepository _real;
  final PracticeWorld _world;
  final OrderPracticeData _data;

  @override
  ResultFuture<MaterialAvailability> checkAvailability(String material) async {
    if (_world.isClosed) return _real.checkAvailability(material);
    final product = OrderPracticeData.productFor(material);
    return Success(MaterialAvailability(
      material: material,
      isSellable: true,
      summary: '',
      band: StockBand.high,
      baseUnit: product?.unit ?? '',
      plants: [
        MaterialPlantStock(
          plant: product?.warehouseCode ?? 'WH-PP01',
          band: StockBand.high,
          isSellable: true,
        ),
      ],
      checkedAt: _data.now(),
      status: MaterialStockStatus.available,
    ));
  }
}
