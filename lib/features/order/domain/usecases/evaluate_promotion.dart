import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/promotion/promotion_evaluation.dart';
import 'package:steelforce/features/order/domain/repositories/promotion_repository.dart';

class EvaluatePromotionParams extends Equatable {
  const EvaluatePromotionParams({
    required this.materialCode,
    required this.categoryCode,
    required this.quantity,
    this.depotId,
  });

  final String materialCode;
  final String categoryCode;
  final int quantity;

  /// The depot the quotation is for. Null for a walk-in, which matches only
  /// unscoped promotions — a named account's negotiated deal must not leak.
  final String? depotId;

  @override
  List<Object?> get props => [materialCode, categoryCode, quantity, depotId];
}

/// What this depot earns on this material at this quantity.
///
/// The single question the product card asks, re-asked whenever the quantity
/// changes. Null means no promotion applies, and renders as nothing.
class EvaluatePromotion
    extends UseCase<PromotionEvaluation?, EvaluatePromotionParams> {
  const EvaluatePromotion(this._repository);
  final PromotionRepository _repository;

  @override
  ResultFuture<PromotionEvaluation?> call(EvaluatePromotionParams params) =>
      _repository.evaluate(
        materialCode: params.materialCode,
        categoryCode: params.categoryCode,
        quantity: params.quantity,
        depotId: params.depotId,
      );
}
