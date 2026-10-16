import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';
import 'package:steelforce/features/order/domain/repositories/pricing_repository.dart';

class DepotPricesParams extends Equatable {
  const DepotPricesParams({
    required this.depotId,
    required this.materials,
  });

  final String depotId;

  /// SAP material numbers. Batched into one request via the endpoint's
  /// repeatable `materials` parameter.
  final List<String> materials;

  @override
  List<Object?> get props => [depotId, materials];
}

/// What this depot pays for these materials, according to the backend.
class GetDepotMaterialPrices
    extends UseCase<List<MobilePrice>, DepotPricesParams> {
  const GetDepotMaterialPrices(this._repository);
  final PricingRepository _repository;

  @override
  ResultFuture<List<MobilePrice>> call(DepotPricesParams params) =>
      _repository.getPrices(
        depotId: params.depotId,
        materials: params.materials,
      );
}
