import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Sends a visit's steps the server refused again, once the rep has seen
/// why (the visit's "Needs attention").
class ResendPlanVisitSteps extends UseCase<void, String> {
  const ResendPlanVisitSteps(this._repository);
  final VisitPlanRepository _repository;

  @override
  ResultFuture<void> call(String params) => _repository.resendPlanSteps(params);
}

/// Drops a visit's steps still on the device — the rep's own decision,
/// after a refusal they cannot fix.
class DiscardPlanVisitSteps extends UseCase<void, String> {
  const DiscardPlanVisitSteps(this._repository);
  final VisitPlanRepository _repository;

  @override
  ResultFuture<void> call(String params) =>
      _repository.discardPlanSteps(params);
}
