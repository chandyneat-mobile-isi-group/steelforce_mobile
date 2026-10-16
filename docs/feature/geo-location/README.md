# Geo Location

> **Purpose:** the Cambodian administrative gazetteer — province → district →
> commune/sangkat → village, plus commune-level postal codes — and every address
> picker built on it.
> **Code:** `lib/features/geo_location/`, `lib/core/database/drift/tables/geo_tables.dart`,
> `lib/core/database/drift/daos/geo_dao.dart`
> **Data:** `assets/geo/kh_geo_seed_v1.json` (~1.3 MB, ~16,000 rows)
> **Verified:** 2026-08-27, branch `web` @ `142de9b`.

---

## What this feature is

An offline address selector. A rep filling in a depot's location picks
province → district → commune → village from a bundled dataset, with the postal
code resolved from the commune. No network call is involved at any point.

Used by: the depot creation and edit forms
([../depot/README.md](../depot/README.md)). It owns no screens of its own —
it contributes widgets that other features embed.

---

## The three decisions that define it

Each is recorded in the code and worth understanding before changing anything.

### 1. It is a bundled table, not an API cache

**There is no geographic endpoint.** `GET /mobile/depots/references` serves
exactly ten SAP `CustHelper` catalogues
([../depot/registration/sap-helpers.md](../depot/registration/sap-helpers.md))
and none of them is geographic — so there is nothing to cache.

Before this table existed, the app carried five provinces and one province's
districts as `const` maps in `bp_depot_form_data.dart`, which meant **a rep in
Kampot could not enter their own district.** The gazetteer is therefore shipped
in the bundle and imported on first use.

[ADR-0002](../../adr/ADR-0002-offline-first.md) applies to reference data a form
cannot be completed without, not just to transactional data.

### 2. It lives in the encrypted database

Not because a village name is secret — it is public record. Because **the address
a rep selects becomes part of a depot record**, and joining it out of a
plaintext side-store would put half of a PII row outside the encryption boundary
([../../skills/security.md](../../skills/security.md) §3). One database also lets
the address be resolved in the same transaction as the depot write.

### 3. It carries no foreign keys

`provinceCode`, `districtCode`, and `communeCode` are plain indexed columns. The
hierarchy is validated in the domain layer by `GeoAddress.validateHierarchy`,
**where a violation can be reported**, rather than by a constraint that aborts the
write. A re-seed replaces rows level by level; declaring parent links would make
the order of those four statements load-bearing for no benefit the domain check
does not already provide.

Per [ADR-0011](../../adr/ADR-0011-local-mirror-no-foreign-keys.md), and asserted
by `test/core/database/drift/foreign_key_schema_test.dart`.

---

## Structure

