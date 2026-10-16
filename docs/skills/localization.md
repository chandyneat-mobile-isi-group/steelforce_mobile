# Localization Guide

> SteelForce (ISI Steel Sales Mobile) · How the multilingual system works and how to extend it.
> Companion: `docs/feature/localization/string-analysis-report.md` (the migration analysis that produced this system).
> Last updated: 2026-08-06.

---

## 1. Overview

The app ships **English (`en`)** and **Khmer (`km`)**. There are **two independent
mechanisms**, and confusing them is the single most common source of "localization is
broken" reports:

| | **UI copy** | **Master data** |
|---|---|---|
| What | Labels, buttons, errors, empty states | Product / category / depot / lead / stop names |
| Source | `assets/lang/<code>.json` | The record itself, carrying both languages |
| Read via | `'key'.tr` | `context.localized(x.displayName)` |
| Switch cost | Re-read a map | A rebuild — nothing is re-fetched |
| Section | §2–§7 | §8 |

- **1,095 keys** per language file, at parity (`en.json` ⇄ `km.json` diff = ∅, enforced by
  `test/core/localization/localization_assets_test.dart`).
- **Zero hardcoded user-facing strings** in presentation code (brand names like "ISI STEEL"
  and "SteelForce", and unit codes like `Pc`/`Ton`, are deliberately excluded).
- Live, in-place language switching — no restart. Selection persists across launches.

## 2. Architecture

```
presentation                     domain                        data
────────────                     ──────                        ────
LanguageCubit ──────────────────▶ ChangeLanguage ─────────────▶ LanguageRepositoryImpl
(state: Locale, consumed          GetCurrentLanguage             ├─ LanguageLocalDatasource
 by MaterialApp in app.dart)      GetSupportedLanguages           │   (Hive AppPreferences,
LanguageSection /                 RestoreSavedLanguage            │    legacy kh→km migration)
LanguageSelectorSheet             LanguageRepository (interface)  └─ LanguageManager (core)
LanguageSelectionScreen           LanguageEntity                      └─ LocalizationService
MainAppBar language menu                                                 (loads assets/lang/<code>.json,
                                                                          ChangeNotifier → LocalizedBuilder)
```

| Piece | File | Role |
|---|---|---|
| `LocalizationService` | `core/localization/localization_services.dart` | Flattened key store; `'key'.tr` / `'key'.trParams({...})`; notifies on reload |
| `LocalizedBuilder` | `core/localization/localized_builder.dart` | Rebuilds a subtree the instant the language changes |
| `LanguageManager` | `core/localization/language_manager.dart` | The one place that *applies* a language (loads bundle + notifies) |
| `LanguageEntity` | `features/localization/domain/entities/` | Pure value: `code`, `nameKey`, `regionKey`, `flag` |
| `LanguageRepository` | `features/localization/domain/repositories/` | Sync reads (no wrong-language flash on boot), async writes |
| Usecases | `features/localization/domain/usecases/` | `GetCurrentLanguage`, `GetSupportedLanguages`, `ChangeLanguage`, `RestoreSavedLanguage` |
| `LanguageModel` | `features/localization/data/models/` | **The shipped catalog** (`LanguageModel.supported`) + `fromCode` fallback |
| `LanguageLocalDatasource` | `features/localization/data/datasources/` | Hive persistence; migrates legacy stored `kh` → `km` on first read |
| `LanguageRepositoryImpl` | `features/localization/data/repositories/` | Wires datasource + manager; domain sees only entities |
| `LanguageCubit` | `features/localization/presentation/bloc/` | `Cubit<Locale>`; calls usecases only; runs startup restoration |
| DI | `features/localization/localization_injection.dart` | `registerLocalizationFeature(sl)` from `core/di/injection_container.dart` |

**Widgets never touch `LocalizationService` for switching** — they go through
`LanguageCubit` → usecases. Reading (`'key'.tr`) stays on the String extension by design.

## 3. UI surfaces

- **Profile → Language section** (`features/localization/presentation/widgets/language_section.dart`)
  — row showing the active flag + native name; opens the selector sheet.
- **Language selector sheet** (`language_selector_sheet.dart`) — native name, region line, flag,
  animated radio → spinner while switching; the sheet itself re-renders in the new language
  before dismissing.
