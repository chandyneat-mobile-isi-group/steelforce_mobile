# Offline-First Engine Design

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> How the app behaves with no, intermittent, or recovering connectivity. Implements `docs/skills/engineering-standard.md`; persistence detail in `docs/blueprint/local-storage-architecture.md`; the sync half of this story is `docs/blueprint/sync-architecture.md`.

---

## 1. Principle

**Connectivity is the exception the UI plans for, not an error state.** The local encrypted Drift database is the single source of truth for every screen: reads always come from local data (populated by prior sync or direct capture), and writes always land locally first, inside a transaction that also enqueues the sync work needed to eventually reach the server (see `docs/blueprint/sync-architecture.md` §2). The user is never blocked on a network round-trip to see their own data or record a new one.

This applies uniformly: browsing the catalog, opening a depot, starting a route, filling a stock count, or drafting a quotation must all work identically whether the device is online, offline, or transitioning between the two.

---

## 2. Offline-first identity: guest-first authentication

Authentication is the clearest existing example of the pattern and the reference implementation for everything else. It is **built and working today**; new offline flows should copy its shape.

### 2.1 Boot flow

```
Splash Screen
     │  (reads onboarding_complete from Hive)
     ├───────────── not complete ─────────────┐
     │                                         ▼
     │                                  Language Selection (= onboarding)
     │                                         │  "Let's go" → onboarding_complete = true
     │                                         │  enters Guest if not signed in
     │                                         ▼
     └───────────── complete ─────────────►  MainShell
                                              │
        AuthBloc.AuthCheckRequested (on boot) resolves in the background:
            cached session ─► Authenticated  (SessionManager.setUser)
            no session      ─► Guest          (SessionManager.clear)
```

Both signed-in and guest users land on `MainShell` — nobody is forced through a login screen at startup, because that would make the app unusable offline for anyone whose token happens to need a refresh. `AppCoach` never auto-launches.

### 2.2 Who owns each transition

Routing is deliberately **not** driven by one global auth listener — that caused guests to be redirect-looped. Each surface owns its own transition instead:

| Trigger | Owner | Destination |
|---|---|---|
| Cold boot | `SplashScreen` | `main` or `chooseLanguage`, by `onboarding_complete` |
| Onboarding done | `LanguageSelectionScreen._continue` | `main` (enters Guest) |
| Login success | `LoginScreen` `BlocListener` | `main` (stack cleared) |
| Logout | `ProfileScreen._confirmLogout` | Pops to `main` as Guest |
| App restart / language change | `app.dart _resolveInitialRoute` | Auth- and onboarding-aware; re-run on every `MaterialApp` rebuild so language changes never replay the splash |

### 2.3 State model

`AuthBloc` (`features/authentication/presentation/bloc/`) is the single orchestrator. Every state change is mirrored into the app-wide `SessionManager` DI singleton, so guards, role checks, and sync scoping all read one synchronous source of truth instead of each subscribing to the bloc.

| State | Meaning |
|---|---|
| `AuthInitialState` | Idle, before the boot check runs |
| `AuthLoadingState` | A request is in flight |
| `AuthenticatedState(user)` | A valid session exists |
| `AuthGuestState` | **Browsing without an account — the default resting state** |
| `UnauthenticatedState` | Transient "must re-authenticate" signal |
| `AuthFailureState(message)` | A login attempt failed |

### 2.4 The reusable guard

`core/auth/auth_guard.dart` is the **one** place feature gating lives — never inline an `isAuthenticated` check in a screen.

```dart
// Explicit
if (await AuthGuard.requireAuthentication(context)) { openCheckout(); }

// Ergonomic extension
await context.requireAuth(onAuthenticated: openCheckout);
```

Guests attempting a gated action (create order, cart, checkout, profile, history, notifications, saved items) see `core/auth/login_required_dialog.dart` — a Material 3 prompt with **"Login Now"** and **"Later"**; declining leaves the user exactly where they were, still browsing offline data. `MainShell._openProfile` is the reference implementation.

### 2.5 Storage split (why this boots offline)

| Value | Store | Notes |
|---|---|---|
| `onboarding_complete` | Hive | Non-sensitive; falls back to `false` safely |
| `access_token` / `refresh_token` | `flutter_secure_storage` | Encrypted; read by repo + network interceptor |
| Cached user | `flutter_secure_storage` | JSON; is what lets a signed-in user boot straight into `Authenticated` with zero network calls |

Reads are null-safe end to end: a missing token yields Guest, never a crash.

### 2.6 Why this pattern generalizes

- One synchronous source of truth (`SessionManager`) other systems can query without awaiting.
- One gate (`AuthGuard`), so a new protected feature is a one-line call, not a copy-pasted check.
- Decoupled navigation — each surface owning its transition means adding a flow can't create a redirect race.
- No blocking network calls between "app opens" and "user sees their data."

---

## 3. Resumable workflow (`WorkflowSession`)

