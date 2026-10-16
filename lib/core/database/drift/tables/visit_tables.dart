import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';

/// Visit captures — everything a rep records at a stop. Ported from the legacy
/// plaintext `routes.db` into the single encrypted database (ADR-001, T1.5).
///
/// All of these are **first-hand field captures**, which
/// `docs/blueprint/sync-architecture.md` §5 classifies as *client-authoritative*: the server has
/// no competing version of an observation the rep made, so they push rather than
/// merge. They still carry the full §3.1 column set because they participate in
/// sync — a capture that never reaches SAP is a lost sale, and losing one is the
/// failure mode the whole offline design exists to prevent.
///
/// ## No foreign key to `route_stops` (ADR-011, schema v18)
///
/// `stop_id` is a plain column. These tables used to cascade from `route_stops`,
/// which was actively dangerous: route sync replaces a route's stops on every
/// run, so a routine delta — one the backend documents as "acceptable and
/// expected" (`docs/feature/my-visits/api.md` §5.2) — silently deleted every
/// check-in, note and photo the rep had captured and not yet pushed.
///
/// Losing a first-hand capture is the exact failure the offline design exists
/// to prevent, so the constraint had to go: the backend already owns this
/// relationship, and the device only has to store the capture and hand it to
/// the push. An orphaned capture is still pushed by `stop_id` and is dropped
/// only once the server has it.