- **Onboarding** (`features/splash/presentation/language_selection_screen.dart`) and the
  **app-bar menu** (`features/shell/.../main_app_bar.dart`) — both render from
  `LanguageCubit.supportedLanguages`, so they update automatically when the catalog grows.

## 4. Startup restoration

`LanguageCubit` (a lazy singleton provided above `MaterialApp`) seeds its `Locale`
synchronously from the repository, then fire-and-forgets `RestoreSavedLanguage` to load the
bundle. `app.dart` keys `MaterialApp` on `locale.languageCode`, so a language change rebuilds
the navigator and `AppTypography.fontFamilyForLocale` picks **Kantumruy** for `km`
(fixed by the `kh → km` code migration — the old non-ISO `kh` code never matched).

## 5. Key naming rules

- Feature-first, dot-separated: `leads.hq.finish_onboarding`, `my_visits.depot.search_hint`,
  `sync.discard_draft_title`. Cross-feature phrases live in `common.*`
  (`common.cancel`, `common.save`, `common.filter_sort`, `common.any`, …).
- Parameters use `{name}` placeholders resolved with `.trParams`:
  `'sync.checkin_progress'.trParams({'done': done, 'total': total})`.
- Never generic (`title1`, `text1`); never leave a literal English string in a widget.
- `.tr` is **not const** — never place it in a `const` constructor, `const` map, enum
  constructor, or a constructor default. For enums, store the *key* and expose
  `String get label => labelKey.tr` (see `DueUrgency`, `FilterFacet`).

## 6. Adding a string

1. Add the key to **both** `assets/lang/en.json` and `assets/lang/km.json` (nested form).
2. Use `'feature.key'.tr` (or `.trParams`) in the widget.
3. Parity check (CI-able):
   every `'…'.tr` key in `lib/` must exist in `en.json`, and `en.json` ⇄ `km.json`
   key sets must be identical.

## 7. Adding a language (e.g. Chinese later)

1. Drop `assets/lang/<code>.json` (translate from `en.json`; identical key set).
2. Add one `LanguageModel` entry to `LanguageModel.supported`
   (`features/localization/data/models/language_model.dart`).
3. Add its `language.<name>` / `language.<name>_region` keys to **every** bundle.
4. Add the `Locale` to `kSupportedLocales` in `app.dart` — **without this `MaterialApp`
   resolves it back to English and all master data renders Latin** (see §8.2).
5. If the script needs a dedicated font, extend `AppTypography.fontFamilyForLocale`.

Nothing else changes — every selector UI is catalog-driven.

## 8. Master data: one record, both languages

Master data is **not** translated through the key bundles. A product name is not a UI
label — it is data, it changes when SAP changes, and there are ~11,000 of them. Instead
every record carries both languages and the *presentation layer picks at render time*.

### 8.1 The rule

> **One source of truth. Never `products_en.json` + `products_kh.json`.**

Two datasets drift the moment either side is edited: a SKU added to one and not the other
silently disappears when a rep switches language, and every sync has to reconcile N copies
of the same row. SAP already models it correctly — `MaterialDes` and `MaterialDesKH` come
back on the *same* material record — so the app stores it the same way.

### 8.2 `MaterialApp` must declare the locale — `locale:` alone is not enough

**This is the first thing to check when master data renders English in a Khmer session.**

`MaterialApp` does not take `locale:` at face value. It *resolves* it against
`supportedLocales`, which defaults to `[Locale('en','US')]` when unset — so passing
`Locale('km')` to an app that never declared `km` silently resolves to English.

The failure is invisible in exactly the wrong way:

| | Reads locale from | Result when `supportedLocales` is unset |
|---|---|---|
| `'key'.tr` | the global `LocalizationService` singleton | ✅ Khmer |
| `context.localized(...)` | `Localizations.localeOf(context)` | ❌ **English** |

Chrome translated, data not — which looks like missing Khmer *data* and sends you hunting
through generators, assets and sync paths. `app.dart` must therefore carry both:

```dart
supportedLocales: kSupportedLocales,          // const [Locale('en'), Locale('km')]
localizationsDelegates: kLocalizationsDelegates,
```

Both are **public** so `test/core/localization/locale_resolution_test.dart` asserts against
the real lists rather than a copy that could drift. That test includes a negative control
reproducing the broken configuration, so the regression cannot return silently.

