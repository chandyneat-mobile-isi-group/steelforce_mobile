# Authentication — Technical Design

> Generated 2026-07-23 from the actual implementation.

---

## 1. Folder structure (actual)

```
lib/features/authentication/
├── authentication_injection.dart          # registerAuthFeature(GetIt)
├── data/
│   ├── datasources/
│   │   ├── auth_local_data_source.dart    # AuthLocalDataSource(+Impl) — secure storage; also implements TokenStore
│   │   └── auth_remote_data_source.dart   # AuthRemoteDataSource(+Impl) — Dio /v1/auth/*  ⚠ contains mock-login branch
│   ├── models/
│   │   ├── auth_response_model.dart       # {user, tokens} envelope-tolerant parser
│   │   ├── auth_token_model.dart          # extends AuthToken; access_token/refresh_token map
│   │   └── user_model.dart                # extends User; fromMap/toMap, role Set ⇄ string list
│   └── repositories/
│       └── auth_repository_impl.dart      # coordinates remote+local+NetworkInfo → Result/Failure
├── domain/
│   ├── entities/
│   │   ├── auth_token.dart                # accessToken + refreshToken (Equatable)
│   │   ├── user.dart (+ user.g.dart)      # id, email, fullName, Set<UserRole>, company?, avatarUrl?
│   │   └── user_role.dart                 # admin | manager | salesRep | guest
│   ├── repositories/
│   │   └── auth_repository.dart           # login / getCurrentUser / logout (ResultFuture)
│   └── usecases/
│       ├── get_current_user.dart          # UseCase<User, NoParams>
│       ├── login.dart                     # UseCase<User, LoginParams(email, password)>
│       └── logout.dart                    # UseCase<void, NoParams>
└── presentation/
    ├── bloc/
    │   ├── auth_bloc.dart                 # events→usecases; mirrors SessionManager; droppable login
    │   ├── auth_event.dart                # AuthCheckRequested / AuthGuestRequested / LoginSubmittedEvent / LogoutRequested
    │   └── auth_state.dart                # Initial / Loading / Authenticated / Unauthenticated / Guest / Failure
    ├── screens/
    │   ├── login_screen.dart              # bloc-driven; BlocListener nav on success
    │   ├── forgot_password_screen.dart    # callback-driven (onSubmit → ForgotPasswordResult)
    │   ├── verify_screen.dart             # OTP entry; resend cooldown; fallback nav to create-new-password
    │   ├── create_new_password_screen.dart# new+confirm password; callback-driven
    │   └── success_screen.dart            # generic "all done" confirmation
    └── widgets/
        ├── auth_message_banner.dart
        ├── forgot_password/identifier_field.dart   # email-or-phone field with own validate()/mode
        ├── login/{gradient_button,status_pill,vibe_field}.dart
        └── verify/otp_field.dart          # n-box OTP input with validate()/clear()

Cross-cutting (core/, consumed by or serving this feature):
├── core/session/session_manager.dart      # in-memory user; sync role checks; broadcast changes stream
├── core/auth/auth_guard.dart              # AuthGuard.requireAuthentication + context.requireAuth
├── core/auth/login_required_dialog.dart   # Material 3 prompt (Login Now / Later)
├── core/middleware/app_middleware.dart    # TokenStore interface + AuthInterceptor (QueuedInterceptor)
├── core/network/app_network.dart          # AppNetwork.createBareClient/createAuthedClient (Env.apiBaseUrl)
├── core/network/connectivity/network_info.dart         # NetworkInfo(+Impl via connectivity_plus)
└── core/network/api/api_endpoints.dart    # endpoints (keys: core/database/secure/secure_storage_keys.dart)
```

## 2. Entities

| Entity | Fields | Notes |
|---|---|---|
| `User` | `id`, `email`, `fullName`, `roles: Set<UserRole>`, `company?`, `avatarUrl?` | Equatable + `@JsonSerializable`; helpers `primaryRole` (first role or `guest`), `hasRole/hasAnyRole/hasAllRoles` |
| `UserRole` | `admin`, `manager`, `salesRep`, `guest` | Serialized by enum `name` |
| `AuthToken` | `accessToken`, `refreshToken` | Equatable value object |

## 3. Models (data layer)

- `UserModel extends User` — `fromMap` tolerates `full_name`/`name` and `roles`/`user_roles`; unknown role names would throw (`UserRole.values.byName`) — a contract risk to test. `toMap` emits `full_name`, `roles: [name…]`, `company`, `avatar_url`.
- `AuthTokenModel extends AuthToken` — maps `access_token`/`refresh_token`, defaulting to `''` when absent.
- `AuthResponseModel` — accepts `{user, …tokens}`, `{data:{user, …}}`, or a bare user map.

## 4. Repositories

