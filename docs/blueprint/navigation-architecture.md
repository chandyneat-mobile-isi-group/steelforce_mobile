# Navigation Architecture

> **Purpose:** the complete map of how a user reaches every surface — named
> routes, the shell's tabs, push deep links, and resumable-workflow dispatch.
> **Source:** `lib/routes/`, `lib/features/shell/presentation/main_shell.dart`,
> `lib/core/notifications/notification_deep_link.dart`,
> `lib/features/my_visits/presentation/navigation/` on 2026-08-27.

---

## The model: Navigator 1.0, three navigation systems

This app does **not** use a declarative router (`go_router`, `Navigator` 2.0).
It runs three cooperating mechanisms, and knowing which one owns a transition is
the difference between a one-line change and a redirect race.

| # | Mechanism | Owns | Entry point |
|---|---|---|---|
| 1 | **Named routes** via `onGenerateRoute` | Cold boot, auth flows, deep links from outside the app | `AppPages.onGenerateRoute` |
| 2 | **`MainShell` `IndexedStack`** | Movement between the four main tabs | `MainShell._index` |
| 3 | **Imperative `Navigator.push`** | Everything inside a feature (stop → dashboard → quotation) | per-feature `navigation/` helpers |

Everything a named route builds is wrapped in `LocalizedBuilder` by `_page()`,
so a language change rebuilds the whole subtree live — one place, app-wide.
An unrecognised route name renders a `_NotFound` screen rather than throwing.

---

## Route table

Constants live in `lib/routes/app_routes.dart` as `Static.*` — plain strings
with no framework dependency.

| Route | Screen | Notes |
|---|---|---|
| `/` | `SplashScreen` | Cold boot. Reads `isOnboardingComplete` and routes on. |
| `/choose-language` | `LanguageSelectionScreen` | First run only; doubles as the first onboarding step. |
| `/onboarding` | `OnboardingScreen` | First run only. Finishing or skipping flips `isOnboardingComplete`, after which this is unreachable. |
| `/login` | `LoginScreen` | `AuthBloc` is provided at the root, not here. |
| `/forgot-password` | `ForgotPasswordScreen` | ⚠ backend mocked |
| `/verify-otp` | `VerifyScreen` | Takes `VerifyOtpArgs`. ⚠ backend mocked |
| `/create-new-password` | `CreateNewPasswordScreen` | ⚠ backend mocked |
| `/reset-password-success` | `SuccessScreen` | ⚠ backend mocked |
| `/main` | **`MainShell`** | The bottom-nav container. The normal resting route for both guests and signed-in reps. |
| `/profile` | `ProfileScreen` | Gated by `AuthGuard`; also reachable from the shell app bar. |
| `/notifications` | `NotificationsScreen` | `NotificationDeepLink.inboxRoute` |
| `/settings/notifications` | `NotificationPreferencesScreen` | `NotificationDeepLink.notificationSettingsRoute` |
| `/home` | `HomeScreen` | **Deep-link entry into a single tab.** Provides its own `HomeCubit`. |
| `/order` | `OrderScreen` | Deep-link entry into a single tab. |
| `/my-visits` | `StopDashboardScreen` | Deep-link entry; provides `ActiveRouteBloc`, `LocationTrackingCubit`, `VisitCubit`. |
| `/depot` | — | Declared in `Static`, **no `onGenerateRoute` case**. Navigating here yields `_NotFound`. |
| `/lead` | — | Declared, **not routed**. |
| `/revenue` | — | Declared, **not routed**. |

> Three declared constants (`depot`, `lead`, `revenue`) have no handler.
> They are reachable only through the shell's tabs today. Either wire them or
> delete them — a declared route that renders `_NotFound` is a trap for the next
> person adding a push payload.

### Why single-tab routes exist

`/home`, `/order`, `/my-visits` bypass `MainShell` and build one screen
directly, each providing its own blocs because it is reached without the
shell's providers above it. They exist for push notifications and external
deep links, **not** for in-app navigation, which stays on the `IndexedStack`.

---

## `MainShell` — the four tabs

```
┌─────────────────────────── MainShell ────────────────────────────┐
│  AppBar: title · notifications bell · profile (AuthGuard-gated)  │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│   IndexedStack (all four tabs stay built — state is preserved)    │
│                                                                  │
├──────────────────────────────────────────────────────────────────┤
│  ▣ home.title  │  ◕ depots.title  │  ⌖ my_visits.title  │  ▤ orders.title │
└──────────────────────────────────────────────────────────────────┘
```

| Index | Icon | Label key | Feature |
|--:|---|---|---|
| 0 | `grid_view_rounded` | `home.title` | `home` |
| 1 | `people_alt_rounded` | `depots.title` | `depots` |
| 2 | `location_on_rounded` | `my_visits.title` | `my_visits` |
| 3 | `receipt_long_rounded` | `orders.title` | `order` |

