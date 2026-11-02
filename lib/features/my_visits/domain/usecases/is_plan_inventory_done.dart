import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Whether the visit [planId] has its Inventory Visibility photos, so it can
/// be checked out.
class IsPlanInventoryDone extends UseCase<bool, String> {
  const IsPlanInventoryDone(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<bool> call(String params) async =>
      Success(await _repository.isInventoryDone(params));
}
