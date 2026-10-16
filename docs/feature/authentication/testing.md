# Authentication — QA Test Plan

> Generated 2026-07-23 from the actual implementation. 72 manual/automatable cases + the automated-test matrix required by `docs/skills/engineering-standard.md` §10.
> ⚠ Cases marked **MOCK** currently exercise placeholder behavior (mock login `tester@gmail.com`/`tester@12345`, OTP `111111`, simulated reset calls) and must be re-run against the real backend when Blueprint G-1/G-2 close.
> Priority: P0 blocker · P1 high · P2 medium · P3 low.

---

## 1. Smoke tests

| ID | Case | Expected | Pri |
|---|---|---|---|
| SMK-01 | Fresh install → complete onboarding → shell | Lands on MainShell as Guest; AppCoach does **not** auto-launch | P0 |
| SMK-02 | Login with valid credentials (**MOCK**: tester@gmail.com / tester@12345) | Verifying pill → success → stack cleared to `/main` | P0 |
| SMK-03 | Relaunch after SMK-02 | Boots straight to shell, Authenticated, no login screen, no network needed | P0 |
| SMK-04 | Logout from Profile | Returns to shell as Guest; app stays open | P0 |
| SMK-05 | Guest taps protected action (Profile) | LoginRequiredDialog appears | P0 |

## 2. Functional / regression — login

| ID | Case | Expected | Pri |
|---|---|---|---|
| LOG-01 | Empty identifier + submit | Field-level validation error; no bloc event fired | P1 |
| LOG-02 | Invalid email format (e.g. `abc@`) | IdentifierField validation error | P1 |
| LOG-03 | Phone-format identifier | Accepted by IdentifierField (email-or-phone mode) | P1 |
| LOG-04 | Password < 6 chars | `auth.password_too_short` error | P1 |
| LOG-05 | Wrong credentials (online, real backend) | Red StatusPill: "Invalid email or password." (or server message) | P0 |
| LOG-06 | Server 500 / malformed body | "Something went wrong. Please try again." — never a raw exception | P1 |
| LOG-07 | Double-tap "Let's go" during in-flight login | Exactly one request (droppable); no duplicate navigation | P1 |
| LOG-08 | Password visibility toggle | Obscure ⇄ visible; icon flips; both fields on reset screen independent | P2 |
| LOG-09 | Submit via keyboard Done on password field | Same as tapping the button | P2 |
| LOG-10 | "Forgot password?" link | Pushes `/forgot-password` | P1 |
| LOG-11 | Login success arriving from LoginRequiredDialog | Stack cleared to `/main` (not returned to dialog) | P1 |
| LOG-12 | Error → retry with corrected credentials | Failure state cleared; verifying → success | P1 |

## 3. Boot / session restore

| ID | Case | Expected | Pri |
|---|---|---|---|
| BOOT-01 | Cached session + airplane mode → cold boot | Authenticated shell, zero network calls | P0 |
| BOOT-02 | No session → cold boot | Guest shell | P0 |
| BOOT-03 | Corrupt `isi.cached_user` JSON (instrumented) | Silent fallback to Guest — no crash | P1 |
| BOOT-04 | Token present, cached user missing (partial write) | Guest (both required) | P1 |
| BOOT-05 | Language change mid-session (signed in) | MaterialApp rebuilds; user stays Authenticated on shell; splash not replayed | P1 |
| BOOT-06 | Language change mid-session (guest) | Stays Guest on shell; splash not replayed | P1 |
| BOOT-07 | Kill app during boot check → relaunch | Deterministic re-check; correct end state | P2 |

## 4. Auth gating (guard)

| ID | Case | Expected | Pri |
|---|---|---|---|
| GRD-01 | Guest → each gated surface (profile, notifications, guest CTA/preview) | Dialog every time, consistent copy | P0 |
| GRD-02 | Dialog "Later" | Dismissed; user unmoved; still guest | P0 |
| GRD-03 | Dialog "Login Now" | Routes to `/login` | P0 |
| GRD-04 | Authenticated → gated surface | Opens immediately, no dialog | P0 |
| GRD-05 | Login from dialog → original protected action | Post-login lands on shell (current behavior: action **not** auto-resumed — verify accepted UX) | P2 |

