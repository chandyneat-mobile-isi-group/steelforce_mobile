import 'package:drift/drift.dart';

/// The Cambodian administrative gazetteer — province → district →
/// commune/sangkat → village — plus the commune-level postal code
/// (`docs/feature/geo-location/README.md`).
///
/// ## Why this is a table and not an API cache
///
/// There is no geographic endpoint. `GET /mobile/depots/references` serves
/// exactly ten SAP `CustHelper` catalogues
/// (`docs/feature/depot/registration/sap-helpers.md`) and none of them is
/// geographic, so there is nothing to cache. Before this table the app carried
/// five provinces and one province's districts as `const` maps in
/// `bp_depot_form_data.dart`, which meant a rep in Kampot could not enter
/// their own district.
///
/// The data is therefore **bundled** as `assets/geo/kh_geo_seed_v1.json` and
/// imported here on first run. That is what makes the selector work on a
/// handset that has never had signal — the offline-first requirement in
/// ADR-002 applies to reference data a form cannot be completed without.
///
/// ## Why it lives in the encrypted database
///
/// Not because a village name is a secret — it is public record. Because the
/// address a rep selects becomes part of a depot record, and joining it out
/// of a plaintext side-store would put half of a PII row outside the
/// encryption boundary (`docs/skills/security.md` §3). One database also means the
/// address can be resolved in the same transaction as the depot write.
///
/// ## No foreign keys (ADR-011)
///
/// `provinceCode`, `districtCode` and `communeCode` are plain indexed columns.
/// The hierarchy is validated in the domain layer
/// (`GeoAddress.validateHierarchy`) where a violation can be reported, rather
/// than by a constraint that aborts a write. A re-seed replaces rows level by
/// level; declaring the parent links would make the order of those four
/// statements load-bearing for no benefit the domain check does not give.

/// A province or the capital (25 rows).
@DataClassName('GeoProvinceRow')
class GeoProvinces extends Table {
  @override
  String get tableName => 'geo_provinces';

  /// The two-digit NCDD code (`'12'` = Phnom Penh). **This is the key that is
  /// submitted**, never the display name — a name is localised and a rep can
  /// switch language mid-form.
  TextColumn get code => text()();

  TextColumn get nameEn => text()();
  TextColumn get nameKm => text()();

  /// `Province` or `Capital`. Kept because a Cambodian address writes the two
  /// differently (ខេត្ត vs រាជធានី) and dropping it would render
  /// "Phnom Penh Province", which is wrong.
  TextColumn get unit => text()();

  @override
  Set<Column> get primaryKey => {code};
}

/// A district, municipality (ក្រុង) or khan (ខណ្ឌ) — 203 rows.
@TableIndex(name: 'idx_geo_districts_province', columns: {#provinceCode})
@DataClassName('GeoDistrictRow')
class GeoDistricts extends Table {
  @override
  String get tableName => 'geo_districts';

  /// Four digits; the first two are always [provinceCode].
  TextColumn get code => text()();

  /// Indexed because every read of this table is "the districts of one
  /// province" — the cascade never asks for anything else.
  TextColumn get provinceCode => text()();

  TextColumn get nameEn => text()();
  TextColumn get nameKm => text()();

  /// `District`, `Municipality` or `Khan`.
  TextColumn get unit => text()();

  @override
  Set<Column> get primaryKey => {code};
}

/// A commune (ឃុំ) or sangkat (សង្កាត់) — 1,646 rows.
///
/// **This is the level that carries the postal code.** The specification
/// assumed it hung off the village; Cambodia Post assigns one six-digit code
/// per commune, and every village inside a commune shares it.
@TableIndex(name: 'idx_geo_communes_district', columns: {#districtCode})
@DataClassName('GeoCommuneRow')
class GeoCommunes extends Table {
  @override
  String get tableName => 'geo_communes';

  /// Six digits; the first four are always [districtCode].
  TextColumn get code => text()();

  TextColumn get districtCode => text()();

  /// Denormalised so a province-wide commune search is one indexed scan rather
  /// than a join through `geo_districts`. The gazetteer is read-only between
  /// re-seeds, so the usual argument against denormalisation — the two copies
  /// drifting apart on update — does not apply.
  TextColumn get provinceCode => text()();

  TextColumn get nameEn => text()();
  TextColumn get nameKm => text()();

  /// `Commune` or `Sangkat`.
  TextColumn get unit => text()();

  /// The six-digit Cambodia Post code, or null for the 99 communes the postal
  /// source does not cover unambiguously.
  ///
  /// **Nullable on purpose.** The seed builder joins the postal dataset by name
  /// because its own numbering is not the NCDD numbering, and it drops every
  /// ambiguous match rather than picking one. Null reaches the rep as
  /// "postal code unavailable — enter it manually", which is recoverable; a
  /// guessed code would be silently wrong on a delivery address.
  TextColumn get postalCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {code};
}

/// A village (ភូមិ) — 14,372 rows.
@TableIndex(name: 'idx_geo_villages_commune', columns: {#communeCode})
@DataClassName('GeoVillageRow')
class GeoVillages extends Table {
  @override
  String get tableName => 'geo_villages';

  /// Eight digits; the first six are always [communeCode].
  TextColumn get code => text()();

  TextColumn get communeCode => text()();

  TextColumn get nameEn => text()();
  TextColumn get nameKm => text()();

  @override
  Set<Column> get primaryKey => {code};
}
