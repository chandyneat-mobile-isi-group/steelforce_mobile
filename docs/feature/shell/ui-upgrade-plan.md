# Shell UI Upgrade Plan

> **Scope:** every UI surface under `lib/features/shell/` — the app bar, home
> content, KPI screen, sync widgets, guest surfaces, and the sheets they open.
> **Gate:** `docs/skills/feature-ui-standard.md`. Every task below cites the rule it
> satisfies; nothing here is taste.
>
> **Status:** proposed, not started. Phase 0 needs one decision (§4) before code.

---

## 1. Goal

Cards now size correctly on tablet, but **type does not**, and the **app bar is
still phone-only**. This plan finishes the shell so it satisfies the Definition
of Done (`docs/skills/feature-ui-standard.md` §15) at 390 / 600 / 834 / 1032 / 1280 / 1440pt,
in English and Khmer, light and dark.

Non-goal: redesigning the information architecture. The "My Work" grid launcher
stays; Leads remains cut.

---

## 2. Current state — measured, not guessed

18 shell files declare `fontSize:`. **~88 declarations, only 10 responsive.**

| File | Lines | `fontSize:` | bare `.sp` | `context.rsp()` | Priority |
|---|---:|---:|---:|---:|---|
| `continue_working_card.dart` | 826 | 11 | 15 | 0 | P2 |
| `add_depot_bottom_sheet.dart` | 777 | 14 | 15 | 0 | P2 |
| `kpi_screen.dart` | 672 | 18 | 23 | 0 | P2 |
| `main_shell.dart` | 569 | 2 | 0 | 2 | ✅ done |
| `my_work_grid_section.dart` | 494 | 3 | 2 | 1 | 🟡 partial |
| **`main_app_bar.dart`** | **435** | **4** | **8** | **0** | **P0** |
| `monthly_target_widget.dart` | 362 | 4 | 1 | 4 | ✅ done |
| `pending_sync_sheet.dart` | 310 | 7 | 0 | 0 | P2 |
| `continue_visit_card.dart` | 309 | 6 | 9 | 0 | P1 |
| `guest_cta_card.dart` | 294 | 1 | 0 | 0 | P1 |
| `guest_my_work_grid.dart` | 276 | 3 | 0 | 3 | ✅ done |
| `quick_action_widget.dart` | 228 | 2 | 2 | 0 | P1 |
| `continue_action_widget.dart` | 196 | 5 | 5 | 0 | P1 |
| `guest_feature_preview.dart` | 180 | 3 | 0 | 0 | P1 |
| `guest_quick_action_grid.dart` | 158 | 2 | 2 | 0 | P1 |
| `connectivity_banner.dart` | 126 | 1 | 2 | 0 | P1 |
| `pending_sync_badge.dart` | 87 | 1 | 3 | 0 | P1 |
| `data_syncing_widget.dart` | 88 | 1 | 0 | 0 | P1 |

Seven files exceed the 300-line limit in **FS-MNT-2**.

---

## 3. Why text still reads too small — two causes, not one

Fixing only the first will not solve it.

**Cause A — the type scale is deliberately conservative.**
`responsive_sizing.dart` uses `typeScale` 1.0 / 1.15 / **1.25**. At 1032pt a
14pt label becomes 17.5pt. That is *correct but timid* for a canvas 2.6× wider
than the phone it was designed for.

**Cause B — text sits in over-wide containers.**
At 1032pt the 2-column grid yields **~494pt-wide cards** holding centred 17.5pt
labels. Even correctly sized type looks lost at that ratio. This is **FS-RSP-7**
("a tablet is not a stretched phone") and **FS-RSP-5** (content must be clamped).

**Cause C — most of the shell never scales at all.** 78 of 88 font sizes are
still bare `.sp`, which above 600pt means a *literal* phone-sized value.

---

## 4. ✅ DECIDED — type scale raised 30% (Phase 0.1 shipped)

My 1.25/1.35 proposal was rejected on device as still too small. **Applied
instead: the whole curve ×1.30.**

| Size class | Was | **Now** |
|---|---|---|
| compact | 1.00 | **1.00** (phone baseline frozen — unchanged, asserted by test) |
| medium (834pt) | 1.15 | **1.50** |
| expanded (1032pt+) | 1.25 | **1.63** |

