import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/depot_related_tables.dart';
import 'package:steelforce/core/database/drift/tables/depots_table.dart';
import 'package:steelforce/core/utils/text_normalization.dart';

part 'depot_dao.g.dart';

/// Sort options for [DepotDao.browse]. Declared here so the core DAO stays
/// decoupled from the feature's domain enum; the repository maps between them.
enum DepotBrowseSort { recentOrder, nameAsc, nearest, valueDesc }

/// A SAP depot plus its contacts, the unit the sync upsert writes atomically.
class DepotWithContacts {
  const DepotWithContacts(this.depot, this.contacts);
  final DepotsCompanion depot;
  final List<DepotContactsCompanion> contacts;
}

/// Scoped accessor for the whole depot directory (master + child tables).
/// All depot reads exclude soft-deleted rows.
@DriftAccessor(
  tables: [
    Depots,
    DepotContacts,
    DepotNotes,
    DepotActivities,
    DepotFavorites,
    DepotRecent,
    DepotSyncMeta,
  ],
)
class DepotDao extends DatabaseAccessor<AppDatabase> with _$DepotDaoMixin {
  DepotDao(super.db);

  // ── Directory reads ────────────────────────────────────────────────

  /// Paginated browse mirroring the legacy data source: returns up to
  /// `pageSize + 1` rows so the caller can detect "has more" without a COUNT.
  /// Search is a case-insensitive LIKE across name/code/owner/phone (FTS5 is a
  /// planned optimization, tracked separately).
  Future<List<Depot>> browse({
    required int page,
    required int pageSize,
    String query = '',
    String? territory,
    String? status,
    String? productCategory,
    String? salesOrg,
    String? division,
    DepotBrowseSort sort = DepotBrowseSort.nameAsc,
  }) {
    final statement = select(depots)
      ..where((t) {
        var cond = t.deleted.equals(false);
        if (territory != null) cond = cond & t.territory.equals(territory);
        if (status != null) cond = cond & t.status.equals(status);
        if (productCategory != null) {
          cond = cond & t.productsPurchased.like('%$productCategory%');
        }
        // Sales area (schema v9). Index-backed — see idx_depots_sales_org /
        // idx_depots_division. Equality, not LIKE: these are SAP codes, so a
        // partial match would silently widen the filter.
        if (salesOrg != null) cond = cond & t.salesOrg.equals(salesOrg);
        if (division != null) cond = cond & t.division.equals(division);
        // Zero-width characters are stripped from the term here and from the
        // name columns in SQL below, mirroring what the server does. Without
        // it, roughly a fifth of Khmer names are unfindable by typing the
        // name shown on screen — see `stripZeroWidth`.
        final trimmed = normalizeSearchTerm(query);
        if (trimmed.isNotEmpty) {
          // SQLite's LIKE is already case-insensitive for ASCII, which covers
          // the codes and Latin names searched here. Khmer has no case, so
          // folding is a no-op on those columns.
          final like = '%$trimmed%';
          cond = cond &
              (_searchable(t.shopName).like(like) |
                  t.depotCode.like(like) |
                  t.ownerName.like(like) |
                  t.phone.like(like) |
                  // v9 fields — the brief's requirement that typing "PRD" or
                  // "Steel" finds depots by sales area, not just by name.
                  _searchable(t.enName).like(like) |
                  _searchable(t.khName).like(like) |
                  t.salesOrg.like(like) |
                  t.division.like(like));
        }
        return cond;
      })
      ..orderBy([(t) => _ordering(t, sort)])
      ..limit(pageSize + 1, offset: page * pageSize);
    return statement.get();
  }

  /// A name column with SAP's zero-width word-break hints removed, for
  /// comparison against an equally-stripped search term.
  ///
  /// Emits nested `replace()` calls rather than normalising on write, because
  /// the stored value must stay byte-identical to what SAP sent: it is what the
  /// list renders, and a delivery note carries the shopfront name exactly as
  /// the ERP holds it.
  ///
  /// The term itself is still a bound parameter — the column name is the only
  /// thing interpolated, and it comes from the generated schema, never from
  /// user input.
  Expression<String> _searchable(GeneratedColumn<String> column) {
    Expression<String> stripped = column;
    for (final character in kZeroWidthCharacters) {
      stripped = FunctionCallExpression('replace', [
        stripped,
        Variable<String>(character),
        const Constant<String>(''),
      ]);
    }
    return stripped;
  }

  OrderingTerm _ordering($DepotsTable t, DepotBrowseSort sort) {
    return switch (sort) {
      DepotBrowseSort.recentOrder =>
        OrderingTerm(expression: t.lastOrderDate, mode: OrderingMode.desc),
      DepotBrowseSort.nameAsc => OrderingTerm(expression: t.shopName),
      // Distance is computed client-side from GPS; fall back to freshness.
      DepotBrowseSort.nearest =>
        OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      DepotBrowseSort.valueDesc =>
        OrderingTerm(expression: t.lifetimeValue, mode: OrderingMode.desc),
    };
  }

