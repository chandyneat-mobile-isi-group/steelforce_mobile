# Authentication Architecture

How the app decides who is signed in, and how a feature gets to call a
protected endpoint without implementing any of it.

**The rule this document exists to enforce:** authentication is a platform
capability, not a feature-level responsibility. A feature author never writes
`checkToken`, `getToken`, `refreshToken`, `handle401` or `redirectLogin`.

---

## Where things live

| Responsibility | File |
|---|---|
| Global lifecycle state, roles, protected-API gate | `core/session/session_manager.dart` |
| Token storage (secure) | `features/authentication/data/datasources/auth_local_data_source.dart` |
| Attach token, refresh on 401, single-flight | `AuthInterceptor`, `core/middleware/app_middleware.dart` |
| `Accept-Language`, `X-Correlation-Id` | `ApiHeadersInterceptor`, same file |
| Client construction (authed vs bare) | `core/network/app_network.dart` |
| Feature-level gate | `core/auth/protected_feature.dart` |
| UI gate + login prompt | `core/auth/auth_guard.dart` |
| Event → use case → session | `features/authentication/presentation/bloc/auth_bloc.dart` |
| Startup resolution | `app.dart` (`AuthCheckRequested`) |

---

## The state machine

`AuthenticationState` (`SessionManager`) is the single globally observable
fact. It is deliberately **synchronous** — a feature deciding whether to issue
a request cannot await a stream first.

```
                    ┌──────────────┐
   app launch  ───▶ │ initializing │
                    └──────┬───────┘
                           │  AuthCheckRequested
              ┌────────────┴────────────┐
     no stored session          stored session valid
              │                          │
              ▼                          ▼
        ┌─────────┐               ┌───────────────┐
        │  guest  │◀──── clear ───│ authenticated │
        └────┬────┘   (sign-out)  └───┬───────┬───┘
             │                        │       │
      login  │                 refresh│       │refresh
             ▼                  starts│       │fails
     ┌────────────────┐               ▼       ▼
     │ authenticating │──▶ ┌──────────────────┐  ┌────────────────┐
     └────────────────┘    │ refreshingToken  │  │ sessionExpired │
                           └──────────────────┘  └────────────────┘
```

`guest` and `sessionExpired` are both "no session", kept apart on purpose: one
is a normal resting state, the other is something the server did to the user,
and the UI should be able to explain the difference rather than silently
presenting a login screen.

`AuthState` (in `AuthBloc`) is **not** this. It is presentation state for the
login screen — spinner, error banner. Features consume `SessionManager`.

---

## The protected-API gate

```dart
bool get canCallProtectedApi =>
    state == AuthenticationState.authenticated ||
    state == AuthenticationState.refreshingToken;
```

Open in exactly two states. `refreshingToken` counts because the session is
still valid — the interceptor holds the request until the new token lands.
Closing it there would make every rotation look like a sign-out.

Everything else — booting, guest, mid-sign-in, expired — means the call can
only fail. Failing it locally costs nothing; failing it at the server costs a
round trip and puts an error banner in front of a user who did nothing wrong.

---

## How to protect a new feature

### Background loads — mix in `ProtectedFeature`

```dart
class QuotationCubit extends Cubit<QuotationState> with ProtectedFeature {
  QuotationCubit({required this.session, required FetchQuotations fetch})
      : _fetch = fetch, super(const QuotationIdle());

  @override
  final SessionManager session;   // injected, never located inside the mixin

  Future<void> load() => whenAuthenticated(() async {
        // only runs with a live session
      });
}
```

Register it with `session: sl<SessionManager>()`.

- `canLoad` — the raw boolean.
- `whenAuthenticated(action)` — runs or silently skips. Correct for background
  loads: a guest has not asked for this data and should not see an error.
- `guardedCall(action)` — returns an `AuthenticationFailure` instead of calling,
  so the caller's existing failure branch says "sign in to continue" rather
  than showing a network error.

