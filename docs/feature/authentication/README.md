# Authentication — Feature Blueprint

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> Status: **Built (guest-first core) / Partial (password-reset flows are UI-only mocks)**
> Version 1.0 · Generated 2026-07-23 from the actual implementation (`lib/features/authentication/`, `lib/core/{auth,session,middleware,network}/`) via Graphify analysis.
> Companion documents: [Architecture](architecture.md) · [Workflow](workflow.md) · [Overview](overview.md) · [Technical Design](technical-design.md) · [API](api.md) · [Database](data-model.md) · [Security](security.md) · [QA Test Plan](testing.md) · [UAT](uat.md) · [Use Cases](use-cases.md) · [Business Rules](business-rules.md) · [Changelog](changelog.md) · [Implementation Checklist](implementation-checklist.md) · [Roadmap](roadmap.md)
> Canonical flow narrative (pre-existing): `docs/blueprint/authentication-architecture.md`

---

## 1. Purpose

Provide **guest-first, offline-first identity** for a field sales force. Users can explore the entire app without an account; a signed-in session unlocks protected actions (orders, cart, checkout, profile, history, notifications). A previously signed-in user boots fully offline from a cached session — **no network call stands between app-open and usable app**.

## 2. Business Goal

Field sales reps in Cambodia routinely work hours without connectivity. The business needs:

- Zero-friction evaluation of the app (guest browsing) for new reps and prospects.
- Reps who signed in once to stay productive with **no connectivity at all** (cached session boot).
- A single, trustworthy answer to "who is signed in" that drives role checks, feature gating, and (eventually) sync scoping to SAP.

## 3. Problem Statement

| Problem | Consequence without this feature |
|---|---|
| Forcing login at startup blocks offline users whose token needs refresh | App unusable in the field |
| Per-screen ad-hoc `isAuthenticated` checks | Gating logic drifts, inconsistent UX |
| Global auth-redirect listeners | Guests yanked between screens, duplicate redirects (tried and reverted — see `docs/blueprint/offline-architecture.md` §2.2) |
| Token handling duplicated between repository and HTTP layer | Token drift, refresh stampedes |

## 4. Objectives

1. Guest is a **first-class resting state** (`AuthGuestState`), not an error.
2. Session restore on boot resolves **locally** (secure-storage cached user + token) with zero required network calls.
3. One synchronous source of truth (`SessionManager`) for guards, roles, and future sync scopes.
4. One reusable gate (`AuthGuard` / `context.requireAuth`) for every protected feature.
5. Transparent token attach + single-flight refresh at the network layer (`AuthInterceptor`).
6. Full localization (en + km) and light/dark theming across all auth surfaces.

## 5. Business Value

- **Field productivity**: reps never lose access to their data because of connectivity.
- **Adoption funnel**: guest browsing lowers the barrier to first use; login friction appears only at the moment of a protected action.
- **Security posture**: tokens and cached user live exclusively in `flutter_secure_storage` (Keychain/Keystore) — aligned with `docs/skills/security.md` §3.
- **Engineering leverage**: the pattern is the documented reference implementation that every other offline flow copies (`docs/blueprint/offline-architecture.md` §2).

## 6. Target Users

| User | Need |
|---|---|
| Field sales rep (`UserRole.salesRep`) | Sign in once, work offline all day |
| Sales manager (`UserRole.manager`) | Same, plus (future) team-level views |
| Administrator (`UserRole.admin`) | Same, plus (future) admin functions |
| Guest (`UserRole.guest`) | Browse catalog/app without an account |
| QA / internal testers | Mock credentials for release-candidate testing (see gap G-1 in §12) |

## 7. Roles & Permissions

`UserRole` enum: `admin`, `manager`, `salesRep`, `guest` ([user_role.dart](../../../lib/features/authentication/domain/entities/user_role.dart)).

- A `User` carries a `Set<UserRole>`; helpers `hasRole` / `hasAnyRole` / `hasAllRoles` / `primaryRole` (defaults to `guest` when the set is empty).
- `SessionManager` exposes synchronous `can(role)` / `canAny` / `canAll`; with no user, `roles` = `{guest}`.
- **Current implementation**: no screen performs per-role branching yet — gating is binary (authenticated vs. guest) via `AuthGuard`. Role-based RBAC is declared "Missing — needed for RBAC" in `docs/blueprint/offline-architecture.md` §4 (Organization/Role/Permission row).

## 8. Dependencies

| Dependency | Direction | Notes |
|---|---|---|
| `core/session/session_manager.dart` | auth → core | In-memory session singleton, mirrored by `AuthBloc` |
| `core/auth/{auth_guard,login_required_dialog}.dart` | features → core | Gate + prompt consumed by shell, notifications, guest widgets |
| `core/middleware/app_middleware.dart` (`TokenStore`, `AuthInterceptor`) | auth implements `TokenStore` | Interceptor declared in core to avoid a circular dependency |
| `core/network/app_network.dart` (`AppNetwork`, `Env.apiBaseUrl`) | auth → core | Authed Dio built per feature registration |
| `core/network/connectivity/network_info.dart` | auth → core | Fail-fast connectivity check for login |
| `flutter_secure_storage` | data layer | Tokens + cached user only |
| `flutter_bloc`, `bloc_concurrency`, `equatable`, `get_it`, `dio`, `json_annotation` | packages | Standard stack |
| **Not used**: Drift, Hive, sync queue | — | Auth stores nothing in the database; `onboarding_complete` (Hive) is owned by splash/onboarding, not this feature |

