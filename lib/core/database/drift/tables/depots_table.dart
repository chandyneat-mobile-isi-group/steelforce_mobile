import 'package:drift/drift.dart';

/// Offline depot directory (Blueprint Layer 1). Ported from the legacy
/// `depots.db` `depots` table into the single encrypted database, using
/// idiomatic Drift column types (DateTime/bool/int) instead of the old
/// text/int-encoded columns.
///
/// SAP-controlled: overwritten wholesale on every sync, never merged locally
/// (reps have no write path to these columns), so the sync strategy is a plain
/// upsert keyed by [id] with [sapDepotId] uniquely indexed.
@TableIndex(name: 'idx_depots_territory', columns: {#territory})
@TableIndex(name: 'idx_depots_rep', columns: {#assignedRepId})
@TableIndex(name: 'idx_depots_status', columns: {#status})
// Both back a hot-path `WHERE` in `DepotDao.browse` once the Sales
// Organization / Division filters are selectable, so they are indexed per
// DATABASE_GUIDE.md §3.
@TableIndex(name: 'idx_depots_sales_org', columns: {#salesOrg})
@TableIndex(name: 'idx_depots_division', columns: {#division})
class Depots extends Table {
  @override
  String get tableName => 'depots';

  TextColumn get id => text()();

  /// Nullable *and* unique, deliberately: SQLite counts every NULL as
  /// distinct, so this reads as "at most one row per SAP id, and rows without
  /// one never conflict" — which is exactly the rule for field-created
  /// depots awaiting approval.
  TextColumn get sapDepotId => text().nullable().unique()();
  TextColumn get depotCode => text()();
  TextColumn get shopName => text()();
  TextColumn get ownerName => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get whatsapp => text().nullable()();
  TextColumn get address => text()();
  TextColumn get province => text()();
  TextColumn get district => text()();
  TextColumn get territory => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get creditLimit => real()();
  TextColumn get status => text()();
  TextColumn get assignedRepId => text()();
  TextColumn get assignedRepName => text()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originLeadId => text().nullable()();
  TextColumn get productsPurchased => text().withDefault(const Constant(''))();
  DateTimeColumn get lastOrderDate => dateTime().nullable()();
  DateTimeColumn get lastVisitDate => dateTime().nullable()();
  RealColumn get lifetimeValue => real().withDefault(const Constant(0))();
  IntColumn get openOpportunityCount =>
      integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  // ── Route-execution attributes (T1.5, schema v7) ────────────────────
  // Absorbed from the legacy plaintext `routes.db.depots` table, which was a
  // denormalised copy of this one plus these two fields. Rather than import
  // that copy — which would resurrect stale PII and clobber the SAP-controlled
  // columns above — the two genuinely-unique fields are added here and the
  // legacy copy is dropped. This table stays the single source of truth for a
  // depot (ADR-001).
  //
  // Both are nullable because rows created before v7 have no value, and because
  // only depots that appear on a route ever carry them.

  /// Urban / rural / etc. — drives visit-planning rules.
  TextColumn get territoryType => text().nullable()();

  /// Per-depot geofence radius in metres, overriding the global policy when
  /// a site is unusually large (a depot yard) or tight (a stall in a market).
  RealColumn get geofenceRadiusOverride => real().nullable()();

  // ── SAP sales-area & commercial attributes (schema v9) ──────────────
  // Names deliberately mirror the SAP Depot (BP) API field names documented
  // in `SapAPI_Technical_Document_v1_BP.docx` §5, so swapping the mock remote
  // datasource for a real SAP one is a mapper change, not a schema change
  // (ADR-009 decision 4).
  //
  // All are nullable or defaulted: `addColumn` must supply a value for rows
  // that already exist at v8, and SAP itself leaves most of these blank for
  // prospects that have no sales area assigned yet.

  /// Sales area — the three fields SAP uses together to scope a depot.
  TextColumn get salesOrg => text().nullable()();
  TextColumn get division => text().nullable()();
  TextColumn get distributionChannel => text().nullable()();

  /// Commercial classification.
  TextColumn get depotGroup => text().nullable()();
  TextColumn get priceGroup => text().nullable()();

  /// Latin and Khmer legal names. `shopName` stays the display name; these are
  /// the SAP `name1` / `name3` equivalents used for search and documents.
  TextColumn get enName => text().nullable()();
  TextColumn get khName => text().nullable()();

  /// Credit position. `creditLimit` already exists above; the balance is the
  /// currently-consumed portion, so available credit is limit − balance.
  RealColumn get creditBalance => real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();

  /// VAT / tax identification number (SAP `taxNumber`).
  TextColumn get taxNumber => text().nullable()();

  /// Lifetime order count. `lifetimeValue` above is the matching money figure.
  IntColumn get totalOrders => integer().withDefault(const Constant(0))();

  /// When SAP first created the record. `updatedAt` already covers the
  /// modification side.
  DateTimeColumn get createdAt => dateTime().nullable()();

  /// Per-row sync state — `synced` / `dirty` / `syncing` / `conflict`
  /// (SYNC_ENGINE.md §5). Adding it here closes part of the standard
  /// syncable-column gap in DATABASE_GUIDE.md §3.1; `server_revision` and
  /// `dirty` remain outstanding and belong with the sync-engine work rather
  /// than this feature change.
  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}