Interface `AuthRepository` (domain) / `AuthRepositoryImpl` (data) — full behavior table in [Architecture.md](architecture.md) §4.1. Signature style: `ResultFuture<T>` = `Future<Result<T, Failure>>` from `core/utils/typedefs.dart` + `core/utils/result.dart` (`Success` / `Failed`, consumed with `.when(success:…, failure:…)`).

## 5. Bloc

`AuthBloc(login, logout, getCurrentUser, sessionManager)`:

| Event | Handler | Transformer | Emits | SessionManager |
|---|---|---|---|---|
| `AuthCheckRequested` | `_onCheck` | default | Loading → Authenticated \| Guest | `setUser` / `clear` |
| `AuthGuestRequested` | `_onGuest` | default | Guest | `clear` |
| `LoginSubmittedEvent(email, password)` | `_onLogin` | **`droppable()`** | Loading → Authenticated \| Failure(message) | `setUser` on success |
| `LogoutRequested` | `_onLogout` | default | Guest | `clear` |

## 6. UseCases

One per action, all `const`, all pure delegation to the repository: `Login(LoginParams)`, `Logout(NoParams)`, `GetCurrentUser(NoParams)`. No mode parameters (complies with the one-usecase-per-action rule).

## 7. Datasources

See [Architecture.md](architecture.md) §4.2 and [API.md](api.md). Key structural decision: `AuthLocalDataSourceImpl` implements **both** `AuthLocalDataSource` and `TokenStore`; DI registers the single concrete instance under both interfaces plus its own type, guaranteeing the interceptor and repository read/write the same keys.

## 8. Mapper

There is no separate mapper file: models extend their entities (so a `UserModel` *is a* `User`) and carry their own `fromMap`/`toMap`. This differs from the Drift-era mapper-extension pattern in `docs/skills/ai-engineering-playbook.md` §13.5, which applies to database-row mapping — not needed here since auth has no database rows.

## 9. Drift

**None.** No tables, DAOs, or migrations belong to authentication. (The secure-storage keys `isi.db_device_key*` in `app_constant.dart` are database-encryption infrastructure, not auth.)

## 10. Hive

**None owned by this feature.** `onboarding_complete` (Hive `AppPreferences`) affects the boot route but belongs to splash/onboarding.

## 11. Secure storage

| Key | Content | Written by | Read by |
|---|---|---|---|
| `isi.access_token` | JWT/opaque access token | `cacheSession`, `saveTokens` (refresh) | interceptor `onRequest`, `readToken` |
| `isi.refresh_token` | refresh token | same | `_performRefresh`, `readToken` |
| `isi.cached_user` | `UserModel.toMap()` JSON | `cacheSession` | `readUser` (boot restore) |

All three deleted on `clear()` (logout, or failed refresh via `TokenStore.clear`).

## 12. Dependency graph (feature-scoped)

```mermaid
graph TD
    subgraph presentation
        LS[LoginScreen] --> AB[AuthBloc]
        FPS[ForgotPassword/Verify/CreateNewPassword/Success] -. callbacks wired in app_page.dart ⚠ MOCK .-> APP[routes/app_page.dart]
    end
    subgraph domain
        AB --> L[Login] & LO[Logout] & GCU[GetCurrentUser]
        L & LO & GCU --> ARI[AuthRepository interface]
    end
    subgraph data
        ARImpl[AuthRepositoryImpl] -->|implements| ARI
        ARImpl --> RDS[AuthRemoteDataSource] & LDS[AuthLocalDataSource] & NI[NetworkInfo]
        RDS --> DIO[Dio authed client]
    end
    subgraph core
        AB --> SM[SessionManager]
        AG[AuthGuard] --> SM
        AG --> LRD[LoginRequiredDialog]
        DIO --> AI[AuthInterceptor]
        AI --> TS[TokenStore]
        LDS -->|same instance| TS
        LDS --> FSS[flutter_secure_storage]
        DIO --> ENV[Env.apiBaseUrl / AppNetwork]
    end
    SHELL[MainShell / notifications / guest widgets] --> AG
    APPDART[app.dart] -->|provides + AuthCheckRequested| AB
```

## 13. Known deviations from target architecture

| Deviation | Assessment |
|---|---|
| Reset-flow screens bypass AuthBloc (plain callbacks) | Deliberate, documented in each screen's doc comment; migrate to bloc events when backend endpoints exist (Blueprint G-2) |
| `AuthBloc` registered as factory but provided once at root | Harmless today; align registration (`registerLazySingleton`) or comment when touched |
| Silent `catch (_)` in `logout()` remote call | Commented as best-effort by design; `docs/skills/engineering-standard.md` §7 would prefer a debug log via the structured logger |
| `readUser` swallows decode errors to `null` | Correct offline-first posture (corrupt cache → Guest), acceptable per `docs/blueprint/offline-architecture.md` §2.5 |
