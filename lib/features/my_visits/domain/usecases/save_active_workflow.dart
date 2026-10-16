import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';

class SaveActiveWorkflow extends UseCase<void, ActiveWorkflow> {
  const SaveActiveWorkflow(this._repository);
  final ActiveWorkflowRepository _repository;
  @override
  ResultFuture<void> call(ActiveWorkflow params) =>
      _repository.saveActiveWorkflow(params);
}
