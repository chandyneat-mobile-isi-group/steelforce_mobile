import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/visit_plan_tables.dart';

part 'visit_plan_dao.g.dart';

/// The plans endpoints' last answers, and the visit steps waiting to reach
/// the server (ADR-004: one DAO per aggregate).
@DriftAccessor(tables: [VisitPlanSnapshots, PlanVisitOutbox])
class VisitPlanDao extends DatabaseAccessor<AppDatabase>
    with _$VisitPlanDaoMixin {
  VisitPlanDao(super.db);

  /// Replaces the snapshot for [period].
  Future<void> save(String period, String payload, DateTime fetchedAt) =>
      into(visitPlanSnapshots).insertOnConflictUpdate(
        VisitPlanSnapshotsCompanion.insert(
          period: period,
          payload: payload,
          fetchedAt: fetchedAt.toUtc(),
        ),
      );

  /// The snapshot for [period], or null when none was ever saved.
  Future<VisitPlanSnapshot?> read(String period) =>
      (select(visitPlanSnapshots)..where((t) => t.period.equals(period)))
          .getSingleOrNull();

  // ── Outbox (v32) ───────────────────────────────────────────────────

  Future<void> enqueueStep(PlanVisitOutboxCompanion row) =>
      into(planVisitOutbox).insertOnConflictUpdate(row);

  /// Every waiting step, oldest first.
  Future<List<PlanVisitOutboxData>> allSteps() =>
      (select(planVisitOutbox)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<PlanVisitOutboxData>> watchSteps() =>
      (select(planVisitOutbox)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  /// [planId]'s waiting steps, in the order they must reach the server.
  Future<List<PlanVisitOutboxData>> stepsFor(String planId) =>
      (select(planVisitOutbox)
            ..where((t) => t.planId.equals(planId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Future<void> deleteStep(String id) =>
      (delete(planVisitOutbox)..where((t) => t.id.equals(id))).go();

  Future<void> deleteStepsFor(String planId) =>
      (delete(planVisitOutbox)..where((t) => t.planId.equals(planId))).go();

  /// A try that may yet work: counted, the code kept, still sendable.
  Future<void> markStepAttempted(String id, String code) async {
    await customUpdate(
      'UPDATE plan_visit_outbox SET attempts = attempts + 1, '
      'last_error_code = ? WHERE id = ?',
      variables: [Variable.withString(code), Variable.withString(id)],
      updates: {planVisitOutbox},
    );
  }

  /// A refusal a retry cannot fix: held for the rep, with what to show.
  Future<void> flagStep(String id, String code, String message) =>
      (update(planVisitOutbox)..where((t) => t.id.equals(id))).write(
        PlanVisitOutboxCompanion(
          lastErrorCode: Value(code),
          lastErrorMessage: Value(message),
          needsAttention: const Value(true),
        ),
      );

  /// The rep asked to send [planId]'s steps again.
  Future<void> clearFlagsFor(String planId) =>
      (update(planVisitOutbox)..where((t) => t.planId.equals(planId))).write(
        const PlanVisitOutboxCompanion(
          needsAttention: Value(false),
          lastErrorMessage: Value(null),
        ),
      );
}
