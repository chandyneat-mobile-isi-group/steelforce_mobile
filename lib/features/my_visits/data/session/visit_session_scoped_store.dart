import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/features/my_visits/domain/repositories/active_workflow_repository.dart';

/// Drops the outgoing rep's "continue where you left off" pointer on sign-out.
///
/// [ActiveWorkflow] is a resume pointer into a route/stop the previous rep was
/// mid-way through (ADR-007). Left behind, the next rep signs in and the shell
/// offers to resume someone else's visit — and, worse, a check-in captured
/// under it would be attributed to the wrong person.
///
/// Captured visit data (check-ins, stock counts, photos) goes with the rest of
/// the database (`LocalDatabaseSessionStore`); sign-out is refused while any
/// of it is still unsent (`VisitUnsentWorkSource`).
class VisitSessionScopedStore implements SessionScopedStore {
  const VisitSessionScopedStore(this._workflow);

  final ActiveWorkflowRepository _workflow;

  @override
  String get debugName => 'my_visits.active_workflow';

  @override
  Future<void> clearForSignOut() => _workflow.clearActiveWorkflow();
}