Measured effect at 1032pt:

| Role | Design | Was | **Now** |
|---|---:|---:|---:|
| Badge / caption | 10 | 12.5 | **16.3** |
| Secondary label | 13 | 16.3 | **21.2** |
| Card label / body | 14 | 17.5 | **22.8** |
| App bar title | 18 | 22.5 | **29.3** |
| KPI figure | 24 | 30.0 | **39.1** |

**Type now outruns `boxScale` (1.63 > 1.45), and that is intentional.** The
cards were already judged correctly sized, so only type moved. The old
"boxes grow faster than type" assertion was replaced by a **fit** test —
card content uses 116pt of a 180pt box at 1032pt.

> The lever is one constant. Do **not** compensate by hand-tuning individual
> widgets — that is how the 88 hardcoded sizes happened.

⚠️ **Only affects the ~10 call sites already migrated to `context.rsp`.** The
other 78 hardcoded sizes — including the entire app bar — do not move until
Phases 1–3.

---

## 5. Phases

### Phase 0 — Foundation (blocks everything else)

| # | Task | Rule |
|---|---|---|
| 0.1 | Raise `typeScale` to 1.25 / 1.35 in `responsive_sizing.dart`; update its doc table and test expectations | FS-VIS-3 |
| 0.2 | Add gold palette as real tokens (`AppThemeColors.goldLight/goldPrimary/goldDark`) — currently copy-pasted as raw hex in ≥4 shell files, and **twice inside `main_app_bar.dart` alone** | FS-VIS-2, FS-MNT-6 |
| 0.3 | Add `context.rIcon(double)` for icon sizes — icons are currently sized with `.sp`, which is semantically wrong (they are boxes, not type) and makes them scale on the type curve | FS-VIS-7 |
| 0.4 | Clamp the home content column with `ResponsiveContentFrame` (max ~900pt) so cards stop reaching 494pt | FS-RSP-5, FS-RSP-7 |
| 0.5 | Extend `AppTypography.textTheme` into a responsive scale so widgets can migrate to `Theme.of(context).textTheme.titleMedium` instead of `fontSize:` | FS-VIS-3 |

**Exit:** phone rendering bit-identical (existing test), tablet type visibly larger, no new analyzer issues.

---

### Phase 1 — MainAppBar (your stated priority)

`main_app_bar.dart`, 435 lines. Ten defects, all rule-backed:

| # | Defect | Evidence | Rule |
|---|---|---|---|
| 1.1 | Title `18.sp`, icons `16/18/20.sp`, language rows `13/10.sp` — none responsive | lines 118, 81, 232, 199, 210 | FS-RSP-3 |
| 1.2 | Logo fixed `height: 40.h, width: 140.w` — stays phone-sized on a 1032pt bar | line 107 | FS-RSP-3 |
| 1.3 | `PopupMenuItem(height: 44.h)` — **below the 48dp minimum touch target** | line 182 | FS-UX-3 |
| 1.4 | Gold palette declared as raw hex **twice in one file** | lines 33-35, 320 | FS-VIS-2, FS-MNT-6 |
| 1.5 | Badge gradient raw hex `0xFFEF4444` / `0xFFB91C1C` | line 402 | FS-VIS-2 |
| 1.6 | `const Duration(milliseconds: 200)` instead of `AppDurations` | line 44 | FS-ANI-1 |
| 1.7 | Icon-only buttons (back, language, notifications, avatar) lack `Semantics` labels | throughout | FS-A11Y-1 |
| 1.8 | Title `Text` has no `maxLines`/`overflow` guard — Khmer runs longer and clips | line 114 | FS-LOC-4, FS-A11Y-2 |
| 1.9 | Language names/regions at 10–13pt are unreadable at tablet distance | lines 199, 210 | FS-VIS-3 |
| 1.10 | 435 lines, three responsibilities (bar, medallion, language menu) | whole file | FS-MNT-2 |

**Work:**
1. Migrate every dimension to `context.rsp/rr/rIcon/rh` and the gold tokens.
2. Raise `PopupMenuItem` height to `context.rh(48)` minimum.
3. Bar height itself becomes responsive so the 70/80pt clearances in
   `main_shell.dart` stay correct — **these are coupled; change together.**
