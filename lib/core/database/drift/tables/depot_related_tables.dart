import 'package:drift/drift.dart';

/// Child tables of the depot directory, ported from `depots.db` into the
/// single encrypted database (T2). Split by ownership:
///   * server-controlled, replaced on sync: [DepotContacts]
///   * rep-owned, queued for push: [DepotNotes], [DepotActivities]
///   * local UI state: [DepotFavorites], [DepotRecent]
///   * sync bookkeeping: [DepotSyncMeta]
///
/// ## No foreign keys to `depots` (ADR-011, schema v18)
///
/// [depotId] is a plain column, not a foreign key. The backend owns
/// referential integrity for depot data and has already enforced it before
/// the row reaches the device; these tables are a **flat local mirror** whose
/// only job is to store what arrived and render it.
///
/// Re-declaring the constraint here bought nothing and cost real data: rows
/// arrive from independently-paged endpoints in an order the server never
/// promised, so a child row whose parent has not been pulled yet aborted the
/// whole write transaction rather than landing harmlessly. An orphan here is
/// invisible (every read filters by `depot_id`) and self-heals on the next
/// sync — which is strictly better than losing the batch.
///
/// See `docs/adr/ADR011localmirrornorelations.md`.

@TableIndex(name: 'idx_depot_contacts_depot', columns: {#depotId})
class DepotContacts extends Table {
  @override
  String get tableName => 'depot_contacts';

  TextColumn get id => text()();
  TextColumn get depotId => text()();
  TextColumn get name => text()();
  TextColumn get role => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_depot_notes_depot', columns: {#depotId})
class DepotNotes extends Table {
  @override
  String get tableName => 'depot_notes';

  TextColumn get id => text()();
  TextColumn get depotId => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_depot_activities_depot', columns: {#depotId})
class DepotActivities extends Table {
  @override
  String get tableName => 'depot_activities';

  TextColumn get id => text()();
  TextColumn get depotId => text()();
  TextColumn get type => text()();
  TextColumn get summary => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class DepotFavorites extends Table {
  @override
  String get tableName => 'depot_favorites';

  TextColumn get depotId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {depotId};
}

class DepotRecent extends Table {
  @override
  String get tableName => 'depot_recent';

  TextColumn get depotId => text()();
  DateTimeColumn get viewedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {depotId};
}

class DepotSyncMeta extends Table {
  @override
  String get tableName => 'depot_sync_meta';

  TextColumn get entity => text()();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// The `Accept-Language` tag the stored rows were fetched under (`en-US` /
  /// `km-KH`), or null for a book synced before this column existed.
  ///
  /// ## Why the language has to be recorded (schema v21)
  ///
  /// `shopName` is localised **by the server**, against the `Accept-Language`
  /// header of the request that fetched it. A book pulled under `km-KH` holds
  /// Khmer names; the same rows pulled under `en-US` hold Latin ones. The list
  /// summary carries no language-independent name — `enName` and `khName` are
  /// on the detail aggregate only — so the cached row is only correct for the
  /// language it arrived in.
  ///
  /// A delta cannot repair that: `modifiedSince` returns rows the *server*
  /// changed, and switching language on the device changes nothing server-side.
  /// So the directory would keep rendering the old language indefinitely.
  /// Comparing this against the active language turns that into a one-off full
  /// resync (`docs/feature/depot/mobile/get-depot.md` §Local schema).
  TextColumn get syncedLanguage => text().nullable()();

  @override
  Set<Column> get primaryKey => {entity};
}
