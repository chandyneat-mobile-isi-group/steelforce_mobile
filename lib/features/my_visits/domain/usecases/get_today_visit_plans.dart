import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Loads the signed-in rep's visit plans for today — the Visits list.
class GetTodayVisitPlans extends UseCase<VisitPlansOverview, NoParams> {
  const GetTodayVisitPlans(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<VisitPlansOverview> call(NoParams params) =>
      _repository.getTodayPlans();
}
