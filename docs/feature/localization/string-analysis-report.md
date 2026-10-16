# Static String Analysis Report — Localization Migration

> ISI Steel Sales Mobile · Generated 2026-07-22 by full-project static analysis
> Method: Graphify dependency-graph orientation (`graphify-out/graph.json`, 664 Dart files) followed by a
> heuristic string-literal classifier over `lib/**` (excluding `*.g.dart` / `*.freezed.dart`).
> Scope note: this work is outside the current `docs/blueprint/migration-plan.md` sprint sequence (T1.x infra);
> executed at explicit product-owner request. It touches presentation + `assets/lang` only — no
> database, sync, or security infrastructure.

---

## 1. Existing localization state (discovered, not assumed)

The app already ships a working key-based i18n system:

| Component | Location | Status |
|---|---|---|
| Translation store (`.tr` / `.trParams`, flattened JSON, ChangeNotifier) | `lib/core/localization/localization_services.dart` | ✅ working |
| Live-rebuild wrapper | `lib/core/localization/localized_builder.dart` | ✅ working |
| `LanguageCubit` (Cubit\<Locale\>) | `lib/features/localization/presentation/bloc/language_cubit.dart` | ⚠️ direct service/prefs access — no domain layer |
| Persistence | Hive `AppPreferences.savedLanguageCode` | ✅ working |
| Language files | `assets/lang/en.json` (487 keys), `assets/lang/kh.json` (485 keys) | ⚠️ `kh` is not a valid ISO 639-1 code; 2 keys missing in Khmer (`auth.title`, `calendar.todays_routes`) |
| Onboarding language screen | `lib/features/splash/presentation/language_selection_screen.dart` | ✅ working (en/kh only) |
| In-app switcher | `lib/features/shell/presentation/widgets/main_app_bar.dart` (bottom sheet) | ⚠️ hardcoded 2-language tiles |
| Profile screen | `lib/features/profile/presentation/screens/profile_screen.dart` | ❌ **no language section at all** |

**Latent bug found:** `AppTypography.fontFamilyForLocale` (lib/core/theme/app_typography.dart:26)
switches to the Khmer font **Kantumruy** only for locale `km`, but the app stores and emits `kh` —
so Khmer users have never received the Khmer font. Migrating the language code `kh → km`
(with a stored-preference migration) fixes this.

`.tr` adoption before this migration: **362 usages across 68 of 664 files.**

## 2. Raw scan results

| Bucket | Strings | Files | Action |
|---|---|---|---|
| Total string-literal candidates | 1,607 | 191 | — |
| Mock/demo data (`data/mock/*`, seed fixtures, demo names/products/cities) | 853 | 58 | **Ignore** (per scope rules: not UI copy; demo data is replaced by SAP data) |
| Dev-facing (asserts, `FlutterError`, `Bearer` headers, camera EXIF stamps) | ~25 | 7 | **Ignore** (never shown to users) |
| Pure interpolation / numeric / coordinate / already-`.tr` fragments | ~324 | — | **Ignore** (no translatable words) |
| **User-facing refactor targets** | **405** | **83** | **Localize** |

## 3. Refactor targets by feature

| Feature | Hardcoded strings | Notes |
|---|---|---|
| Lead / Pipeline | 117 | detail screen (39), form sheet (15), send-to-HQ (14), filter/sort, won sheet, boards |
| Shell (dashboard, quick actions, my-work, guest, sync center) | 100 | sync cards/sheets (48), guest surfaces (20), grids (18) |
| My Visits | 72 | depot stock count, depot selection, stop detail, timeline, forms, route dashboard |
| Orders / Catalog / Quotation | 69 | voice search (9), filters (17), PDF generator (19), sync banner |
| Depots | 28 | detail screen sales-history / cross-sell / opportunity dialogs |
| Home | 8 | greeting, KPI titles, "See All" |
| Authentication | 3 | login status pill |
| Notification | 3 | guest welcome sheet |
| Splash | 2 | brand tagline |
| Routes (not-found page) | 2 | |
| App root | 1 | app title |
| **Total** | **405** | **83 files** |

## 4. Duplicates & reuse

- **78 of 405** strings are *identical* to values that already exist in `en.json` — the keys were
  created but never wired (e.g. `'Add Note'` → `depots.add_note`, the entire hardcoded PDF block
  in `quotation_pdf_generator.dart` → existing `orders.quotation.pdf.*`). These are wired to the
  **existing** keys — no duplicate keys or duplicate translations are created.
- **294 unique new strings** require new keys.
- Most-duplicated hardcoded strings (converted to a single shared key each):
  `Send to HQ` (4×), `Cancel` (4×), `Save`/`Save changes` (4×), `Continue` (4×), `Delete` (4×),
  `No activity yet` (3×), `Clear all` (2×), `Filter & sort` (2×), `Walk-in Depot` (4×),
  `Continue Previous Work` (2×), `MY WORK` (3×), `QUICK ACTIONS` (2×), `Login required` (3×),
  `Something went wrong` (3×), `Delete lead?` (2×), `Check out` (3×).
- Reusable common keys added/used: `common.cancel`, `common.save`, `common.delete`, `common.continue`,
  `common.ok`, `common.search`, `common.clear_all`, `common.not_specified`, `common.optional`.

## 5. Key-naming design

- Structured, feature-first, matching the **existing** hierarchy (`auth.*`, `common.*`, `home.*`,
  `orders.*`, `leads.*`, `depots.*`, `my_visits.*`, `language.*`, `profile.*`, `coach.*`, …).
- New top-level groups introduced: `shell.*` (my-work grid, quick actions, guest surfaces),
  `sync.*` (sync center, pending-sync, connectivity, drafts), `splash.*`, `app.*` (titles/not-found).
- Existing group names are kept even where the task brief suggested different ones
  (`my_visits.*` not `visit.*`, `orders.*` not `order.*`) — consistency with 487 live keys beats
  renaming them all.
- No generic keys (`title1`, `text1`) anywhere; parameterized copy uses `{name}` placeholders via
  `.trParams`.

## 6. Language matrix

| Language | Code | File | Status before | Status after |
|---|---|---|---|---|
| English | `en` | `assets/lang/en.json` | 487 keys | 841 keys (source of truth) |
| Khmer | `km` (was `kh`) | `assets/lang/km.json` (renamed from `kh.json`) | 485 keys | 841 keys — full parity |

**Final migration outcome (verified):** `.tr` adoption grew from 362 usages / 68 files to
**772 usages / 130 files**; 647 distinct keys are referenced from code and every one resolves
in both bundles; `flutter analyze` is at its pre-migration baseline (0 errors, 22 pre-existing
warnings/infos in untouched files). Architecture and extension guide: `docs/skills/localization.md`.

Legacy stored preference `kh` is migrated to `km` transparently on first read.
Adding a future language (e.g. Chinese) is: drop `assets/lang/<code>.json`, add one
`LanguageModel` entry to the `supported` catalog, add its `language.<name>` keys —
nothing else changes.