## 5. Forgot password / OTP / reset (**all MOCK today**)

| ID | Case | Expected | Pri |
|---|---|---|---|
| RST-01 | Valid identifier → "Send reset link" | Verifying → success card ("Check your inbox", target echoed) → auto-push `/verify-otp` | P1 |
| RST-02 | Invalid identifier | Field validation; no submit | P1 |
| RST-03 | "Resend or try different" on success card | Returns to idle form | P2 |
| RST-04 | OTP `111111` (**MOCK**) | Success → replaced with `/create-new-password` | P1 |
| RST-05 | Wrong OTP | `auth.invalid_code`, boxes cleared, can re-enter | P1 |
| RST-06 | Resend cooldown | Button disabled 30 s with countdown `resend_code_in`; re-enabled at 0 | P1 |
| RST-07 | Resend after cooldown | Status reset to idle; boxes cleared; cooldown restarts | P2 |
| RST-08 | New password < 6 / mismatch | `password_too_short` / `passwords_dont_match` | P1 |
| RST-09 | Successful reset | Replaced with `/reset-password-success`; "Back to login" clears stack to `/login` | P1 |
| RST-10 | Back navigation from each step | ForgotPassword→login pop; Verify back button; CreateNewPassword back — no dead ends | P2 |
| RST-11 | OTP auto-submit on 6th digit | Verification fires without tapping Verify | P2 |

## 6. Offline tests

| ID | Case | Expected | Pri |
|---|---|---|---|
| OFF-01 | Login attempt in airplane mode | Immediate NetworkFailure pill — no 15 s timeout hang | P0 |
| OFF-02 | Toggle offline **during** in-flight login | Timeout → NetworkException → error pill; app stable | P1 |
| OFF-03 | Logout offline | Local session cleared; Guest; no error shown | P0 |
| OFF-04 | Captive-portal Wi-Fi (interface up, no internet) | Currently: passes fail-fast then times out (~15 s) — document as known G-4 behavior | P2 |
| OFF-05 | Offline for multiple days, then reopen | Still Authenticated from cache | P1 |

## 7. Online / token refresh

| ID | Case | Expected | Pri |
|---|---|---|---|
| TOK-01 | Expired access token → any API call | Single refresh, request replayed, user unaware | P0 |
| TOK-02 | N parallel requests hit 401 simultaneously | Exactly **one** `/auth/refresh` call (single-flight) | P1 |
| TOK-03 | Refresh returns new refresh token | Rotated in storage; next refresh uses new one | P1 |
| TOK-04 | Refresh fails (revoked/expired refresh token) | Storage cleared; original call fails; **known G-5**: UI still shows Authenticated until reboot — verify no crash, log the UX gap | P1 |
| TOK-05 | 401 on replayed request | Propagates once; no retry loop | P1 |
| TOK-06 | Refresh response missing `access_token` | Treated as failure (TOK-04 path) | P2 |

## 8. Automated-test matrix (required; **currently 0% — Blueprint G-3**)

| Tier | Targets | Gate |
|---|---|---|
| Unit (domain) | `Login`, `Logout`, `GetCurrentUser`, `User` role helpers | ≥ 90% |
| Unit (data) | `AuthRepositoryImpl` all four failure mappings + offline fail-fast + best-effort logout; model `fromMap` tolerance incl. unknown-role name (throws today — decide contract) | ≥ 80% |
| Unit (bloc) | Event→state table incl. droppable double-submit; SessionManager mirroring | — |
| Unit (interceptor) | attach / single-flight refresh / replay-once / clear-on-failure | 100% branches (security control) |
| Widget | LoginScreen validation + state mapping; StatusPill states; OtpField clear/validate | — |
| Golden | 5 screens × light/dark × en/km | — |
| Integration | boot-restore, login-logout round trip, guard dialog | — |

## 9. Theme tests