4. Add `Semantics` labels + tooltips to all four icon actions.
5. `maxLines: 1` + `TextOverflow.ellipsis` on the title.
6. Split into `main_app_bar.dart` (composition), `app_bar_medallion_button.dart`,
   `app_bar_language_menu.dart`.

**Exit:** app bar legible and proportionate at 1032pt; touch targets ≥48dp;
zero raw hex; Khmer title does not clip.

---

### Phase 2 — Remaining home surfaces (P1 files)

Mechanical migration of the eight P1 files to `rsp/rr/rh/pagePadding` + tokens.
Each is small (≤310 lines). Batch as one PR per logical group:

- **Sync group** — `connectivity_banner`, `pending_sync_badge`,
  `data_syncing_widget`, `continue_visit_card`, `continue_action_widget`
- **Guest group** — `guest_cta_card`, `guest_feature_preview`,
  `guest_quick_action_grid`
- **Actions** — `quick_action_widget`

Rules: FS-RSP-3, FS-VIS-2, FS-VIS-3, FS-UX-3.

---

### Phase 3 — Heavy screens (P2)

| File | Extra work beyond migration |
|---|---|
| `kpi_screen.dart` (672) | `crossAxisCount: 2` → `SliverGridDelegateWithMaxCrossAxisExtent` (**FS-RSP-4**); charts need explicit tablet sizing |
| `continue_working_card.dart` (826) | `MediaQuery.of(context).size.height * 0.75` → constraints (**FS-PRF-4**, FS-RSP-1) |
| `pending_sync_sheet.dart` (310) | same `.size.height * 0.8` pattern; sheet should become a constrained dialog ≥600pt (**FS-UX-4**) |
| `add_depot_bottom_sheet.dart` (777) | form fields need max-width; multi-column ≥834pt (**FS-RSP-5**) |

---

### Phase 4 — Structural debt (FS-MNT-2)

Split the seven >300-line files. **Do this last** — splitting before the sizing
migration doubles the diff and makes review harder.

---

### Phase 5 — Lock it in

| # | Task | Rule |
|---|---|---|
| 5.1 | Golden tests for app bar + home at 390 / 834 / 1032 / 1440, light + dark | FS-RSP-8 |
| 5.2 | Widget test: no overflow at 200% `textScaleFactor` | FS-A11Y-2 |
| 5.3 | Khmer clipping test for app bar title and card labels | FS-LOC-4 |
| 5.4 | Test asserting no bare `.sp`/`.h`/`.w` remains under `features/shell` | FS-RSP-3 |
| 5.5 | `graphify update .` | FS-MNT-8 |

---

## 6. Sequencing and risk

```
Phase 0 ──► Phase 1 (app bar) ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5
   │             │
   │             └─ couples to main_shell.dart top insets (70/80pt)
   └─ typeScale change touches every screen already migrated
```

| Risk | Mitigation |
|---|---|
| Raising `typeScale` shifts already-migrated surfaces | Compact is unchanged and asserted by test; only tablet moves, which is the goal |
| App bar height change breaks `main_shell` clearances | Change both in one PR; screenshot home + a non-home tab |
| Khmer text grows with type scale and clips | FS-LOC-4 test in Phase 5; `maxLines` guards in Phase 1 |
| Large diffs hide regressions | One phase per PR; golden tests before Phase 4 splits |
| Hardcoded demo data still renders | Out of scope here, tracked as **FS-NN-5** — `'Sokha Novel'`, `targetAmount: 1000000` |

---

## 7. Verification protocol (every phase)

```bash
flutter analyze                 # zero new issues (baseline: 17)
flutter test                    # all pass
flutter build apk --debug       # Pixel Tablet 800pt
flutter build ios --simulator --debug   # iPad Pro 13" 1032pt
```

Screenshots required per phase: **phone 390 + tablet 1032, light + dark, en + km.**
Then tick `docs/skills/feature-ui-standard.md` §14 in the PR.

---

## 8. Effort estimate

| Phase | Files | Size |
|---|---:|---|
| 0 — Foundation | 4 | S |
| 1 — MainAppBar | 1 → 3 | M |
| 2 — P1 surfaces | 9 | M |
| 3 — Heavy screens | 4 | L |
| 4 — Splits | 7 | M |
| 5 — Tests | ~6 new | M |

Phases 0+1 deliver most of the visible improvement and are independently
shippable.
