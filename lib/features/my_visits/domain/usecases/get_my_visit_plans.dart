import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Loads the signed-in rep's visit plans for [PlanPeriod].
class GetMyVisitPlans extends UseCase<VisitPlansOverview, PlanPeriod> {
  const GetMyVisitPlans(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<VisitPlansOverview> call(PlanPeriod params) =>
      _repository.getMyPlans(params);
}
