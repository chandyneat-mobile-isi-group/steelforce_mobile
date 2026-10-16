import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';

/// Route plans (Blueprint Layer 1). Ported from the legacy **plaintext**
/// `routes.db` `routes` table into the single encrypted database (ADR-001,
/// `docs/blueprint/migration-plan.md` T1.5).
///
/// Offline posture (`docs/blueprint/offline-architecture.md` §4): full offline, pull + push
/// telemetry — the plan is issued by the backend, while execution status is
/// captured locally and pushed.
@TableIndex(name: 'idx_routes_rep', columns: {#repId})
@TableIndex(name: 'idx_routes_visit_date', columns: {#visitDate})
@DataClassName('RouteRow')
class Routes extends Table with SyncableTable {
  @override
  String get tableName => 'routes';

  TextColumn get name => text()();
  TextColumn get repId => text()();
  TextColumn get repName => text()();
  TextColumn get territory => text()();
  DateTimeColumn get visitDate => dateTime()();
  DateTimeColumn get plannedStart => dateTime()();
  DateTimeColumn get plannedEnd => dateTime()();
  TextColumn get status => text()();
}

/// Stops on a [Routes] plan. Legacy table name was `stops`; renamed to match the
/// `RouteStop` domain entity.
///
/// ## No foreign keys (ADR-011, schema v18)
///
/// [routeId] and [depotId] are plain columns. Both constraints were removed
/// after they were shown to destroy data rather than protect it:
///
///   * `depot_id -> depots` aborted the *entire* route write when any one
///     stop referenced a depot the directory had not pulled yet. The route
///     feed and the depot feed page independently and the backend never
///     promised an arrival order, so a five-stop day persisted zero stops and
///     zero routes. The rep lost the whole day, not one stop.
///   * `route_id -> routes ON DELETE CASCADE` is unnecessary for the same
///     reason: the two always arrive in one payload, and nothing hard-deletes
///     a route.
///
/// The stop's own depot details are stored flat in [RouteDepots], so a
/// stop renders from the route feed alone and never depends on the depot
/// directory having synced first.
@TableIndex(name: 'idx_route_stops_route', columns: {#routeId})
@TableIndex(name: 'idx_route_stops_depot', columns: {#depotId})
@DataClassName('RouteStopRow')
class RouteStops extends Table with SyncableTable {
  @override
  String get tableName => 'route_stops';

  TextColumn get routeId => text()();
  TextColumn get depotId => text()();

  /// Call Plan stops occupy 1..100; ad hoc visits are banded at 1001 and above
  /// so ordering by this column alone already puts them last.
  IntColumn get sequence => integer()();

  /// Nullable since schema v25: an ad hoc visit has no planned window, and the
  /// backend sends null rather than inventing one. Non-null for every Call Plan
  /// stop, exactly as before.
  DateTimeColumn get plannedArrival => dateTime().nullable()();
  DateTimeColumn get plannedDeparture => dateTime().nullable()();
  TextColumn get status => text()();

  /// `callPlan` | `adHoc` — where the stop came from, not what happened to it.
  /// Defaulted rather than nullable: every row written before v25 is a Call
  /// Plan stop, which is what they all were.
  TextColumn get visitSource =>
      text().withDefault(const Constant('callPlan'))();

  DateTimeColumn get actualArrival => dateTime().nullable()();
  DateTimeColumn get actualDeparture => dateTime().nullable()();
}

/// The depot details carried by the **route feed itself**
/// (`docs/feature/my-visits/api.md` §7.1 `DepotStopInfo`) — a flat,
/// de-duplicated mirror, one row per depot appearing on a route.
///
/// ## Why this exists rather than joining the directory (ADR-011)
///
/// T1.5 deleted the legacy denormalised copy and made route stops join
/// `depots` instead, on the reasoning that the directory is the single
/// source of truth. That reasoning was sound for *ownership* and wrong for
/// *availability*: the two feeds are separate endpoints with separate scopes,
/// so a stop routinely references a depot the directory does not have, and
/// the join then hid the stop from the rep standing outside the shop.
///
/// This table restores the payload's own copy without resurrecting the old
/// confusion: it is explicitly the *route feed's* view, used only to render
/// stops. It never feeds the Depots screen, and the directory never reads
/// it. That also removes `my_visits`' dependency on the depot feature's
/// tables, which `CLAUDE.md` §4 forbids anyway.
///
/// Server-owned and replaced wholesale on every route sync, so it carries no
/// sync state of its own.
@DataClassName('RouteDepotRow')
class RouteDepots extends Table {
  @override
  String get tableName => 'route_depots';

  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Khmer shop name. `''` is the documented "no Khmer name" value, so the
  /// column defaults rather than being nullable — `LocalizedText` falls back
  /// to [name] and a stop card is never blank.
  TextColumn get nameKh => text().withDefault(const Constant(''))();
  TextColumn get code => text()();
  TextColumn get contact => text()();
  TextColumn get phone => text()();
  TextColumn get address => text()();
  TextColumn get territory => text()();
  TextColumn get territoryType => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();

  /// Metres; falls back to the territory-type default when absent.
  RealColumn get geofenceRadiusOverride => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// GPS breadcrumb trail captured while a route is executed.
///
/// **Sensitive**: this is a location trace of a named employee. It sat in a
/// plaintext SQLite file until T1.5; moving it into the encrypted database is
/// the single highest-severity outcome of this migration
/// (`docs/skills/security.md` §3, `docs/blueprint/migration-plan.md` §9 risk register).
///
/// Keeps its `route_id` foreign key (ADR-011 kept the constraints that have no
/// data-loss path): nothing hard-deletes a route — route sync upserts — so the
/// cascade never fires during normal operation, and it still gives correct
/// cleanup if a route is ever purged.
@TableIndex(name: 'idx_location_samples_route', columns: {#routeId})
@TableIndex(name: 'idx_location_samples_timestamp', columns: {#timestamp})
@DataClassName('LocationSampleRow')
class LocationSamples extends Table with SyncableTable {
  @override
  String get tableName => 'location_samples';

  // Restored explicitly: drift_dev 2.31.0 + analyzer 10.2.0 silently emit no
  // foreign keys from `references()` (docs/blueprint/web-architecture.md section 8).
  // The `references()` call is kept — it still drives drift's Dart-side
  // relation API — but the SQL constraint now comes from here. Remove this
  // override once the generator is fixed, and verify with the FK tests.
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE',
      ];

  TextColumn get routeId =>
      text().references(Routes, #id, onDelete: KeyAction.cascade)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real()();
  RealColumn get speed => real()();
  RealColumn get heading => real()();
  RealColumn get altitude => real()();
  DateTimeColumn get timestamp => dateTime()();

  /// True when the OS reported the fix as mock/simulated — an anti-fraud signal,
  /// never silently dropped.
  BoolColumn get isMocked => boolean().withDefault(const Constant(false))();
}

/// Fraud signals raised during route execution (geofence breach, mocked GPS).
///
/// Keeps `route_id` (see [LocationSamples]) but **not** `stop_id` (ADR-011):
/// route sync replaces a route's stops on every run, and the cascade from
/// `route_stops` silently deleted compliance evidence the rep had captured and
/// not yet pushed. Losing a fraud flag because a route refreshed is precisely
/// the outcome the flag exists to prevent.
@TableIndex(name: 'idx_fraud_flags_route', columns: {#routeId})
@DataClassName('FraudFlagRow')
class FraudFlags extends Table with SyncableTable {
  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE',
      ];

  @override
  String get tableName => 'fraud_flags';

  TextColumn get routeId =>
      text().references(Routes, #id, onDelete: KeyAction.cascade)();

  /// Nullable: a flag can belong to a whole route rather than one stop.
  TextColumn get stopId => text().nullable()();
  TextColumn get type => text()();
  TextColumn get detail => text()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
}

/// Ad hoc visit requests the rep has made that the server has not yet
/// acknowledged (`docs/feature/my-visits/ad-hoc-visits-mobile.md` §7).
///
/// ## Why this is persisted rather than held in memory
///
/// Creating an ad hoc visit is the one operation in this app that genuinely
/// requires connectivity: the server owns stop ids, so there is nothing to
/// check in against until it has issued one. What *can* be made offline-safe is
/// the identity of the request. [id] is the `clientRequestId`, written here
/// **before the first attempt** and reused on every retry, so a retry after a
/// crash, a kill or a week offline replays the same request rather than
/// creating a second visit. A new id on retry is a new visit — precisely the
/// duplicate the field exists to prevent.
///
/// Rows are deleted on success (including the server's `created: false`
/// replay, which is also success) and on a business rejection, which is not
/// retryable. Only transport failures survive a drain.
///
/// No `SyncableTable`: this is an outbox with its own lifecycle, not an entity
/// that is mirrored from the server. No foreign key to `depots` either
/// (ADR-011) — a queued request must survive the depot directory resyncing
/// underneath it.
@DataClassName('AdHocVisitQueueRow')
class AdHocVisitQueue extends Table {
  @override
  String get tableName => 'ad_hoc_visit_queue';

  /// The `clientRequestId` — a v4 uuid generated once per user tap. It is the
  /// primary key because it *is* the request's identity, on both sides.
  TextColumn get id => text()();

  TextColumn get depotId => text()();

  /// Carried so the pending row can name the shop without a directory lookup
  /// that may fail offline — "Adding Toul Kork Yard…" is the whole point of
  /// showing a pending row rather than an untappable card.
  TextColumn get depotName => text()();

  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  /// The last `ApiError.code` seen, e.g. `Visit.AdHocNotAllowed`. The **code
  /// only** — never the server's detail, which is written for developers and
  /// can quote payload values.
  TextColumn get lastErrorCode => text().nullable()();

  /// The depot's SAP code — what the endpoint is actually keyed on (`sk`,
  /// `ad-hoc-visits-mobile.md` §4). Stored so a replay sends the identical
  /// body. [depotId] is kept alongside it only to route a 409 to the stop the
  /// rep already has.
  ///
  /// Declared last because v26 added it with `ALTER TABLE ADD COLUMN`, which
  /// appends — a fresh install must match an upgraded one column for column.
  ///
  /// Nullable since schema v26: rows queued before then have none and cannot
  /// be sent, so the drain drops them rather than guessing a code.
  TextColumn get sk => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Delta-sync cursor for the route domain — mirrors the existing
/// `DepotSyncMeta` / `CatalogSyncMeta` pattern.
///
/// A cursor table, not a syncable entity: it has nothing to push, so it
/// deliberately does not use [SyncableTable] (`docs/blueprint/local-storage-architecture.md` §3.1).
@DataClassName('RouteSyncMetaRow')
class RouteSyncMeta extends Table {
  @override
  String get tableName => 'route_sync_meta';

  TextColumn get entity => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}