Two deliberate constraints, both the result of real regressions:

- **`IndexedStack` is unkeyed and not wrapped in `AnimatedSwitcher`.** The
  switcher only animates when the child's *type or key* changes, so wrapping an
  unkeyed `IndexedStack` animated nothing while discarding the tab state the
  `IndexedStack` exists to preserve.
- **`_index` is clamped** (`if (_index >= _tabs.length) _index = 0`) so a tab
  count change cannot produce an out-of-range build.

Switching to tab 0 refreshes `ResumableVisitCubit`, which is how a rep sees a
resumable visit banner without a manual pull.

---

## Routing decisions are owned per surface

There is **no** global auth listener driving navigation. A global listener
yanked guests around and produced duplicate redirects. Each surface owns its own
transition instead:

| Trigger | Owner | Destination |
|---|---|---|
| Cold boot | `SplashScreen` | `/main` or `/choose-language` |
| Onboarding complete | `LanguageSelectionScreen._continue` | `/main` (as guest) |
| Login success | `LoginScreen` `BlocListener` | `/main`, stack cleared |
| Logout | `ProfileScreen._confirmLogout` | pops to `/main` as guest |
| Language change / app restart | `app.dart` `_resolveInitialRoute` | auth + onboarding aware; `_splashShown` latch prevents splash replay |

Full detail, including the guest-first login prompt:
[authentication-architecture.md](authentication-architecture.md#boot--navigation-flow).

---

## Push deep links

`NotificationDeepLink` (`lib/core/notifications/`) translates a notification
payload into a route.

```
push payload / notification tap
        │
        ▼
NotificationDeepLink.parse       scheme: app://
        │
        ├── app://notifications   ──▶  /notifications           (inbox)
        └── …                     ──▶  /settings/notifications  (preferences)
        │
        ▼
navigatorKey.currentState.pushNamed(...)
```

`navigatorKey` is a `GlobalKey<NavigatorState>` in `app_routes.dart` — it exists
so a notification arriving outside the widget tree can still navigate.
Coverage: `test/core/notifications/notification_deep_link_test.dart`.

---

## Resumable workflows (`my_visits`)

A visit interrupted by a process kill, dead battery, or an incoming call resumes
where it left off. The persisted pointer is a screen key plus a JSON argument
blob ([../adr/ADR-0007-workflow-session.md](../adr/ADR-0007-workflow-session.md)),
and `resume_workflow_dispatcher.dart` holds **the single registry** mapping that
key back to a live screen.

```
WorkflowStateDao  ──▶  ActiveWorkflow { routeName, navigationArguments }
                              │
                              ▼
                   _navigationRegistry[routeName]
                              │
        ┌─────────────────────┼─────────────────────┐
        │ args valid          │                     │ args missing/invalid
        ▼                     ▼                     ▼
  push that screen     (per-screen builder)   fall back to guided
                                              stop resume
```

Registered resume targets:

| Key | Resumes into |
|---|---|
| `StopInformationScreen.routeName` | Stop review, using stop context |
| `InventoryVisibilityScreen.routeName` | Depot stock visual audit |
| `InventoryCompletionScreen.routeName` | Audit completion |
| `QuotationBuilderScreen.routeName` | Quotation being built for the stop |
| `ShopListScreen.routeName` | Sales-order shop list |
| `DepotDetailScreen.routeName` | Depot detail |

A builder returning `null` (missing or stale args — e.g. the stop was
reassigned) is not an error: the dispatcher degrades to guided stop resume
rather than routing to a screen that cannot render. `VisitWorkflow.salesOrder`
maps to `ShopListScreen` through `_screenForWorkflow`.

Adding a resumable screen means adding one registry entry — never a new
resume mechanism.

---

## Rules

1. **Never add a global auth/navigation listener.** Give the new surface its own
   transition.
2. **Gate at the tap site**, with `AuthGuard` / `context.requireAuth()` — never
   inside a repository.
3. **A new `Static` constant needs an `onGenerateRoute` case** in the same
   change, or it silently renders `_NotFound`.
4. **A new resumable screen needs a `_navigationRegistry` entry**, and its
   builder must return `null` on invalid args rather than throwing.
5. **Deep-link routes provide their own blocs** — they are reached without
   `MainShell`'s providers above them.

---

## Related

- [authentication-architecture.md](authentication-architecture.md) — boot flow, guest gating, session state machine
- [feature-architecture.md](feature-architecture.md) — which feature owns which screen
- [../adr/ADR-0007-workflow-session.md](../adr/ADR-0007-workflow-session.md) — why resume is a generalized session
- [../feature/notification/README.md](../feature/notification/README.md) — payload shapes behind the deep links
- [../feature/shell/ui-upgrade-plan.md](../feature/shell/ui-upgrade-plan.md) — planned changes to the shell surfaces
