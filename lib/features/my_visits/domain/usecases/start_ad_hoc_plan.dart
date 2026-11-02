import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Starts an unplanned visit for today at an outlet the rep can see.
class StartAdHocPlan extends UseCase<AdHocPlanOutcome, AdHocPlanOutlet> {
  const StartAdHocPlan(this._repository);
  final VisitPlanRepository _repository;

  @override
  ResultFuture<AdHocPlanOutcome> call(AdHocPlanOutlet params) =>
      _repository.startAdHoc(params);
}
