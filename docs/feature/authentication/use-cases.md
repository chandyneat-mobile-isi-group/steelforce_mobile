# Authentication — Use Case Document

> Generated 2026-07-23. UC-1..4 are fully implemented (`domain/usecases/` + `AuthBloc`); UC-5..7 are UI-implemented with mocked backends (Blueprint G-2).

---

## UC-1: Restore session on boot

| Field | Value |
|---|---|
| Actor | System (app boot) on behalf of any user |
| Goal | Resolve Authenticated vs. Guest without blocking startup |
| Trigger | `AuthBloc` created at app root → `AuthCheckRequested` |
| Preconditions | App process starting; secure storage accessible |
| Main flow | 1. Emit `AuthLoadingState` 2. `GetCurrentUser` → repository reads cached user + token from secure storage 3. Both present → `SessionManager.setUser`; emit `AuthenticatedState(user)` |
| Alternative flow | Either value missing → `SessionManager.clear()`; emit `AuthGuestState` (not an error) |
| Exception flow | Corrupt cached-user JSON → local source returns `null` → Guest path; storage read throwing → Guest path. Never crashes boot |
| Business rules | BR-S1, BR-S2, BR-O1 ([BusinessRules.md](business-rules.md)) |
| Post conditions | Shell renders for both outcomes; `SessionManager` consistent with emitted state; zero network calls made |

## UC-2: Sign in

| Field | Value |
|---|---|
| Actor | Guest (rep/manager/admin with an account) |
| Goal | Establish an authenticated session |
| Trigger | "Let's go" on `LoginScreen` → `LoginSubmittedEvent` |
| Preconditions | Device online; form + identifier valid (client-side) |
| Main flow | 1. Droppable transformer admits one in-flight attempt 2. `AuthLoadingState` 3. Connectivity fail-fast check 4. `POST /v1/auth/login` 5. `cacheSession(tokens, user)` in secure storage 6. `SessionManager.setUser` 7. `AuthenticatedState` 8. Screen-local listener clears stack to `/main` |
| Alternative flow | A: duplicate tap while in flight → dropped silently. B: arrived via LoginRequiredDialog → same flow; destination is still the shell |
| Exception flow | Offline → `NetworkFailure` (no request). 401/403 → `AuthenticationFailure` with server/fallback message. 5xx/malformed → `ServerFailure`. Storage write fails → `CacheFailure`. All → `AuthFailureState(message)`; user may retry |
| Business rules | BR-V1..V3, BR-W1, BR-W2, BR-O2 |
| Post conditions | Success: session persisted + mirrored; user on shell. Failure: unchanged guest state; localized error visible |

## UC-3: Continue as guest

| Field | Value |
|---|---|
| Actor | Any user without (or declining) an account |
| Goal | Use the app without signing in |
| Trigger | Onboarding "Let's go" (`LanguageSelectionScreen`) or dismissing the login prompt → `AuthGuestRequested` |
| Preconditions | None |
| Main flow | `SessionManager.clear()`; emit `AuthGuestState` |
| Alternative flow | Already guest → same result (idempotent) |
| Exception flow | None (pure in-memory) |
| Business rules | BR-W3 |
| Post conditions | Full browsing available; protected actions gated by UC-4 |

## UC-4: Access a protected feature (guard)

| Field | Value |
|---|---|
| Actor | Guest or authenticated user |
| Goal | Ensure a session exists before a gated action (order, cart, checkout, profile, history, notifications, saved items) |
| Trigger | Tap on a gated surface → `AuthGuard.requireAuthentication(context)` / `context.requireAuth(...)` |
| Preconditions | `SessionManager` registered in DI |
| Main flow | Authenticated (synchronous check) → run `onAuthenticated`; return `true` |
| Alternative flow | Guest → show `LoginRequiredDialog`; "Login Now" routes to `/login`; return `false`. "Later" → dismiss, user stays put |
| Exception flow | Context unmounted before dialog → return `false` silently |
| Business rules | BR-P1, BR-P2 |
| Post conditions | Gated action ran iff authenticated; guests never blocked from continuing to browse. Note: after login the original action is **not** auto-resumed (current behavior) |

## UC-5: Sign out

| Field | Value |
|---|---|
| Actor | Authenticated user (via ProfileScreen confirm) |
| Goal | End the session; return to guest browsing |
| Trigger | `LogoutRequested` |
| Preconditions | Authenticated |
| Main flow | 1. If online: `POST /v1/auth/logout` (best-effort) 2. Delete all three secure-storage keys 3. `SessionManager.clear()` 4. `AuthGuestState`; Profile pops to shell |
| Alternative flow | Offline → skip step 1 entirely |
| Exception flow | Server revocation throws → swallowed by design; local clear proceeds; always succeeds from the user's perspective |
| Business rules | BR-W4, BR-D1 |
| Post conditions | Device session gone; app open as Guest. Server-side refresh token may remain valid until expiry (accepted risk) |

## UC-6: Request password reset ⚠ MOCK

| Field | Value |
|---|---|
| Actor | User who forgot their password |
| Goal | Receive a verification code at their email/phone |
| Trigger | "Send reset link" on `ForgotPasswordScreen` |
| Preconditions | Valid identifier entered |
| Main flow (intended) | Submit identifier → backend sends OTP → success card → navigate to `/verify-otp` with the identifier |
| Current implementation | `app_page.dart` `onSubmit` waits 1 s and returns success unconditionally — **no request is made** |
| Alternative flow | "Resend or try a different account" returns to the form |
| Exception flow (intended) | Unknown identifier / rate-limited → `ForgotPasswordResult.failure(message)` → error pill |
| Business rules | BR-V1, BR-R1 |
| Post conditions | User on OTP screen with `target` displayed |

## UC-7: Verify code and set a new password ⚠ MOCK

| Field | Value |
|---|---|
| Actor | User mid-reset |
| Goal | Prove ownership of the identifier and choose a new password |
| Trigger | 6-digit entry on `VerifyScreen` (auto-submits) → then `CreateNewPasswordScreen` submit |
| Preconditions | Arrived from UC-6 with `target`; code delivered out-of-band |
| Main flow (intended) | Code verified server-side → replace with create-new-password (`target`+`code` as args) → new password accepted server-side → replace with success screen → back to login (stack cleared) |
| Current implementation | Code `111111` accepted after 1 s delay; any password accepted after 1 s delay; resend is a 1 s no-op with a 30 s client cooldown |
| Alternative flow | Resend code (after cooldown) → boxes cleared, cooldown restarts |
| Exception flow | Wrong code → localized error + boxes cleared. Mismatch/short password → field validation. (Intended: expired code, attempt limits — undefined until backend exists) |
| Business rules | BR-V2..V4, BR-R2, BR-R3 |
| Post conditions | Intended: password changed; all prior sessions revoked server-side (to be confirmed with backend); user re-authenticates. Current: nothing actually changes |