Field work is regularly interrupted — battery death, OS process kill, a call coming in mid-visit. `WorkflowSession` exists so the app can put the user back on the exact screen and step they were on, sourced entirely from the local database (not memory, not the OS's fragile state restoration).

### 3.1 What exists today

`ActiveWorkflow` — a single-row resume pointer (`currentScreen` + a JSON `navigationArguments` blob, DB as source of truth) — is scoped to one feature (`my_visits`) and is well designed for that scope: the JSON-blob approach for arguments is forward-compatible across schema changes, which is exactly right for a field that will keep growing.

### 3.2 Gaps to close for an enterprise-wide `WorkflowSession`

| Gap | Why it matters | Fix |
|---|---|---|
| Missing `sessionId`, `userId`, `deviceId`, `startedAt`, `expiresAt`, `version`, `state` | Current schema assumes single-user, no expiry, no versioning | Add explicit columns; `id` should be a UUID/text to match the rest of the app, not an integer |
| No resume validation | Could route back to a deleted/reassigned route or a stop that no longer belongs to this user | On resume, re-verify the referenced entity still exists and still belongs to the current user |
| Recovery edge cases unhandled | Stale/deleted route, route now `completed`, `navigationArguments` shape drifted after an app upgrade | Validate shape defensively; fall back to dashboard rather than crashing on a malformed resume |
| No expiry | Abandoned sessions accumulate forever | TTL / end-of-day auto-close + a resume prompt instead of silent auto-jump |
| Single-user assumption | Device could be shared or re-logged-in | Scope every session row by `userId`; clear on logout |
| Navigation restoration is unguarded | A renamed/removed route name would otherwise crash resume | Guard restoration; fall back to dashboard on any mismatch |

### 3.3 Design to implement

- Generalize `WorkflowSession` as a shared `core/workflow/` entity usable by any feature, not just visits — see `docs/blueprint/system-architecture.md` §5 folder structure.
- A `resume_router` checks for an active, non-expired, still-valid session on boot (after the auth check in §2.1) and offers to resume before falling through to the normal shell.
- Open product question carried over from planning: deprecate the legacy `ActiveRouteScreen` in favor of the guided 4-step flow once `WorkflowSession` is generalized — resolve before Phase 3 (`docs/blueprint/migration-plan.md`) starts.

---

## 4. Per-domain offline posture

Every domain declares upfront how it behaves offline and how it eventually syncs. This table is the offline contract each feature is reviewed against; sync mechanics referenced here are detailed in `docs/blueprint/sync-architecture.md`.

| Domain | Offline behavior | Sync direction | Status |
|---|---|---|---|
| Authentication | Cached user boots the app fully offline | Token refresh only, when online | Built |
| Organization/Role/Permission | Read-mostly cache | Pull | Missing — needed for RBAC |
| Depot/Contact | Full offline read + edit | Pull + delta | Built (migrating off sqflite) |
| Depot master data (SAP Helper lists) | Cache-first from Hive; falls back to a stale copy when offline or SAP is unreachable, badged as stale. Never blocks a screen. | Pull only, on cache miss or explicit refresh (7-day TTL) | Built behind a mock — real source blocked on `core/network/sap_client.dart` (ADR-009) |
| Lead/Opportunity | Offline draft | Push queue | Partial |
| Catalog/Product/Category/PriceBook | Full offline catalog, including search (FTS) | Pull, paged + delta | Built |
| Territory/Route/Visit/Check-in | Full offline | Pull + push telemetry | Built |
| Inventory/Stock Count | Offline capture | Push queue | Built |
| Cart | Local only | None — never leaves the device until converted to a quotation/order | Built |
| Quotation | Local-only until submitted | Push → SAP | Built |
| Sales Order | Local + queued | Push → SAP, conflicts routed to Action-Required | Built (SAP mocked) |
| Attachment/Media | Filesystem + DB reference (Layer 4) | Push binary | Unbuilt |
| Workflow | Local | Status only | Being generalized (§3) |
| Sync (queue/DLQ/cursor) | Local | Is the engine | Core, unbuilt |
| Notification | Local | Pull/push | Scaffolded |
| Dashboard/Reporting | Derived entirely from local data | Derived | UI built, data not real yet |
| Audit | Local | Push | Unbuilt |
| Settings/Profile | Hive | None | Built |

---

## 5. Connectivity handling

- `connectivity_service` exposes a reactive stream of connectivity state — this is a **plugin-interface-up** check today and must become a real reachability probe (an actual request succeeding), not just "the OS reports a network interface." A phone connected to a captive-portal Wi-Fi with no internet must be treated as offline.
- Connectivity is surfaced as a global, non-blocking status pill/banner, plus per-item sync state (queued/syncing/synced/failed) where relevant — never a blocking dialog. Offline is a normal, expected state, not an error screen.
- Regaining connectivity triggers a sync-queue drain automatically (see `docs/blueprint/sync-architecture.md` §6); it does not require the user to manually retry.

---

## 6. Testing offline behavior

Offline correctness is validated with dedicated tests, not just manual QA:

- **Blackout / chaos tests**: toggle connectivity mid-flow (mid-capture, mid-sync-drain, mid-checkout) and assert no data loss and correct UI state.
- **Crash-recovery simulation**: kill the process mid-write and mid-sync, restart, and assert the workflow resumes and the sync queue recovers (`inFlight → queued` on boot — see `docs/blueprint/sync-architecture.md` §7).
- **Acceptance scenario** carried from the blueprint: "battery-death resume" — the app must recover a mid-visit workflow session and a partially-drained sync queue after an unclean shutdown, with zero duplicate submissions and zero silently-dropped captures.

These sit in the Integration and Offline/Sync tiers of the testing matrix in `docs/skills/engineering-standard.md` §10.
