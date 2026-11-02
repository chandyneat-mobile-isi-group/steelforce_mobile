import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Skips one planned visit with the rep's reason.
class SkipVisitPlan extends UseCase<void, SkipVisitPlanParams> {
  const SkipVisitPlan(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<void> call(SkipVisitPlanParams params) =>
      _repository.skipPlan(params.planId, params.reason.trim());
}

class SkipVisitPlanParams extends Equatable {
  const SkipVisitPlanParams({required this.planId, required this.reason});

  /// The plan id — never a depot code.
  final String planId;

  /// 1–500 characters once trimmed; the server rejects anything else.
  final String reason;

  static const maxReasonLength = 500;

  @override
  List<Object?> get props => [planId, reason];
}
