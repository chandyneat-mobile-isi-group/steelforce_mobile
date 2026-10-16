# Authentication — Feature Architecture

> Generated 2026-07-23 from the actual implementation. See [Blueprint.md](README.md) for scope and gaps.

---

## 1. Layer map

```
┌────────────────────────── presentation ───────────────────────────┐
│ AuthBloc  ── events: AuthCheckRequested / AuthGuestRequested /    │
│              LoginSubmittedEvent (droppable) / LogoutRequested    │
│           ── states: Initial / Loading / Authenticated(user) /    │
│              Guest / Unauthenticated / Failure(message)           │
│ Screens: LoginScreen, ForgotPasswordScreen, VerifyScreen,         │
│          CreateNewPasswordScreen, SuccessScreen                   │
│ Widgets: IdentifierField, VibeField, GradientButton, StatusPill,  │
│          OtpField, AuthMessageBanner                              │
└──────────────────────────────┬────────────────────────────────────┘
                               │ use cases only
┌──────────────────────────────▼──────────────── domain ────────────┐
│ Entities: User (+UserRole), AuthToken                             │
│ Repository interface: AuthRepository                              │
│ Use cases: Login(LoginParams), Logout(NoParams),                  │
│            GetCurrentUser(NoParams)                               │
│ (pure Dart — zero Flutter/Dio/storage imports)                    │
└──────────────────────────────┬────────────────────────────────────┘
                               │ implemented by
┌──────────────────────────────▼──────────────── data ──────────────┐
│ AuthRepositoryImpl (remote + local + NetworkInfo, maps            │
│                     exceptions → typed Failures)                  │
│ AuthRemoteDataSourceImpl (Dio; /v1/auth/*)                        │
│ AuthLocalDataSourceImpl (flutter_secure_storage; also TokenStore) │
│ Models: UserModel, AuthTokenModel, AuthResponseModel              │
└──────────────────────────────┬────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────── core/ ─────────────┐
│ SessionManager (in-memory, sync reads, broadcast stream)          │
│ AuthGuard + context.requireAuth  ·  LoginRequiredDialog           │
│ AuthInterceptor + TokenStore (core/middleware/app_middleware.dart)│
│ AppNetwork (Dio factory, Env.apiBaseUrl) · NetworkInfo            │
└───────────────────────────────────────────────────────────────────┘
```

## 2. Presentation layer

- **[AuthBloc](../../../lib/features/authentication/presentation/bloc/auth_bloc.dart)** holds no business logic. It maps events → use-case calls → states, and mirrors every outcome into `SessionManager` (`setUser` / `clear`). `LoginSubmittedEvent` uses `bloc_concurrency`'s `droppable()` so double-taps during an in-flight login are ignored, not queued.
- Provided **once at the app root** (`lib/app.dart`) via `MultiBlocProvider`, seeded with `AuthCheckRequested` on creation. Note: `authentication_injection.dart` registers it as a `registerFactory` with a "fresh bloc per screen" comment, but the root provider means one instance lives for the app's lifetime in practice; `app_page.dart` explicitly removed the per-route provider ("REMOVED BlocProvider here. It is now provided at the root.").
- **LoginScreen** maps bloc states to a local `AuthVibeStatus` (`idle/verifying/success/error`) that drives `StatusPill` + `GradientButton` loading. Navigation on success is a screen-local `BlocListener` (`pushNamedAndRemoveUntil(Static.main)`), per the "each surface owns its own transition" rule.
- **ForgotPassword / Verify / CreateNewPassword / Success** are deliberately **bloc-decoupled**: they accept plain async callbacks (`onSubmit`, `onVerify`, `onResend`…) returning small result objects (`ForgotPasswordResult`, `VerifyResult`, `ResetPasswordResult`). Wiring lives in `lib/routes/app_page.dart` and is currently mocked (Blueprint G-2).

## 3. Domain layer

