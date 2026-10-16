import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';

abstract interface class ActiveWorkflowRepository {
  ResultFuture<ActiveWorkflow?> getActiveWorkflow();
  ResultFuture<void> saveActiveWorkflow(ActiveWorkflow workflow);
  ResultFuture<void> clearActiveWorkflow();
}
