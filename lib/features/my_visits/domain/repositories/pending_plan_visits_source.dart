import 'package:steelforce/features/my_visits/domain/entities/pending_plan_visit.dart';

/// Planned visits with steps still on this device, oldest first.
abstract interface class PendingPlanVisitsSource {
  /// Emits now and again whenever a step is saved, sent or discarded.
  Stream<List<PendingPlanVisit>> watch();
}