Adding a locale to `LanguageModel.supported` **and** a new `assets/lang/<code>.json` is not
enough on its own — it must also go in `kSupportedLocales` (see §7).

> **Third-party delegates.** Flutter's `GlobalMaterialLocalizations` covers Khmer;
> `phone_form_field` does not, and an uncovered delegate makes `MaterialApp` warn on every
> build. `core/localization/fallback_localizations_delegate.dart` wraps those delegates so
> they serve English for `km` — stating explicitly that those few strings are untranslated,
> rather than leaving a permanent console warning that trains everyone to ignore warnings.

### 8.3 The pieces

| Piece | File | Role |
|---|---|---|
| `LocalizedText` | `core/localization/localized_text.dart` | `{en, km}` value type; `resolve(code)` with English fallback; `allValues` for search |
| `LocalizedTextContext` | `core/localization/localized_text_context.dart` | `context.localized(x)` — reads the locale from `Localizations`, **use this in `build()`** |
| `ActiveLanguage` | `core/localization/active_language.dart` | `ActiveLanguage.resolve(x)` — context-free, for blocs / PDFs / background services |
| `LocalizedTextCodec` | `core/localization/localized_text_codec.dart` | The one place that knows how a bilingual field is spelled on the wire (`nameKh` / `name_kh` / `khName`) |

**Do not use `ActiveLanguage` inside `build()`.** It is a plain read with no dependency
registered, so the widget will not rebuild on a language change. `context.localized(...)`
will.

### 8.4 Which entity carries what

| Entity | Latin | Khmer | Accessor |
|---|---|---|---|
| `Product` | `name` (SAP `MaterialDes`) | `nameKh` (`MaterialDesKH`) | `displayName` |
| `Category` | `name.en` | `name.km` | `name` (already a `LocalizedText`) |
| `Depot` | `shopName` | `khName` (SAP `name3`) | `displayName` |
| `DepotStopInfo` | `name` | `nameKh` (projected from the directory) | `displayName` |
| `Lead` | `companyName` | `companyNameKh` | `displayName` |
| `VisitRecord` | `depotName` | `depotNameKh` | `displayName` |

English resolves to the *always-populated* field (`shopName`, not `enName`) so a depot
SAP has thin master data for still renders. Khmer falls back to English when absent — a
Latin name a rep can match against the shop sign beats a blank row.

### 8.5 Search spans both languages, always

Search matches **both** languages regardless of the active locale. A rep who knows a shop
by its Khmer sign types that whether or not the UI is in Khmer; returning nothing would be
a defect, not correct locale handling.

- **SQL**: `DepotDao.browse` and `CatalogDao` both `LIKE` across the Latin *and* Khmer
  columns. `CatalogDao` also sanitises the query with a Unicode-aware pattern
  (`\p{L}\p{N}\p{M}`) — `\w` is ASCII-only and silently deleted every Khmer character,
  which read as "no text filter" and returned the whole catalog.
- **In-memory**: entities expose `searchableValues`, which yields `displayName.allValues`
  plus codes. Used by the stop dashboard and the lead pipeline.

### 8.6 Regenerating the mock assets — not optional

`MockProductRemoteDataSource` serves the **committed asset**
and only fall back to the in-memory generator when the file is *missing*. Editing a
generator without regenerating leaves the app serving the old data, which looks exactly
like "my change didn't work":

```bash
dart run tool/generate_mock_products.dart   # assets/mock/products.json
```

`test/core/localization/bilingual_mock_data_test.dart` fails if either committed asset has
a row without a Khmer name, so a stale asset can no longer ship silently.

### 8.6.1 The local cache is the *third* place data can go stale

Regenerating the asset is still not enough for a device that has already synced. Both sync
repositories only take the full "initial" path when the watermark is null:

```dart
final since = await _local.getLastSyncedAt(entity);
if (since == null) return runInitialSync();   // ← never true again
```

Every later sync is a **delta**, which only carries rows the backend says changed — and
nothing tells it that 11,000 unchanged rows just grew a Khmer name. So there are three
independent staleness layers, and all three must be cleared:

| Layer | Symptom | Remedy |
|---|---|---|
| Generator | New rows have no Khmer | Edit the `_LeafSpec` / name-pair tables |
| Committed asset | App serves the old catalog | `dart run tool/generate_mock_*.dart` |
| **Device's Drift cache** | **App serves the old rows** | `MasterDataLocaleBackfill` |

