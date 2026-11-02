# Shell

> **Purpose:** the container every other feature is seen through — `MainShell`,
> its four tabs, the app bar, the KPI screen, the sync widgets, and the guest
> surfaces.
> **Code:** `lib/features/shell/`
> **Verified:** 2026-10-26, branch `feat/auth` (uncommitted restructure).

Presentation-only by design: no domain or data layer. The shell composes other
features rather than owning data. Its one cubit, `WorkModeCubit`, wraps the
app-wide `WorkModeService`.

Every source file is kept **under 200 lines**, one widget or section per file,
so a style lives in a file named after what it draws.

## Folder map — where to change what

```
presentation/
├── main_shell.dart          tab switching, sync start/stop, permission primer
├── navigation/              ShellTabController + ShellTab indices
├── bloc/                    WorkModeCubit
├── screens/kpi_screen.dart  the KPI screen (composition only)
└── widgets/
    ├── shell_frame/         body layers, tab content, nav rail, app-bar layer, tab list
    ├── app_bar/             MainAppBar and its logo, medallion buttons, bell, avatar
    ├── home/                signed-in Home: welcome header, hero, Home tab
    │   ├── monthly_target/  the monthly target card
    │   └── my_work/         the My Work grid, its cards, badges and skeleton
    ├── guest/               the signed-out landing
    ├── kpi/                 one file per KPI card, tile, row and filter
    └── sync/
        ├── pending_sync/       Sync Center sheet pieces (entry: sync/pending_sync_sheet.dart)
        ├── work_mode/          Online/Offline confirm dialog pieces (entry: sync/work_mode_confirm_dialog.dart)
        └── continue_working/   Continue Working and Continue Visit cards
```

Gold accents come from `AppColors.goldLight / goldPrimary / goldDark / goldDeep
/ goldBorder` (`lib/core/theme/app_colors.dart`). Do not re-declare them as
private hex constants.

---

## Documents

| Document | What it covers |
|---|---|
| [ui-upgrade-plan.md](ui-upgrade-plan.md) | Planned upgrade of every UI surface under `lib/features/shell/`. **Status: proposed, not started** — Phase 0 needs one decision before code. Every task cites the [feature-ui-standard](../../skills/feature-ui-standard.md) rule it satisfies. |

The shell's structural behaviour — the tab model, `IndexedStack` constraints,
route table, and why there is no global auth listener — is documented in
[../../blueprint/navigation-architecture.md](../../blueprint/navigation-architecture.md#mainshell--the-four-tabs)
rather than duplicated here.

---

## What it contains

| Surface | Notes |
|---|---|
| `MainShell` | Bottom-nav container over an unkeyed `IndexedStack`; the resting route (`/main`) for guests and signed-in reps alike |
| App bar | Title, notifications bell, profile entry (gated by `AuthGuard`) |
| `kpi_screen.dart` | The KPI surface |
| Guest surfaces | `widgets/guest/` — the guest home, work grid, and quick-action grid a signed-out rep sees |
| Sync widgets | Pending-sync sheet and status indicators |

Switching to tab 0 refreshes `ResumableVisitCubit`, which is how a rep sees the
"continue where you left off" banner without pulling to refresh.

---

## Tests

`test/features/shell/` — guest home, KPI screen, monthly target format, the
three pending-sync sheet suites, status-bar tap, work-mode button and cubit.
The Continue Working / Continue Visit cards have no widget test yet.

---

## Known gaps

- [ui-upgrade-plan.md](ui-upgrade-plan.md) predates the restructure: its file
  table names old paths and files since removed (`continue_action_widget.dart`,
  `data_syncing_widget.dart`). Phase 0.2 (gold tokens) and Phase 4 (file
  splits) are done.
- `docs/blueprint/navigation-architecture.md` still mentions a `HomeCubit`;
  that cubit was never registered and has been removed.

---

## Related

- [../../blueprint/navigation-architecture.md](../../blueprint/navigation-architecture.md) — the tab and route model
- [../../skills/feature-ui-standard.md](../../skills/feature-ui-standard.md) — the gate the upgrade plan is written against
- [../../blueprint/authentication-architecture.md](../../blueprint/authentication-architecture.md#guest-first-gating-the-login-prompt) — why guest surfaces exist
