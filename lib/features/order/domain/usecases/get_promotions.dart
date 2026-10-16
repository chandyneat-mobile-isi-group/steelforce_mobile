import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion.dart';
import 'package:steelforce/features/order/domain/repositories/promotion_repository.dart';

class GetPromotionsParams extends Equatable {
  const GetPromotionsParams({this.depotId, this.includeUpcoming = false});

  final String? depotId;
  final bool includeUpcoming;

  @override
  List<Object?> get props => [depotId, includeUpcoming];
}

/// Promotions worth showing, for the dashboard strip and the promotions page.
class GetPromotions extends UseCase<List<Promotion>, GetPromotionsParams> {
  const GetPromotions(this._repository);
  final PromotionRepository _repository;

  @override
  ResultFuture<List<Promotion>> call(GetPromotionsParams params) =>
      _repository.getPromotions(
        depotId: params.depotId,
        includeUpcoming: params.includeUpcoming,
      );
}