/// Arrival at a stop. Unique per stop — a rep checks in once.
@TableIndex(name: 'idx_visit_check_ins_stop', columns: {#stopId}, unique: true)
@DataClassName('VisitCheckInRow')
class VisitCheckIns extends Table with SyncableTable {
  @override
  String get tableName => 'visit_check_ins';

  TextColumn get stopId => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real()();

  /// Metres between the rep and the depot's registered location — the input
  /// to the geofence rule, retained for audit.
  RealColumn get distanceFromDepot => real()();
  BoolColumn get isMocked => boolean().withDefault(const Constant(false))();

  /// Why the rep checked in from outside the geofence, when they did.
  ///
  /// Null is the normal case — a check-in that satisfied the rule needs no
  /// explanation. Non-null means the rep was let through anyway and said why,
  /// so the row carries its own justification rather than leaving an
  /// out-of-bounds check-in indistinguishable from a compliant one.
  ///
  /// Nullable and additive: the geofence verdict itself stays in
  /// [distanceFromDepot], which is what the server re-evaluates.
  TextColumn get overrideReason => text().nullable()();

  /// The route the stop was on (v28). Lets the server refuse a stale stop
  /// quickly; null on rows written before it existed.
  TextColumn get routeId => text().nullable()();
}

/// Departure from a stop. Unique per stop.
@TableIndex(name: 'idx_visit_check_outs_stop', columns: {#stopId}, unique: true)
@DataClassName('VisitCheckOutRow')
class VisitCheckOuts extends Table with SyncableTable {
  @override
  String get tableName => 'visit_check_outs';

  TextColumn get stopId => text()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get durationMinutes => integer()();
  TextColumn get visitSummary => text()();

  // ── v28: how the visit ended (check-in-check-out-mobile.md §5) ──
  // All nullable: a check-out queued before v28 has none of these, and the
  // server stores it with outcome `unknown`.

  /// The check-in this closes — the visit id.
  TextColumn get checkInId => text().nullable()();

  /// `withOrder` or `withoutOrder`.
  TextColumn get outcome => text().nullable()();

  /// With order: JSON array of `{clientId, quotationId, type}`.
  TextColumn get ordersJson => text().nullable()();

  /// Without order: a code from the server's reason list, plus a note when
  /// that reason requires one.
  TextColumn get noOrderReason => text().nullable()();
  TextColumn get noOrderNote => text().nullable()();
}

/// Order lines captured during a visit.
///
/// [unitPrice] is denormalised deliberately: it records the price *as quoted at
/// the visit*, which must not silently change if the catalog is re-synced
/// afterwards. Server-side divergence on price is a conflict routed to
/// Action-Required, never an in-place overwrite (`docs/blueprint/sync-architecture.md` §5).
@TableIndex(name: 'idx_visit_order_lines_stop', columns: {#stopId})
@DataClassName('VisitOrderLineRow')
class VisitOrderLines extends Table with SyncableTable {
  @override
  String get tableName => 'visit_order_lines';

  TextColumn get stopId => text()();
  TextColumn get productId => text()();

  /// Denormalised at capture time so a historical line still renders if the
  /// product is later delisted from the catalog.
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  TextColumn get unit => text()();
  RealColumn get unitPrice => real()();
}

/// Shelf/stock statuses taken at a route stop or during a depot count.
///
/// v10 replaced the numeric `counted_quantity` capture with a three-tier
/// `stock_level` (`'low'` / `'medium'` / `'high'` — the domain [StockLevel]
/// enum's storage names). Exactly one of [stopId] / [depotId] is set per row:
/// stop captures ride the visit flow, depot captures the depot flow; both push
/// through the same pending-sync batch.
@TableIndex(name: 'idx_visit_stock_updates_stop', columns: {#stopId})
@TableIndex(name: 'idx_visit_stock_updates_depot', columns: {#depotId})
@DataClassName('VisitStockUpdateRow')
class VisitStockUpdates extends Table with SyncableTable {
  @override
  String get tableName => 'visit_stock_updates';

  TextColumn get stopId => text().nullable()();

  /// The depot/shop (depot id) a depot count was taken at. No FK: depot
  /// counts may reference depots synced later than the capture.
  TextColumn get depotId => text().nullable()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  TextColumn get stockLevel => text()();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// Goods returned by the depot during a visit.
@TableIndex(name: 'idx_visit_returns_stop', columns: {#stopId})
@DataClassName('VisitReturnRow')
class VisitReturns extends Table with SyncableTable {
  @override
  String get tableName => 'visit_returns';

  TextColumn get stopId => text()();
  TextColumn get productId => text()();
  TextColumn get productName => text()();
  RealColumn get quantity => real()();
  TextColumn get reason => text()();
}

/// Cash/cheque collected at a stop. Financial data — server-authoritative on
/// conflict (`docs/blueprint/sync-architecture.md` §5).
@TableIndex(name: 'idx_visit_collections_stop', columns: {#stopId})
@DataClassName('VisitCollectionRow')
class VisitCollections extends Table with SyncableTable {
  @override
  String get tableName => 'visit_collections';

  TextColumn get stopId => text()();
  RealColumn get amount => real()();
  TextColumn get method => text()();
  TextColumn get reference => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
}

/// Free-text notes recorded at a stop.
@TableIndex(name: 'idx_visit_notes_stop', columns: {#stopId})
@DataClassName('VisitNoteRow')
class VisitNotes extends Table with SyncableTable {
  @override
  String get tableName => 'visit_notes';

  TextColumn get stopId => text()();
  TextColumn get type => text()();

  /// The note itself. Named [body] in Dart because `text` would shadow Drift's
  /// own `text()` column builder; `.named('text')` keeps the SQL column name
  /// identical to the legacy sqflite table so the T1.5 import maps 1:1.
  TextColumn get body => text().named('text')();
  DateTimeColumn get createdAt => dateTime()();
}

/// Photo / signature evidence captured at a stop.
///
/// **Layer 4 boundary** (`docs/blueprint/system-architecture.md` §3): this table stores only a
/// filesystem [path] — never the binary. Encrypting the referenced file itself
/// is the `core/database/files/encrypted_file_store.dart` deliverable
/// (`docs/blueprint/migration-plan.md` §8, P0), so until that lands the *reference* is
/// encrypted here while the file on disk is not.
@TableIndex(name: 'idx_visit_photos_stop', columns: {#stopId})
@DataClassName('VisitPhotoRow')
class VisitPhotos extends Table with SyncableTable {
  @override
  String get tableName => 'visit_photos';

  TextColumn get stopId => text()();

  /// Filesystem path or remote URL. Legacy column was named `url`.
  // TODO(release-gate): the referenced file is not yet encrypted at rest —
  // blocked on the encrypted file store (MIGRATION_PLAN.md §8). Must not ship
  // to production as-is (SECURITY.md §11 release checklist).
  TextColumn get path => text()();
  TextColumn get caption => text().withDefault(const Constant(''))();
  DateTimeColumn get takenAt => dateTime()();
  BoolColumn get isSignature => boolean().withDefault(const Constant(false))();
}