`core/database/drift/migrations/master_data_locale_backfill.dart` runs once at bootstrap,
clears the three `*_sync_meta` cursors, and records a marker in `app_metadata`. The next
sync then takes the initial path and rewrites every row with both languages. It resets
**cursors only** — no rep-captured data is touched. Bump `markerKey`'s `v1` suffix to
re-arm it if master data is ever widened again.

**A delta must carry every field it rebuilds.** `MockProductRemoteDataSource.fetchDelta`
constructs a fresh `ProductModel`, so any field it omits is *erased*, not preserved.
`nameKh`, `color` and `specification` are all defaulted on the constructor, so leaving them
out compiled cleanly and silently blanked the Khmer name on ~5% of the catalog per sync —
a correctly-synced bilingual catalog decayed back to English the longer the app ran.
`test/features/order/product_delta_preserves_khmer_test.dart` pins this.

### 8.7 Writing the Khmer side

- Generators draw `(en, km)` **pairs** — one random step, both languages — so a generated
  record can never have the two names describing different companies.
- Khmer word order puts the trade before the name: `ហាងគ្រឿងដែក អង្គរ`, not
  `អង្គរ ហាងគ្រឿងដែក`. English is the reverse. Compose accordingly.
- Translate the *meaning*, not the sound: `Golden` → `មាស` (gold), not `ហ្គោលដិន`.
- **Never translate**: brand names (`Schneider`, `Draka`, `ISI PIPE`), size/spec labels
  (`3P 63A`, `1Cx2.5mm2`), grades, material numbers, unit codes. They are SAP vocabulary a
  rep reads identically in either language, and "translating" them makes the Khmer catalog
  un-searchable by part "../../localization"number.

## 9. Deliberate exclusions

- **Brand strings** — "SteelForce" (the app) and "ISI STEEL" (the company) stay Latin in
  every locale, including the PDF `author`/`creator` metadata and file names.
- **Unit codes** (`Pc`, `Ton`, `Kg`, `m`, `mm`) — SAP unit vocabulary.
- **Dev-facing text** (asserts, `FlutterError`, debug-fixture hints, log lines).
- **Persisted document snapshots** — `quotations.shop_name`, `sales_orders.shop_name` and
  the resumable-workflow `shop_name` record the name *as it was when the document was
  raised*. They are frozen history, not live master data, and must not re-resolve.
- **Form input values** — the add-depot sheet prefills `shop_name` from the lead's Latin
  name even in a Khmer session: the field becomes SAP `name1`, which is Latin-only.
- The quotation **PDF** localizes through its own `_l(key, fallback)` helper against
  `orders.quotation.pdf.*`, and product lines through `ActiveLanguage` — a Khmer session
  produces a Khmer document.

## 10. Known follow-ups

- **Activity-log narratives** (`mock_lead_data.dart`, `lead_repository_impl.dart`) are
  English sentence templates — `"{company} moved from Leads to Opportunities."`. Localizing
  them needs parameterised keys per activity kind, which is a separate change from this
  master-data work.
- **`ownerName` / contact names** have no Khmer column in `depots`; adding one is a
  schema migration. Person names are commonly written in Latin in Cambodian business
  systems, so this is deferred rather than forced.
- **`RoutePlan.name`** carries a translation key for mock plans and a verbatim SAP
  description for real ones; `.tr` resolves the former and passes the latter through. If
  SAP ever ships bilingual route descriptions, `routes` needs a `name_kh` column.
- **`km.json` carries 12 orphaned `my_visits.calendar.months.m*` keys** with no English
  counterpart. The code reads top-level `calendar.months.m*`, which is at parity — the
  `my_visits.*` block is dead data and can be dropped.
- **`QuotationPdfService`** (`order/presentation/services/`) is unreferenced dead code with
  hardcoded English headers; the live generator is `order/pdf/quotation_pdf_generator.dart`.
- ~190 keys in the bundles are referenced only dynamically (coach steps via
  `titleKey`/`messageKey`, enum `labelKey`s, notification kinds) — a naive "unused key"
  lint must account for these.
- Widget/golden tests for the language selector (en + km light/dark) per
  `docs/skills/engineering-standard.md` §10 are not yet written.