### User-triggered actions — `AuthGuard`

```dart
if (await context.requireAuth()) {
  openCheckout();
}
```

Shows the login prompt for guests. Use this at the tap site, not inside the
repository.

### What you do **not** write

Attaching the bearer token, refreshing on 401, retrying, redirecting on
expiry. All of it is in the interceptor. Just resolve `Dio` from the locator —
the default registration is the authenticated client.

---

## Boot & navigation flow

Both **signed-in** and **guest** users land on `MainShell`. Nobody is forced
through the login screen at startup, and AppCoach never auto-launches.

```
Splash Screen
     │  (reads onboarding_complete)
     ├───────────── not complete ─────────────┐
     │                                        ▼
     │                                 Language Selection
     │                                 (= onboarding step)
     │                                        │  "Let's go" →
     │                                        │  set onboarding_complete = true
     │                                        │  enter Guest (if not signed in)
     │                                        ▼
     └───────────── complete ─────────────►  MainShell
                                              │
        AuthBloc.AuthCheckRequested (on boot) resolves in the background:
            cached session ─► authenticated   (SessionManager.setUser)
            no session      ─► guest          (SessionManager.clear)
```

### Routing decisions are owned per surface, not globally

Navigation is deliberately **not** driven by a global auth listener. A global
listener yanked guests around and produced duplicate redirects; each surface
now owns its own transition.

| Trigger | Owner | Destination |
|---|---|---|
| Cold boot | `SplashScreen` | `main` or `chooseLanguage` (by `onboarding_complete`) |
| Onboarding done | `LanguageSelectionScreen._continue` | `main` (enters guest) |
| Login success | `LoginScreen` `BlocListener` | `main` (stack cleared) |
| Logout | `ProfileScreen._confirmLogout` | pops to `main` as guest |
| App restart / language change | `app.dart` `_resolveInitialRoute` | auth + onboarding aware |

`_resolveInitialRoute` re-runs whenever `MaterialApp` rebuilds (e.g. on language
change). It keeps signed-in **and** guest users on the shell — so switching
language mid-session never replays the splash — while showing the splash exactly
once on first cold boot via the `_splashShown` latch.

See [navigation-architecture.md](navigation-architecture.md) for the route table.

---

## Guest-first gating: the login prompt

`core/auth/login_required_dialog.dart` is the one prompt a guest ever sees, and
`AuthGuard` is the only thing that shows it.

- Lock badge, title "Login Required", synced-data description.
- Primary **"Login Now"** → closes, routes to the login screen.
- Secondary **"Later"** → dismisses; the user keeps browsing as a guest.
- Returns a `LoginPromptResult` (`login` / `dismissed`) for callers that care.
- Fade + scale-in (`showGeneralDialog`), width-capped and scroll-safe, fully
  light/dark aware via `ColorScheme` + `AppThemeColors`.
- All copy is localized — `auth.login_required_title`, `auth.login_required_desc`,
  `auth.login_now`, `auth.later` — in both `assets/lang/en.json` and
  `assets/lang/km.json`.

Friction appears exactly when an account is genuinely required, and nowhere
else. That is the whole product argument for the guest resting state: a rep
evaluating the app, or one whose session expired mid-route, is never locked out
of the catalog.

`MainShell._openProfile` is the reference implementation.

---

## Request path

```
feature repository
   │
   ▼
Dio (authed)  ── ApiHeadersInterceptor ── Accept-Language, X-Correlation-Id
   │
   ├── ApiLogInterceptor      (redacted; ahead of auth so a 401 is logged
   │                           before refresh-and-replay swallows it)
   │
   └── AuthInterceptor        Authorization: Bearer <access_token>
```

Two clients:

- **authed** (default `Dio` registration) — feature endpoints.
- **bare** (`instanceName: bareClientName`) — login, refresh, forgot/reset
  password. No auth interceptor, so a 401 from these is the answer rather than
  a stale-token symptom.

