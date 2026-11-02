import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Checks the rep in at a planned visit with GPS and photos.
class CheckInVisitPlan extends UseCase<PlanCheckInResult, PlanCheckInRequest> {
  const CheckInVisitPlan(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<PlanCheckInResult> call(PlanCheckInRequest params) =>
      _repository.checkIn(params);
}