  Stream<List<Depot>> watchByTerritory(String territory) {
    return (select(depots)
          ..where(
              (t) => t.territory.equals(territory) & t.deleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.shopName)]))
        .watch();
  }

  Future<Depot?> getById(String id) {
    return (select(depots)
          ..where((t) => t.id.equals(id) & t.deleted.equals(false)))
        .getSingleOrNull();
  }

  Future<List<DepotContact>> fetchContacts(String depotId) {
    return (select(depotContacts)..where((t) => t.depotId.equals(depotId)))
        .get();
  }

  Future<int> countByTerritory(String territory) async {
    final countExp = depots.id.count();
    final query = selectOnly(depots)
      ..where(depots.territory.equals(territory) & depots.deleted.equals(false))
      ..addColumns([countExp]);
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  // ── Sync writes (the only path that populates depots/contacts) ───

  /// Atomically replaces each depot and its contacts. Mirrors the legacy
  /// transactional upsert (minus the FTS index, handled by [browse]'s LIKE).
  Future<void> upsertDepots(List<DepotWithContacts> records) async {
    if (records.isEmpty) return;
    await transaction(() async {
      for (final record in records) {
        final id = record.depot.id.value;
        await into(depots)
            .insert(record.depot, onConflict: DoUpdate((_) => record.depot));
        await (delete(depotContacts)..where((t) => t.depotId.equals(id))).go();
        for (final contact in record.contacts) {
          await into(depotContacts).insert(contact);
        }
      }
    });
  }

  Future<void> markDeleted(List<String> ids) async {
    if (ids.isEmpty) return;
    await (update(depots)..where((t) => t.id.isIn(ids)))
        .write(const DepotsCompanion(deleted: Value(true)));
  }

  Future<int> softDelete(String id) {
    return (update(depots)..where((t) => t.id.equals(id)))
        .write(const DepotsCompanion(deleted: Value(true)));
  }

  // ── Notes (rep-owned) ──────────────────────────────────────────────

  Future<List<DepotNote>> fetchNotes(String depotId) {
    return (select(depotNotes)
          ..where((t) => t.depotId.equals(depotId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<void> addNote(DepotNotesCompanion note) =>
      into(depotNotes).insert(note);

  // ── Activities (rep-owned) ─────────────────────────────────────────

  Future<List<DepotActivity>> fetchActivities(String depotId) {
    return (select(depotActivities)
          ..where((t) => t.depotId.equals(depotId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  Future<void> addActivity(DepotActivitiesCompanion activity) =>
      into(depotActivities).insert(activity);

  // ── Favorites / recent (local UI state) ────────────────────────────

  Future<void> toggleFavorite(String depotId) async {
    final existing = await (select(depotFavorites)
          ..where((t) => t.depotId.equals(depotId)))
        .getSingleOrNull();
    if (existing != null) {
      await (delete(depotFavorites)..where((t) => t.depotId.equals(depotId)))
          .go();
    } else {
      await into(depotFavorites).insert(
        DepotFavoritesCompanion.insert(
          depotId: depotId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<List<Depot>> fetchFavorites() {
    final query = select(depotFavorites).join([
      innerJoin(depots, depots.id.equalsExp(depotFavorites.depotId)),
    ])
      ..where(depots.deleted.equals(false))
      ..orderBy([
        OrderingTerm(
            expression: depotFavorites.createdAt, mode: OrderingMode.desc)
      ]);
    return query.map((row) => row.readTable(depots)).get();
  }

  Future<void> recordViewed(String depotId) {
    return into(depotRecent).insertOnConflictUpdate(
      DepotRecentCompanion.insert(
        depotId: depotId,
        viewedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<List<Depot>> fetchRecent({int limit = 20}) {
    final query = select(depotRecent).join([
      innerJoin(depots, depots.id.equalsExp(depotRecent.depotId)),
    ])
      ..where(depots.deleted.equals(false))
      ..orderBy([
        OrderingTerm(expression: depotRecent.viewedAt, mode: OrderingMode.desc)
      ])
      ..limit(limit);
    return query.map((row) => row.readTable(depots)).get();
  }

  // ── Sync metadata ──────────────────────────────────────────────────

  Future<DateTime?> getLastSyncedAt(String entity) async {
    final row = await (select(depotSyncMeta)
          ..where((t) => t.entity.equals(entity)))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  /// Records the watermark and, when supplied, the language the rows were
  /// fetched under. The two are written together on purpose: a watermark that
  /// outlived its language would let a delta resume against rows localised for
  /// a language the user is no longer reading.
  Future<void> setLastSyncedAt(
    String entity,
    DateTime at, {
    String? language,
  }) {
    return into(depotSyncMeta).insertOnConflictUpdate(
      DepotSyncMetaCompanion.insert(
        entity: entity,
        lastSyncedAt: Value(at),
        syncedLanguage:
            language == null ? const Value.absent() : Value(language),
      ),
    );
  }

  /// The `Accept-Language` tag the stored rows were fetched under, or null for
  /// a book synced before the column existed.
  Future<String?> getSyncedLanguage(String entity) async {
    final row = await (select(depotSyncMeta)
          ..where((t) => t.entity.equals(entity)))
        .getSingleOrNull();
    return row?.syncedLanguage;
  }
}