- `User` is `Equatable` + `json_serializable` (`user.g.dart`), with role helpers used by `SessionManager`. `AuthToken` is a plain value pair.
- `AuthRepository` is the only contract presentation/domain know: `login`, `getCurrentUser`, `logout`, all returning `ResultFuture<T>` (the app's `Result`/`Failure` wrapper from `core/utils/`).
- One use case per action (`Login`, `Logout`, `GetCurrentUser`) extending `core/usecase/usecase.dart`'s `UseCase<T, Params>`.

## 4. Data layer

### 4.1 Repository ([auth_repository_impl.dart](../../../lib/features/authentication/data/repositories/auth_repository_impl.dart))

| Method | Behavior |
|---|---|
| `login` | Fail-fast `NetworkFailure` when `NetworkInfo.isConnected` is false → `remote.login` → `local.cacheSession(token, user)` → `Success(user)`. Catches `AuthenticationException` / `NetworkException` / `ServerException` / `CacheException` into matching `Failure`s |
| `getCurrentUser` | **Offline-first, purely local**: cached user + token present → `Success`; otherwise `AuthenticationFailure('No active session.')`. Never touches the network — the interceptor validates/refreshes on the first real API call |
| `logout` | Best-effort `remote.logout()` only when online, exceptions swallowed by design ("clearing local state is what counts") → `local.clear()` → always `Success` |

### 4.2 Datasources

- **Remote** (`AuthRemoteDataSourceImpl`): authed Dio; normalizes `DioException` via `_map` — timeouts/connection → `NetworkException`; 401/403 → `AuthenticationException` ("Invalid email or password." fallback); else `ServerException`. Contains the mock-login branch (Blueprint G-1).
- **Local** (`AuthLocalDataSourceImpl`): `flutter_secure_storage` under keys `isi.access_token`, `isi.refresh_token`, `isi.cached_user` (JSON `UserModel`). Reads are null-safe (corrupt cached user → `null` → Guest). **The same instance implements `TokenStore`**, so the repository and the network interceptor share one token source — registered under three types in DI to guarantee it.

## 5. Offline storage

No Drift tables, no Hive boxes, no sync-queue rows belong to this feature. The complete persistence surface is three secure-storage entries — see [Database.md](data-model.md). `onboarding_complete` (Hive `AppPreferences`) influences boot routing but is owned by splash/onboarding.

## 6. Sync queue

**Not applicable.** Authentication performs no syncable writes; its only "sync" is opportunistic token refresh (`/v1/auth/refresh`) driven by the interceptor when online. This matches the offline-posture table (`docs/blueprint/offline-architecture.md` §4: "Token refresh only, when online").

## 7. API / network

- `AppNetwork` builds Dio clients from `Env.apiBaseUrl` (Envied; no hardcoded host — a literal previously pinned all builds to production and was deliberately removed, see the note in `api_endpoints.dart`). Timeouts: connect 15 s, receive 20 s.
- The auth feature registers the app's **authed client**: `AppNetwork.createAuthedClient(tokenStore: …)` with `AuthInterceptor` (a `QueuedInterceptor`):
  - `onRequest`: attaches `Authorization: Bearer <access>` when present.
  - `onError` 401 (not yet retried): single-flight refresh (`_refreshCompleter` coalesces concurrent 401s), then replays the original request exactly once via a bare client (never recurses). Failed refresh → `TokenStore.clear()` and the original 401 propagates. See Blueprint G-5 for the missing UI notification.
- Endpoints in `ApiEndpoints`: `/v1/auth/login`, `/v1/auth/refresh`, `/v1/auth/logout`, `/v1/auth/me`. Full contract in [API.md](api.md).

## 8. Navigation

Routes (`lib/routes/app_routes.dart` → `Static`): `/login`, `/forgot-password`, `/verify-otp`, `/create-new-password`, `/reset-password-success`.

Ownership table (no global auth listener — prohibited by `docs/skills/engineering-standard.md` §4):

| Transition | Owner |
|---|---|
| Cold boot → splash/shell | `app.dart _resolveInitialRoute` + `_splashShown` latch |
| Login success → `/main` (stack cleared) | `LoginScreen` `BlocListener` |
| Forgot password → OTP → new password → success | `app_page.dart` route callbacks + `VerifyScreen`'s built-in fallback (`pushReplacementNamed(Static.createNewPassword)`) |
| Success → back to `/login` (stack cleared) | `SuccessScreen.onContinue` wiring in `app_page.dart` |
| Logout → shell as Guest | `ProfileScreen._confirmLogout` |
| Guest hits protected action | `AuthGuard` → `LoginRequiredDialog` (dialog routes to `/login` on "Login Now") |

## 9. Dependency injection

`registerAuthFeature(GetIt sl)` ([authentication_injection.dart](../../../lib/features/authentication/authentication_injection.dart)), called from the core composition root after externals (secure storage, connectivity) are registered. All lazy:

- `AuthBloc` — factory (see §2 note); use cases, repository — lazy singletons.
- `AuthLocalDataSourceImpl` registered once, then aliased as both `AuthLocalDataSource` and `TokenStore` (one token store, no drift).
- `Dio` (authed) — lazy singleton consumed by feature remote datasources app-wide.

## 10. Security

Tokens/cached user only in secure storage; no PII in logs from this feature; typed failures only cross to UI. The one live violation is the untagged mock login (Blueprint G-1). Full treatment: [Security.md](security.md).

## 11. Performance

- Boot check is memory/secure-storage only — respects the cold-start budget (`docs/skills/ai-engineering-playbook.md` §9).
- `SessionManager` reads are synchronous — guards never `await` to decide gating.
- `droppable()` prevents duplicate login requests; queued interceptor + single-flight refresh prevent token stampedes.
- Screen rebuilds are scoped: `LoginScreen` wraps only the status/button area in `BlocBuilder`.

## 12. Theme

All auth screens share the aurora + glass visual language (`shared/widgets/aurora_background.dart`, `glass_card.dart`) and read colors via `Theme.of(context).colorScheme` + `context.appColors` (`core/theme/theme_extensions.dart`) — fully light/dark aware, no hardcoded palette values in screens.

## 13. Localization

All user-facing copy uses `'auth.*'.tr` / `.trParams` (`core/localization/localization_services.dart`) with the `auth` section of `assets/lang/en.json` and `assets/lang/km.json` (en + km only; key parity maintained). Parameterized keys: `auth.reset_instructions_sent{target}`, `auth.verify_code_subtitle{target}`, `auth.resend_code_in{seconds}`.