`ApiEndpoints.authRoutes` lists the routes the interceptor must never refresh
on. Refreshing there would burn a rotation, and on the login path could spend
one of the five attempts that lock an account.

---

## 401 handling

```
request ──▶ 401 ──▶ already retried? ──yes──▶ surface the error
                          │no
                          ▼
                 refresh (single-flight)
                    │            │
                success       failure
                    │            │
                    ▼            ▼
            replay once   clear tokens
                          + SessionManager.expire()
                                 │
                                 ▼
                          sessionExpired
```

**403 is not 401.** A 403 means this user may never do this; signing them out
would be wrong. The interceptor only reacts to 401, and `ApiError` keeps
`isPermissionDenied` and `isUnauthenticated` disjoint.

### Single-flight refresh

Concurrent 401s are coalesced through one `Completer`. Without it, parallel
refreshes each rotate the token and all but the first present one the server
has already retired — which reuse detection reads as theft and revokes the
session.

### Write ordering

`saveTokens` writes the **refresh token first**, then the access token,
sequentially. Refresh tokens are single-use, so the moment the new access token
is in play the old refresh token is dead; the reverse order leaves a live access
token beside a retired refresh token after a crash — a session that works for
fifteen minutes and then forces a re-login.

---

## Startup

`main()` → `AppBootstrapService.run()` → `runApp` → `AuthCheckRequested`.

Bootstrap performs **no network I/O** and no token validation. The session is
restored from secure storage; the interceptor validates lazily on the first
real request. A signed-in rep in a warehouse with no signal must still reach
their data.

Boot does not block on the network — see the `HttpReachabilityProbe` note in
`docs/skills/api-integration.md`, where awaiting an unbounded probe once stopped the app
reaching its first frame at all.

---

## Sign-out

```
LogoutRequested
   │
   ├── revoke server-side (best effort, not awaited)
   ├── clear token store
   ├── clear every session-scoped store (SessionResetService)
   ├── SessionManager.clear()  →  guest
   └── AppRestartController.restart()
```

Order matters: tokens go first so a request racing the sign-out cannot be
authorized, and `clear()` goes last because it is what notifies listeners —
they must find the underlying stores already empty.

Adding a feature that holds rep-scoped data means adding one entry to
`SessionResetService` in the composition root. The logout path itself never
changes.

---

## Security

- Tokens live in `flutter_secure_storage`, never `SharedPreferences`.
- Nothing is hard-coded; the host comes from `AppConfig`.
- `LogRedactor` masks tokens, passwords, employee IDs, e-mail, phone and
  depot data by key name *and* value shape. Covered by
  `test/core/logging/api_log_redaction_test.dart`.
- Client-side permission checks are a courtesy, never a control — the server
  re-checks every one. Use them to hide a button, not to protect anything.

---

## Tests

| Concern | File |
|---|---|
| State machine, gate, expiry vs sign-out | `test/core/session/session_manager_test.dart` |
| Attach, refresh-once, 403 safety, write order, auth-route exclusion | `test/core/middleware/auth_interceptor_test.dart` |
| Redaction both directions | `test/core/logging/api_log_redaction_test.dart` |
| Live payload shapes | `test/core/network/live_contract_test.dart` |

---

## Known gaps

1. **Not every feature has adopted `ProtectedFeature`.** `DepotSyncCubit`
   has; others still load unguarded. They fail safely (the server rejects
   them), but each is a wasted round trip and a spurious error banner. Adopting
   it is a three-line change per cubit.
2. **`sessionExpired` has no dedicated UI.** The state is set and observable,
   but nothing listens to `stateChanges` to show "your session expired" and
   route to login — the user currently discovers it on their next action.
3. **No public/protected endpoint registry.** The split is by *client* (authed
   vs bare) rather than by a declared route list. Adequate today because the
   only public routes are the auth ones; revisit if public content endpoints
   are added.