## 9. Architecture (summary)

Clean Architecture triad, inward dependencies only — full detail in [Architecture.md](architecture.md):

```
presentation (AuthBloc, 5 screens, widgets)
    → domain (User, AuthToken, AuthRepository, Login/Logout/GetCurrentUser)
        → data (AuthRepositoryImpl, AuthRemoteDataSource, AuthLocalDataSource)
```

Cross-cutting collaborators live in `core/`: `SessionManager`, `AuthGuard`, `LoginRequiredDialog`, `AuthInterceptor`/`TokenStore`, `AppNetwork`, `NetworkInfo`.

## 10. Feature Scope

**In scope (built and wired):**

- Login with email-or-phone identifier + password (`LoginScreen` → `AuthBloc` → `Login` use case).
- Boot-time session restore (`AuthCheckRequested` → `GetCurrentUser`, offline-first).
- Explicit guest entry (`AuthGuestRequested`) and logout (`LogoutRequested`, best-effort server revocation).
- Auth gating for protected features (`AuthGuard`, `LoginRequiredDialog`).
- Bearer-token attach + single-flight refresh + one replay on 401 (`AuthInterceptor`).
- Localized (en/km), themed (light/dark) auth UI: Login, Forgot Password, Verify OTP, Create New Password, Success.

**In scope but currently mock/UI-only (see §12):**

- Forgot-password request, OTP verification, password reset — screens are complete but wired to `TODO` placeholder callbacks in `lib/routes/app_page.dart` (simulated delays; OTP `111111` accepted).
- Remote login has a hardcoded mock credential branch (`tester@gmail.com` / `tester@12345`).

## 11. Out of Scope

- Role-based authorization / RBAC enforcement per screen (future — needs Organization/Role/Permission sync).
- Biometric unlock, SSO, MFA beyond the OTP reset step.
- Registration / self-service account creation (`onRequestAccess` hook exists on `LoginScreen` but is unwired).
- Server-side session management, token issuance (backend concern).
- Database encryption keys — related storage keys (`isi.db_device_key*`) live in the same secure store but belong to the database feature (`docs/blueprint/local-storage-architecture.md` §2).

## 12. Gap Analysis (Current vs. Intended)

| ID | Current implementation | Intended behavior | Recommendation |
|---|---|---|---|
| G-1 | Hardcoded mock login in [auth_remote_data_source.dart](../../../lib/features/authentication/data/datasources/auth_remote_data_source.dart) (`tester@gmail.com`/`tester@12345`) — **not tagged `// TODO(release-gate):`** | Debug-only shortcuts must carry the release-gate tag and never ship (`docs/skills/security.md` §11) | Tag immediately; move behind a debug-only flag; add CI grep gate |
| G-2 | Forgot-password / OTP / reset are mock callbacks in `app_page.dart` (OTP `111111`) | Real endpoints via AuthBloc events (`VerifyOtpRequestedEvent`, `ResetPasswordRequestedEvent` — named in code comments, not yet implemented) | Implement domain use cases + repo methods + bloc events when backend exists; tag mocks `// TODO(release-gate):` |
| G-3 | **Zero automated tests** for the auth feature (no `test/features/authentication/`) | Domain ≥ 90%, data ≥ 80% coverage (`docs/skills/engineering-standard.md` §10) | Highest-priority test debt; see [QA_Test_Plan.md](testing.md) §8 |
| G-4 | `NetworkInfo` is an interface-up check (`connectivity_plus`) | ADR-005: real reachability probe | Tracked at core level; login fail-fast inherits the fix |
| G-5 | `AuthInterceptor` clears tokens on failed refresh but does not notify `AuthBloc`/`SessionManager` | UI should degrade to Guest when the session dies mid-use | Emit a session-expired signal (e.g. via `SessionManager.changes`) → `UnauthenticatedState` |
| G-6 | `LoginSubmittedEvent.email` carries email **or** phone (noted in a `LoginScreen` comment) | Param named for what it holds | Rename to `identifier` when backend distinguishes the two |
| G-7 | Mock user has empty `roles` set → `primaryRole` = `guest` even when authenticated | Server returns real roles | Resolved automatically with real backend; add contract test |
| G-8 | `docs/blueprint/authentication-architecture.md` §4 says copy lives in `en.json` and `kh.json` | Locale files are `assets/lang/en.json` + `km.json` (kh→km migration completed) | Doc corrected by this package; treat `km` as canonical |

## 13. Future Roadmap

See [Roadmap.md](roadmap.md). Highlights: real backend wiring for reset flows (removes G-2), session-expiry propagation (G-5), RBAC once role sync exists, biometric quick-unlock, auth telemetry.

## 14. KPIs / Success Metrics

| Metric | Target | Source |
|---|---|---|
| Cold boot → interactive shell (cached session, offline) | < 2 s, zero network calls | Boot trace |
| Login success rate (online, valid credentials) | > 99% | API + client telemetry (future) |
| Duplicate login submissions | 0 (enforced by `droppable()` transformer) | Bloc behavior |
| Token refresh storms (N refreshes for N parallel 401s) | 0 (single-flight `_refreshCompleter`) | Interceptor design |
| Guests reaching a protected action who complete login | Track conversion (future analytics) | `LoginRequiredDialog` result |
| Auth-feature test coverage | domain ≥ 90% / data ≥ 80% (currently 0% — G-3) | CI |
