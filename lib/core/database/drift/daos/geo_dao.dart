import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/geo_tables.dart';

part 'geo_dao.g.dart';

/// Scoped accessor for the bundled administrative gazetteer (ADR-004).
///
/// Every query here is read-only except [replaceAll], which the first-run seed
/// import calls once. The tables are effectively immutable reference data, so
/// there is no sync queue, no soft delete and no `updatedAt` — a new gazetteer
/// ships as a new asset version and replaces the lot.
///
/// ## Why searching is SQL and not Dart
///
/// 14,372 villages will not be pulled into memory to be filtered with
/// `where()`. Each level's list is fetched already narrowed by its parent —
/// at most 33 villages for any one commune — and the cross-level searches run
/// as indexed `LIKE` scans. That keeps the widget's job to rendering a list
/// that is already the right length.
@DriftAccessor(
  tables: [GeoProvinces, GeoDistricts, GeoCommunes, GeoVillages],
)
class GeoDao extends DatabaseAccessor<AppDatabase> with _$GeoDaoMixin {
  GeoDao(super.db);

  // ── Reads ────────────────────────────────────────────────────────────

  /// All 25 provinces, ordered by code so the list is stable across languages.
  ///
  /// Ordering by code rather than by name is deliberate: sorting by name would
  /// reorder the whole list when the rep switches to Khmer, and a rep who has
  /// learned where their province sits would have to hunt for it again.
  Future<List<GeoProvinceRow>> allProvinces() =>
      (select(geoProvinces)..orderBy([(t) => OrderingTerm(expression: t.code)]))
          .get();

  Future<List<GeoDistrictRow>> districtsOf(String provinceCode) =>
      (select(geoDistricts)
            ..where((t) => t.provinceCode.equals(provinceCode))
            ..orderBy([(t) => OrderingTerm(expression: t.code)]))
          .get();

  Future<List<GeoCommuneRow>> communesOf(String districtCode) =>
      (select(geoCommunes)
            ..where((t) => t.districtCode.equals(districtCode))
            ..orderBy([(t) => OrderingTerm(expression: t.code)]))
          .get();

  Future<List<GeoVillageRow>> villagesOf(String communeCode) =>
      (select(geoVillages)
            ..where((t) => t.communeCode.equals(communeCode))
            ..orderBy([(t) => OrderingTerm(expression: t.code)]))
          .get();

  // ── Single-row lookups, for rehydrating a saved address ──────────────

  Future<GeoProvinceRow?> province(String code) =>
      (select(geoProvinces)..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  Future<GeoDistrictRow?> district(String code) =>
      (select(geoDistricts)..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  Future<GeoCommuneRow?> commune(String code) =>
      (select(geoCommunes)..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  Future<GeoVillageRow?> village(String code) =>
      (select(geoVillages)..where((t) => t.code.equals(code)))
          .getSingleOrNull();

  // ── Search ───────────────────────────────────────────────────────────

  /// Provinces matching [query] in either language, or by code.
  ///
  /// Both languages are searched regardless of the active locale: a rep typing
  /// `ភ្នំពេញ` with the UI in English is looking for Phnom Penh, and returning
  /// nothing would be a bug. Same reasoning as `LocalizedText.searchable`.
  Future<List<GeoProvinceRow>> searchProvinces(String query) {
    final q = _like(query);
    return (select(geoProvinces)
          ..where((t) => t.nameEn.like(q) | t.nameKm.like(q) | t.code.like(q))
          ..orderBy([(t) => OrderingTerm(expression: t.code)]))
        .get();
  }

  /// Villages inside [communeCode] matching [query].
  ///
  /// Scoped to the commune, so this is a filter over at most 33 rows. There is
  /// deliberately no global village search on the cascade path — "Ou Thum"
  /// names 41 different villages, and a list of 41 identically-named rows is
  /// not a usable answer. [searchCommunes] is the level where a broad text
  /// search is meaningful.
  Future<List<GeoVillageRow>> searchVillagesIn(
    String communeCode,
    String query,
  ) {
    final q = _like(query);
    return (select(geoVillages)
          ..where((t) =>
              t.communeCode.equals(communeCode) &
              (t.nameEn.like(q) | t.nameKm.like(q) | t.code.like(q)))
          ..orderBy([(t) => OrderingTerm(expression: t.code)]))
        .get();
  }

  /// Communes matching [query] by name, code **or postal code**, anywhere in
  /// the country — capped at [limit].
  ///
  /// This backs "I know the postal code, find me the place", which is the one
  /// search a rep does that does not start at the province. The cap exists
  /// because a one-character query matches thousands of rows and nobody scrolls
  /// them; the UI tells the rep to type more rather than paginating a list that
  /// is not useful at that length.
  Future<List<GeoCommuneRow>> searchCommunes(String query, {int limit = 50}) {
    final q = _like(query);
    return (select(geoCommunes)
          ..where((t) =>
              t.nameEn.like(q) |
              t.nameKm.like(q) |
              t.code.like(q) |
              t.postalCode.like(q))
          ..orderBy([(t) => OrderingTerm(expression: t.code)])
          ..limit(limit))
        .get();
  }

  /// The commune carrying exactly [postalCode], or null.
  ///
  /// Cambodia Post assigns one code per commune and no two communes in the
  /// shipped gazetteer share one, so this is a genuine reverse lookup rather
  /// than a best guess. It is what lets a resumed server draft — which stores
  /// `city`, `district` and `postalCode` but has no commune field — put the
  /// commune selection back on screen instead of making the rep re-pick it.
  Future<GeoCommuneRow?> communeByPostalCode(String postalCode) =>
      (select(geoCommunes)..where((t) => t.postalCode.equals(postalCode)))
          .getSingleOrNull();

  /// `LIKE` is case-insensitive for ASCII in SQLite by default, which covers
  /// the Latin transliterations. Khmer has no case, so it needs nothing.
  String _like(String query) => '%${query.trim()}%';

  // ── Seeding ──────────────────────────────────────────────────────────

  Future<int> provinceCount() async {
    final row = await (selectOnly(geoProvinces)
          ..addColumns([geoProvinces.code.count()]))
        .getSingle();
    return row.read(geoProvinces.code.count()) ?? 0;
  }

  /// Replaces the entire gazetteer in one transaction.
  ///
  /// All-or-nothing because a half-imported gazetteer is worse than an empty
  /// one: the selector would offer a province whose districts had not landed
  /// yet, and the rep would conclude their district does not exist. If the
  /// transaction aborts, [provinceCount] still reads 0 and the next launch
  /// retries the import.
  ///
  /// Batched inserts — 16,000 individual statements take seconds; one batch
  /// per level takes tens of milliseconds.
  Future<void> replaceAll({
    required List<GeoProvincesCompanion> provinces,
    required List<GeoDistrictsCompanion> districts,
    required List<GeoCommunesCompanion> communes,
    required List<GeoVillagesCompanion> villages,
  }) {
    return transaction(() async {
      // Deleted deepest-first so an interrupted delete never leaves a child
      // row whose parent is already gone.
      await delete(geoVillages).go();
      await delete(geoCommunes).go();
      await delete(geoDistricts).go();
      await delete(geoProvinces).go();

      await batch((b) {
        b.insertAll(geoProvinces, provinces);
        b.insertAll(geoDistricts, districts);
        b.insertAll(geoCommunes, communes);
        b.insertAll(geoVillages, villages);
      });
    });
  }
}
