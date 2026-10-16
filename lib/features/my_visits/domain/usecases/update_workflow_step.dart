import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/active_workflow.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';

class UpdateWorkflowStepParams {
  const UpdateWorkflowStepParams(
    this.workflow, {
    this.screen,
    this.navigationArguments,
  });
  final VisitWorkflow workflow;
  final String? screen;

  /// Screen-specific args the resume dispatcher needs to rebuild [screen]
  /// exactly (e.g. `{'territory': 'PP'}`), merged onto the persisted pointer.
  final Map<String, dynamic>? navigationArguments;
}

/// Records that the rep entered a new business activity ([VisitWorkflow]) on
/// the current visit — merging it onto the persisted [ActiveWorkflow] row so
/// the Home "Continue Working" card resumes into the right place.
///
/// A no-op when there's no active visit (nothing to attach the step to): the
/// guided flow only calls this *after* a check-in has seeded the row. Reuses
/// the existing get/save repository methods rather than adding a bespoke
/// data-source call.
class UpdateWorkflowStep extends UseCase<void, UpdateWorkflowStepParams> {
  const UpdateWorkflowStep(this._repository);
  final ActiveWorkflowRepository _repository;

  @override
  ResultFuture<void> call(UpdateWorkflowStepParams params) async {
    final current = await _repository.getActiveWorkflow();
    return switch (current) {
      Failed(failure: final f) => Failed(f),
      // No active visit to attach the step to — nothing to record.
      Success(data: null) => const Success(null),
      Success(data: final workflow!) => await _save(workflow, params),
    };
  }

  ResultFuture<void> _save(
      ActiveWorkflow workflow, UpdateWorkflowStepParams params) {
    final now = DateTime.now();
    return _repository.saveActiveWorkflow(workflow.copyWith(
      currentWorkflow: params.workflow,
      currentScreen: params.screen,
      // Merged, not replaced. A caller recording one step knows only about its
      // own arguments; replacing the map would silently drop the keys written
      // at check-in (`stopId`, `territory`) that the resume dispatcher's
      // fallbacks depend on. Incoming keys win, everything else survives.
      navigationArguments: params.navigationArguments == null
          ? workflow.navigationArguments
          : {
              ...?workflow.navigationArguments,
              ...params.navigationArguments!,
            },
      workflowUpdatedAt: now,
      updatedAt: now,
    ));
  }
}
