/// The resumable-workflow pointer, ported from the plaintext `routes.db`
/// (**T1.5b**).
///
/// This was the *last* live table in `routes.db` — the T1.5 purge emptied every
/// business table but could not delete the file while this one remained. With
/// this port the legacy file has no remaining readers and can finally be
/// removed.
///
/// ## Scope: this is a port, not ADR-007
///
/// ADR-007 specifies a generalized `WorkflowSession` in `core/workflow/` with
/// identity, expiry, and version fields. **This table is not that.** It is the
/// existing `my_visits`-scoped `ActiveWorkflow` shape moved verbatim into the
/// encrypted database so the plaintext file can go away. Adding the ADR-007
/// fields here would be building a module ahead of its plan
/// (`ENGINEERING_STANDARD.md` §2) and would change a row contract that
/// `ActiveWorkflowModel.fromRow`/`toRow` depend on.
///
/// The table lives in `core/database/drift/tables/` rather than under the
/// feature because every table in the single database does (ADR-001/ADR-004);
/// that placement is not an assertion that generalization has happened.
library;

import 'package:drift/drift.dart';

/// Single-row table: exactly one workflow is active at a time, always under
/// `id = 'active'`. Modelled as a keyed table rather than a one-row constraint
/// because that is the shape `ActiveWorkflowModel.toRow()` already writes.
class WorkflowState extends Table {
  @override
  String get tableName => 'workflow_state';

  TextColumn get id => text()();
  TextColumn get routeId => text()();
  TextColumn get currentStopId => text().nullable()();

  /// Persisted as INTEGER 0/1, matching the legacy column — `ActiveWorkflowModel`
  /// reads it with `(row['day_started'] as int) == 1`, so a `BoolColumn` (which
  /// drift would still store as INTEGER, but hand back as `bool` through
  /// `customSelect`) would break that cast.
  IntColumn get dayStarted => integer().withDefault(const Constant(0))();

  TextColumn get updatedAt => text()();

  // Resume context (legacy v3): enough to reopen the exact business activity,
  // not just the route.
  TextColumn get depotId => text().nullable()();
  TextColumn get shopName => text().nullable()();
  TextColumn get checkInAt => text().nullable()();
  TextColumn get currentWorkflow => text().nullable()();
  TextColumn get currentScreen => text().nullable()();

  /// Free-form JSON args (territory, depotId, …) so the resume dispatcher can
  /// rebuild the exact screen. Legacy v4 column; `ActiveWorkflowModel` tolerates
  /// null/corrupt values by falling back to the guided route resume.
  TextColumn get navigationArguments => text().nullable()();

  TextColumn get workflowUpdatedAt => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
