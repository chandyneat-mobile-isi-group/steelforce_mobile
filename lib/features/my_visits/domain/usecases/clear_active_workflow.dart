import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';

class ClearActiveWorkflow extends UseCase<void, NoParams> {
  const ClearActiveWorkflow(this._repository);
  final ActiveWorkflowRepository _repository;
  @override
  ResultFuture<void> call(NoParams params) => _repository.clearActiveWorkflow();
}
