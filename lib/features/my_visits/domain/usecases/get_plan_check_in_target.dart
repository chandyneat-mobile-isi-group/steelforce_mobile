import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Reads where a plan's depot is and its check-in radius. Takes the plan id.
class GetPlanCheckInTarget extends UseCase<PlanCheckInTarget, String> {
  const GetPlanCheckInTarget(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<PlanCheckInTarget> call(String planId) =>
      _repository.getCheckInTarget(planId);
}
