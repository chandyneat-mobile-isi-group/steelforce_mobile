# Shell

> **Purpose:** the container every other feature is seen through — `MainShell`,
> its four tabs, the app bar, the KPI screen, the sync widgets, and the guest
> surfaces.
> **Code:** `lib/features/shell/`
> **Verified:** 2026-08-27, branch `web` @ `142de9b`.

Presentation-only by design: 1 screen, 17 widgets, no blocs, no domain or data
layer. The shell composes other features rather than owning data.

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

`test/features/shell/` — `pending_sync_sheet_l10n_test.dart`,
`status_bar_tap_test.dart`.

---

## Known gaps

- The upgrade plan is **not started**, and its Phase 0 decision is still open.
- Guest surfaces have uncommitted work in progress at the time of writing
  (`widgets/guest/*`), including a removed `guest_feature_preview.dart`.

---

## Related

- [../../blueprint/navigation-architecture.md](../../blueprint/navigation-architecture.md) — the tab and route model
- [../../skills/feature-ui-standard.md](../../skills/feature-ui-standard.md) — the gate the upgrade plan is written against
- [../../blueprint/authentication-architecture.md](../../blueprint/authentication-architecture.md#guest-first-gating-the-login-prompt) — why guest surfaces exist