| Layer | Files |
|---|---|
| **domain/entities** | `geo_address.dart` (the composed address + `validateHierarchy`), `geo_unit.dart` (one level's row) |
| **domain/repositories** | `geo_location_repository.dart` |
| **domain/usecases** | `ensure_geo_data_ready.dart`, `get_geo_children.dart`, `search_geo_units.dart`, `resolve_geo_address.dart` |
| **data** | `geo_local_data_source.dart`, `geo_seed_asset_loader.dart`, `geo_drift_mappers.dart`, `geo_location_repository_impl.dart` |
| **presentation/bloc** | `GeoLocationBloc` + events/state |
| **presentation/widgets** | `geo_location_selector.dart`, `geo_level_field.dart`, `geo_picker_sheet.dart`, `postal_code_field.dart` |
| **DI** | `geo_location_injection.dart` |

The feature imports no device plugin — no `geocoding`, no `geolocator`. It is
pure local data. (`geolocator` is used by `my_visits` and `order` for
positioning; that is a separate concern.)

---

## Tables

`lib/core/database/drift/tables/geo_tables.dart`, reached through `geo_dao.dart`.

| Table | Rows | Key columns |
|---|--:|---|
| `GeoProvinces` | 25 | `code` (PK), `nameEn`, `nameKm`, `unit` |
| `GeoDistricts` | — | `code` (PK), `provinceCode`, `nameEn`, `nameKm`, `unit` |
| `GeoCommunes` | — | `code` (PK), `districtCode`, `provinceCode`, `nameEn`, `nameKm`, `unit`, `postalCode` (nullable) |
| `GeoVillages` | — | `code` (PK), `communeCode`, `nameEn`, `nameKm` |

Every level stores **both** `nameEn` and `nameKm`, so a language switch does not
degrade the address. `unit` carries the administrative unit type (e.g. Krong vs
Srok), which differs by level and matters for display.

`postalCode` sits at commune level and is nullable — not every commune has one.

Introduced by the v19 → v20 migration; covered by
`test/core/database/drift/geo_v19_to_v20_migration_test.dart`.

---

## Seeding

```
selector mounts
      │
      ▼
EnsureGeoDataReady ──▶ repository.ensureSeeded()
      │
      ├── already seeded ──▶ return immediately
      │
      └── not seeded
             │
             ▼
      GeoSeedAssetLoader reads assets/geo/kh_geo_seed_v1.json (~1.3 MB)
             │
             ▼
      ~16,000 inserts, level by level, in one transaction
```

**Seeding happens when the selector mounts, not at startup.** It costs a one-off
~1.3 MB parse and ~16,000 inserts, and most sessions never open an address form —
paying that on every cold start to save it on the rare launch that needs it is
the wrong trade for a handset.

The asset is generated by `tool/geo/build_geo_seed.py`. Regenerating it means a
new versioned filename (`kh_geo_seed_v2.json`) plus a re-seed path, not an
in-place overwrite — the version is in the filename precisely so a stale import
is detectable.

> `pubspec.yaml` must list `assets/geo/` explicitly. Flutter does not recurse
> into subdirectories, so a nested asset is silently absent at runtime.

---

## Offline behaviour

Fully offline, by construction. There is no online path to degrade from.

| Action | Offline |
|---|---|
| Select any administrative level | ✅ |
| Search units by name (either language) | ✅ |
| Resolve a postal code | ✅ |
| First-use seeding | ✅ — reads a bundled asset, not the network |

---

## Tests

`test/features/geo_location/` — 5 files:

| File | Covers |
|---|---|
| `geo_seed_import_test.dart` | The seed parse and insert path |
| `geo_dao_test.dart` | Queries per level |
| `geo_address_test.dart` | `GeoAddress` composition and `validateHierarchy` |
| `geo_location_repository_test.dart` | Repository behaviour |
| `geo_location_bloc_test.dart` | Selector state transitions |

Plus `test/core/database/drift/geo_v19_to_v20_migration_test.dart`.

---

## Known gaps

- **Row counts for districts, communes, and villages are not asserted anywhere.**
  `GeoProvinces` is documented as 25 rows; the other three levels have no
  expected count, so a truncated seed would import silently. A count assertion
  in `geo_seed_import_test.dart` would catch it.
- **No re-seed path for a new dataset version.** `ensureSeeded()` is
  seed-once; shipping `kh_geo_seed_v2.json` needs a migration that clears and
  re-imports, level by level, in the order the no-foreign-keys design assumes.
- **`geocoding` is a declared dependency that nothing uses** — see
  [../../blueprint/device-integration.md](../../blueprint/device-integration.md#unused-declared-dependencies).
  Resolving a coordinate to an address is *not* implemented; this feature only
  resolves a selection to an address.
- **No requirement documents** — which administrative levels are mandatory on a
  depot record is enforced by the form validators alone.

---

## Related

- [../depot/README.md](../depot/README.md) — the feature that embeds this selector
- [../depot/ui-ux.md](../depot/ui-ux.md) — where the address step sits in the BP form
- [../../blueprint/local-storage-architecture.md](../../blueprint/local-storage-architecture.md) — the encrypted database these tables live in
- [../../adr/ADR-0002-offline-first.md](../../adr/ADR-0002-offline-first.md) — why reference data is bundled
- [../../adr/ADR-0011-local-mirror-no-foreign-keys.md](../../adr/ADR-0011-local-mirror-no-foreign-keys.md) — why there are no parent links
- [../../skills/localization.md](../../skills/localization.md) — the bilingual storage pattern these tables follow
