import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/repositories/visit_plan_repository.dart';

/// Adds the Inventory Visibility photos to a checked-in planned visit.
class UploadPlanInventoryPhotos
    extends UseCase<PlanStepDelivery, PlanInventoryUploadRequest> {
  const UploadPlanInventoryPhotos(this._repository);

  final VisitPlanRepository _repository;

  @override
  ResultFuture<PlanStepDelivery> call(PlanInventoryUploadRequest params) =>
      _repository.uploadInventoryPhotos(params);
}
