import 'package:drift/drift.dart';

/// The last answer of each plans endpoint, kept so the Visits tab and the
/// Home badge still work offline (v30).
///
/// One row per [period] — `Today` (`GET /mobile/plans/today`) or `ThisMonth`
/// (`GET /mobile/plans?period=ThisMonth`) — holding the response `data` as
/// JSON. A snapshot rather than a row per plan: the server owns the plan, its
/// counts and their order, and the device only ever replays its last answer
/// whole. Encrypted with the rest of the database because a plan names the
/// rep's depots (docs/skills/security.md §3). Wiped with every other table on
/// sign-out.
class VisitPlanSnapshots extends Table {
  @override
  String get tableName => 'visit_plan_snapshots';

  TextColumn get period => text()();
  TextColumn get payload => text()();

  /// When the server gave this answer, UTC.
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {period};
}

/// A plan visit step saved on the device until the server has it (v32):
/// check-in, inventory photos and check-out, worked offline.
///
/// [id] is the id the step is sent with (`checkInId`, `uploadId`,
/// `checkOutId`), so a resend after a lost answer is the same request. Rows
/// of one plan go strictly oldest first; the first one the server refuses
/// for a reason a retry cannot fix is flagged ([needsAttention]) and holds
/// everything after it until the rep resends or discards. Photo paths in
/// [payload] point at copies under the app's documents directory. Encrypted
/// with the rest of the database and wiped on sign-out — which is refused
/// while any row is left.
class PlanVisitOutbox extends Table {
  @override
  String get tableName => 'plan_visit_outbox';

  TextColumn get id => text()();
  TextColumn get planId => text()();

  /// `checkIn`, `inventory` or `checkOut`.
  TextColumn get kind => text()();

  /// The request as JSON: position, reason, notes and photo paths.
  TextColumn get payload => text()();

  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// The server's code for the last refusal — never its free text.
  TextColumn get lastErrorCode => text().nullable()();

  /// The localisation key the rep is shown for [lastErrorCode].
  TextColumn get lastErrorMessage => text().nullable()();

  BoolColumn get needsAttention =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