| ID | Case | Expected | Pri |
|---|---|---|---|
| THM-01 | All 5 auth screens light mode | Readable contrast; aurora/glass render; no hardcoded dark colors | P1 |
| THM-02 | All 5 auth screens dark mode | Same, dark variants | P1 |
| THM-03 | Toggle theme while on login screen | Restyles in one frame; no restart, no state loss (typed text preserved) | P2 |
| THM-04 | LoginRequiredDialog light + dark | ColorScheme-aware, per existing spec | P2 |

## 10. Localization tests

| ID | Case | Expected | Pri |
|---|---|---|---|
| L10N-01 | All auth screens in English | All `auth.*` keys resolve; no raw key names visible | P0 |
| L10N-02 | All auth screens in Khmer (km) | Same; Khmer font applied (`fontFamilyForLocale`) | P0 |
| L10N-03 | Parameterized strings (`{target}`, `{seconds}`) | Substituted correctly in both languages | P1 |
| L10N-04 | Switch language on login screen | Full rebuild; screen returns localized; session state preserved | P1 |
| L10N-05 | Long Khmer strings on small phone | No overflow/ellipsis truncating meaning | P2 |

## 11. Performance tests

| ID | Case | Expected | Pri |
|---|---|---|---|
| PRF-01 | Cold boot with cached session (mid-range Android) | Interactive shell < 2 s; auth check adds no network wait | P1 |
| PRF-02 | Login screen animation (aurora) on low-end device | No dropped-frame jank while typing | P2 |
| PRF-03 | Typing in fields | No full-screen rebuilds (BlocBuilder scoped to status/button) | P2 |

## 12. Security tests

| ID | Case | Expected | Pri |
|---|---|---|---|
| SEC-01 | Inspect app storage after login (rooted/debug) | Tokens/user only in Keychain/Keystore; nothing in SharedPreferences/Hive/plaintext files | P0 |
| SEC-02 | Grep release build/logs during login+refresh | No password, token, email, or PII in any log | P0 |
| SEC-03 | Release-candidate build | Mock login + OTP `111111` **must not work** (currently would — release blocker until G-1/G-2 fixed + CI grep gate) | P0 |
| SEC-04 | Password fields | Obscured by default; no clipboard leak of obscured text; correct autofill hints | P1 |
| SEC-05 | iOS reinstall after uninstall | Decide/verify Keychain persistence behavior (stale session after reinstall?) | P2 |
| SEC-06 | Logout → inspect storage | All three `isi.*` session keys deleted | P0 |
| SEC-07 | MITM with invalid cert | Connection fails (default TLS validation); note: no pinning yet | P1 |

## 13. Recovery tests

| ID | Case | Expected | Pri |
|---|---|---|---|
| REC-01 | Kill process mid-login (after tap, before response) | Relaunch → previous state (no phantom session) | P1 |
| REC-02 | Kill process mid-`cacheSession` (instrumented partial write) | Boot yields Guest (both-required read rule); no crash | P1 |
| REC-03 | Kill during token refresh | Relaunch boots from cache; next call re-attempts refresh | P1 |
| REC-04 | Kill mid-OTP flow | Restarts at login/shell — reset flow is intentionally non-resumable | P2 |
| REC-05 | Storage exception on cacheSession (full disk / keystore error) | `CacheFailure` pill; user can retry; no crash | P2 |

## 14. Device / form-factor sweep

| ID | Case | Expected | Pri |
|---|---|---|---|
| DEV-01 | Small phone (≤ 5.5") portrait | maxWidth-420 column scrolls; keyboard doesn't cover active field | P1 |
| DEV-02 | Tablet | Card capped at 420 dp, centered; no stretching | P2 |
| DEV-03 | Landscape phone | SingleChildScrollView prevents overflow; all controls reachable | P2 |
| DEV-04 | Accessibility: TalkBack/VoiceOver on login + dialog | Fields, toggles, buttons labeled and operable | P2 |
| DEV-05 | Large system font (200%) | No clipped/overlapping text on any auth screen | P2 |
| DEV-06 | Android back button on each auth screen | Pops per navigation table; never exits to a broken state | P1 |
