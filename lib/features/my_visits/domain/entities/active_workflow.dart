import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_workflow.dart';

/// Persisted pointer to the rep's in-progress visit, used to resume them after
/// a force-close/crash/tab-switch — never the source of truth for stop-level
/// progress (that's [RouteStop.status], re-read fresh from the DB on every
/// load). At most one row ever exists; see `WorkflowStateLocalDataSource`.
///
/// [routeId]/[currentStopId]/[dayStarted] are the original route-resume
/// pointer. The rest ([depotId] .. [workflowUpdatedAt]) make it
/// *workflow-aware*: they capture which Shop/Depot the rep checked into and
/// which business activity ([currentWorkflow]) they last entered, so the Home
/// "Continue Working" card can say "Continue Quotation" and route straight back
/// there. All workflow fields are nullable so older rows (and the pure
/// route-resume path) keep working unchanged.
class ActiveWorkflow extends Equatable {
  const ActiveWorkflow({
    required this.routeId,
    this.currentStopId,
    required this.dayStarted,
    required this.updatedAt,
    this.depotId,
    this.shopName,
    this.checkInAt,
    this.currentWorkflow,
    this.currentScreen,
    this.navigationArguments,
    this.workflowUpdatedAt,
  });

  final String routeId;
  final String? currentStopId;
  final bool dayStarted;
  final DateTime updatedAt;

  /// Shop/Depot the rep checked into (== the stop's `depot.id`). The key the
  /// Continue-Working dedup matches an Order draft against.
  final String? depotId;
  final String? shopName;
  final DateTime? checkInAt;

  /// The business activity the rep last entered; `null` means "route only"
  /// (checked in but no business task yet), which resumes to the guided flow.
  final VisitWorkflow? currentWorkflow;

  /// `RouteSettings.name` of the last screen entered — the resume target key
  /// the dispatcher maps back to a concrete screen.
  final String? currentScreen;

  /// Screen-specific arguments needed to rebuild [currentScreen] exactly (e.g.
  /// `{'territory': 'PP'}` for the shop list, `{'depotId': 'C1'}` for a
  /// depot detail). Persisted as JSON so any future workflow can carry its
  /// own context without a schema change.
  final Map<String, dynamic>? navigationArguments;

  final DateTime? workflowUpdatedAt;

  /// True once the rep has checked into a specific Shop/Depot on this visit.
  bool get hasCheckedIn => depotId != null && checkInAt != null;

  ActiveWorkflow copyWith({
    String? currentStopId,
    bool? dayStarted,
    DateTime? updatedAt,
    String? depotId,
    String? shopName,
    DateTime? checkInAt,
    VisitWorkflow? currentWorkflow,
    String? currentScreen,
    Map<String, dynamic>? navigationArguments,
    DateTime? workflowUpdatedAt,
  }) =>
      ActiveWorkflow(
        routeId: routeId,
        currentStopId: currentStopId ?? this.currentStopId,
        dayStarted: dayStarted ?? this.dayStarted,
        updatedAt: updatedAt ?? this.updatedAt,
        depotId: depotId ?? this.depotId,
        shopName: shopName ?? this.shopName,
        checkInAt: checkInAt ?? this.checkInAt,
        currentWorkflow: currentWorkflow ?? this.currentWorkflow,
        currentScreen: currentScreen ?? this.currentScreen,
        navigationArguments: navigationArguments ?? this.navigationArguments,
        workflowUpdatedAt: workflowUpdatedAt ?? this.workflowUpdatedAt,
      );

  @override
  List<Object?> get props => [
        routeId,
        currentStopId,
        dayStarted,
        updatedAt,
        depotId,
        shopName,
        checkInAt,
        currentWorkflow,
        currentScreen,
        navigationArguments,
        workflowUpdatedAt,
      ];
}
