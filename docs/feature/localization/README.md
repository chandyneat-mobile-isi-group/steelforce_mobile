# Localization

> **Purpose:** how English and Khmer coexist in this app.
> **Code:** `lib/features/localization/`, `lib/core/localization/`,
> `assets/lang/{en,km}.json`
> **Verified:** 2026-08-27, branch `web` @ `142de9b`.

---

## Where to go

| You want to… | Read |
|---|---|
| **Add or change a string, font, or locale** | [../../skills/localization.md](../../skills/localization.md) — the operational guide. This is almost always the right link. |
| Understand how the current system came to be | [string-analysis-report.md](string-analysis-report.md) — the static analysis of every hard-coded string in `lib/` that produced the migration. |

The guide lives under `skills/` rather than here because localization is
cross-cutting: every feature consumes it, no feature owns it.

---

## The shape of it, briefly

- Two locales ship: `en` and `km`. Defined as `kSupportedLocales` in
  `lib/app.dart`, backed by JSON at `assets/lang/`.
- Lookup is the `.tr` extension on a dotted key (`'depots.title'.tr`).
- **A language change restarts the app.** Every named route is wrapped in
  `LocalizedBuilder` by `AppPages._page()`, so the whole subtree rebuilds live;
  `_resolveInitialRoute` keeps signed-in reps and guests on the shell so the
  splash is never replayed.
- Two font families, strictly complementary: **Source Sans 3** (Latin) has no Khmer
  glyphs and **MiSans Khmer** has no Latin glyphs, so each is registered as the
  other's `fontFamilyFallback`. Never ship one without the other.
- **Master data is stored bilingually** in the encrypted database, so switching
  language does not degrade catalog or depot content.

---

## Tests

`test/core/localization/` — 4 files: locale resolution, localization assets
(every key present in both files), localized-text codec, bilingual mock data.
Plus `test/features/order/catalog_localization_test.dart` and
`product_delta_preserves_khmer_test.dart`, which guards that a delta sync cannot
wipe Khmer content.

Font assets are asserted by `test/core/theme/font_assets_test.dart` — the
`.ttf`-only constraint is real: MiSans Khmer shipped as CFF `.otf` (which the
`pdf` package cannot parse) and was converted, and Source Sans 3 is registered
from its static `.ttf` cuts because `pdf` cannot read its variable font.

---

## Known gaps

- The locale set migrated `kh` → `km`. Any document still referencing
  `assets/lang/kh.json` is stale — the file is `km.json`.
- `string-analysis-report.md` was generated 2026-07-22 against 664 Dart files;
  there are 855 now. Its counts are historical, not current.

---

## Related

- [../../skills/localization.md](../../skills/localization.md) — the how-to
- [../../skills/feature-ui-standard.md](../../skills/feature-ui-standard.md) §9 — the localization merge gate
- [../../blueprint/navigation-architecture.md](../../blueprint/navigation-architecture.md) — why every route is wrapped in `LocalizedBuilder`
