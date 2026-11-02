import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Checks the rep out of a planned visit: CheckedIn → Completed.
class CheckOutVisitPlan extends UseCase<PlanStepDelivery, PlanCheckOutRequest> {
  const CheckOutVisitPlan(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<PlanStepDelivery> call(PlanCheckOutRequest params) =>
      _repository.checkOut(params);
}
