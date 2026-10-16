import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_status.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_repository.dart';

/// Resolves the route id the rep should be resumed into on app launch, or
/// `null` if there's nothing to resume. A deliberate exception to this
/// codebase's usual "one usecase = one repository method" shape: the
/// corruption/staleness self-healing here (clearing a pointer that's stale,
/// points at a deleted route, or points at an already-finished route)
/// genuinely spans both [ActiveWorkflowRepository] and [RouteRepository],
/// and belongs in the domain layer rather than duplicated in the UI.
class GetResumableRoute extends UseCase<String?, NoParams> {
  const GetResumableRoute(this._workflowRepository, this._routeRepository);
  final ActiveWorkflowRepository _workflowRepository;
  final RouteRepository _routeRepository;

  @override
  ResultFuture<String?> call(NoParams params) async {
    final workflowResult = await _workflowRepository.getActiveWorkflow();
    final workflow =
        workflowResult.when(success: (w) => w, failure: (_) => null);
    if (workflow == null) return const Success(null);

    if (!_isToday(workflow.updatedAt)) {
      await _workflowRepository.clearActiveWorkflow();
      return const Success(null);
    }

    final routeResult = await _routeRepository.getRoute(workflow.routeId);
    return switch (routeResult) {
      Success(data: final route) => await _evaluate(route),
      Failed() => await _clearAndReturnNull(),
    };
  }

  Future<Result<String?>> _evaluate(RoutePlan route) async {
    final allResolved = route.stops.every((s) =>
        s.status == VisitStatus.checkedOut || s.status == VisitStatus.missed);
    if (route.status == RouteStatus.completed || allResolved) {
      return _clearAndReturnNull();
    }
    return Success(route.id);
  }

  Future<Result<String?>> _clearAndReturnNull() async {
    await _workflowRepository.clearActiveWorkflow();
    return const Success(null);
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }
}
