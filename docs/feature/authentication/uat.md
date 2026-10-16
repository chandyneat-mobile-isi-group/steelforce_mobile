# Authentication — User Acceptance Testing

> Generated 2026-07-23. Execute on a physical device per environment (QA `.env` build). Fill **Actual Result** and **Status** (Pass / Fail / Blocked) during the run.
> ⚠ **MOCK** cases exercise placeholder backend behavior (Blueprint G-1/G-2): mock login `tester@gmail.com` / `tester@12345`, OTP `111111`. Re-execute after real wiring.
> Severity: Critical / Major / Minor. Priority: P0–P3.

---

## Screen 1 — Login (`/login`)

| Test ID | Title | Precondition | Steps | Expected Result | Actual Result | Status | Priority | Severity |
|---|---|---|---|---|---|---|---|---|
| UAT-LOG-001 | Successful login (**MOCK**) | Guest; online | 1. Open login 2. Enter tester@gmail.com / tester@12345 3. Tap "Let's go" | Pill shows verifying → success; navigates to shell with back stack cleared | | | P0 | Critical |
| UAT-LOG-002 | Wrong password | Guest; online; real account | Enter valid identifier + wrong password; submit | Red pill with "Invalid email or password." (or server message); stays on login | | | P0 | Critical |
| UAT-LOG-003 | Empty form submit | Guest | Tap "Let's go" with both fields empty | Inline validation on identifier and password; no request sent | | | P1 | Major |
| UAT-LOG-004 | Malformed identifier | Guest | Enter `abc@` + valid password; submit | Identifier validation error | | | P1 | Major |
| UAT-LOG-005 | Phone identifier accepted | Guest | Enter a valid phone number + password; submit | Field validates; request proceeds (result per backend) | | | P1 | Major |
| UAT-LOG-006 | Short password | Guest | Password `12345`; submit | "Password too short" style error | | | P1 | Major |
| UAT-LOG-007 | Offline login attempt | Guest; airplane mode | Enter any credentials; submit | Immediate network-error pill; no long hang; app usable | | | P0 | Critical |
| UAT-LOG-008 | Double-tap submit | Guest; slow network | Tap "Let's go" twice rapidly | One request; one navigation; no duplicate screens | | | P1 | Major |
| UAT-LOG-009 | Password visibility toggle | Guest | Type password; tap eye icon twice | Text revealed then re-obscured | | | P2 | Minor |
| UAT-LOG-010 | Forgot-password link | Guest | Tap "Forgot password?" | Forgot Password screen opens | | | P1 | Major |
| UAT-LOG-011 | Login screen dark theme | Dark mode on | Open login | All text readable; glass card and pill styled for dark | | | P1 | Major |
| UAT-LOG-012 | Login screen Khmer | Language = km | Open login | Title/subtitle/labels/buttons in Khmer; correct font | | | P0 | Major |
| UAT-LOG-013 | Landscape / small screen | Any phone | Rotate on login; type with keyboard open | Content scrolls; active field visible; no overflow | | | P2 | Minor |
| UAT-LOG-014 | Version footer visible | Guest | Open login | App version shown at bottom edge | | | P3 | Minor |

## Screen 2 — Login Required dialog (guard surface)

| Test ID | Title | Precondition | Steps | Expected Result | Actual Result | Status | Priority | Severity |
|---|---|---|---|---|---|---|---|---|
| UAT-GRD-001 | Prompt on protected action | Guest on shell | Tap Profile (or notifications) | Login Required dialog with lock badge, Login Now, Later | | | P0 | Critical |
| UAT-GRD-002 | "Later" keeps browsing | Dialog open | Tap "Later" | Dialog closes; user exactly where they were; still guest | | | P0 | Critical |
| UAT-GRD-003 | "Login Now" routes | Dialog open | Tap "Login Now" | Login screen opens | | | P0 | Critical |
| UAT-GRD-004 | No prompt when signed in | Authenticated | Tap Profile | Opens immediately; no dialog | | | P0 | Critical |
| UAT-GRD-005 | Dialog theme/language | Dark + km | Trigger dialog | Localized copy; dark-aware styling; scroll-safe on small screens | | | P1 | Major |

## Screen 3 — Forgot Password (`/forgot-password`) ⚠ MOCK

| Test ID | Title | Precondition | Steps | Expected Result | Actual Result | Status | Priority | Severity |
|---|---|---|---|---|---|---|---|---|
| UAT-FPW-001 | Request reset (happy) | On screen; online | Enter valid identifier; tap "Send reset link" | Verifying → success card "Check your inbox" echoing the identifier; auto-navigates to Verify | | | P1 | Major |
| UAT-FPW-002 | Invalid identifier | On screen | Enter `x`; submit | Validation error; no request | | | P1 | Major |
| UAT-FPW-003 | Back to login | On screen | Tap back arrow | Returns to login without losing login-screen state | | | P2 | Minor |
| UAT-FPW-004 | Resend / try different | Success card shown | Tap "Resend or try a different…" | Returns to idle form for re-entry | | | P2 | Minor |
| UAT-FPW-005 | Theme + language | Dark + km | Open screen both states | Localized, dark-aware | | | P1 | Major |

## Screen 4 — Verify OTP (`/verify-otp`) ⚠ MOCK

| Test ID | Title | Precondition | Steps | Expected Result | Actual Result | Status | Priority | Severity |
|---|---|---|---|---|---|---|---|---|
| UAT-OTP-001 | Correct code (**MOCK** `111111`) | Arrived from Forgot Password | Enter 111111 | Auto-submits on 6th digit; success; replaced with Create New Password | | | P1 | Major |
| UAT-OTP-002 | Wrong code | On screen | Enter `000000` | "Invalid code" error; boxes cleared; can retype | | | P1 | Major |
| UAT-OTP-003 | Incomplete code | On screen | Enter 3 digits; tap Verify | Validation blocks submission | | | P1 | Major |
| UAT-OTP-004 | Resend cooldown | Fresh arrival | Observe resend link | Disabled with countdown from 30 s; label `Resend code in NN` | | | P1 | Major |
| UAT-OTP-005 | Resend after cooldown | Countdown at 0 | Tap "Resend code" | Boxes cleared; status reset; countdown restarts | | | P2 | Minor |
| UAT-OTP-006 | Target shown | Arrived with identifier | Read subtitle | The email/phone entered on the previous screen is displayed | | | P2 | Minor |
| UAT-OTP-007 | Back to login | On screen | Tap back | Pops per navigation table; no dead end | | | P2 | Minor |
| UAT-OTP-008 | Theme + language | Dark + km | Open both states | Localized, dark-aware; countdown string localized | | | P1 | Major |

## Screen 5 — Create New Password (`/create-new-password`) ⚠ MOCK

| Test ID | Title | Precondition | Steps | Expected Result | Actual Result | Status | Priority | Severity |
|---|---|---|---|---|---|---|---|---|
| UAT-CNP-001 | Successful reset | Arrived from OTP | Enter matching valid passwords; submit | Verifying → success; replaced with Success screen | | | P1 | Major |
| UAT-CNP-002 | Mismatched confirm | On screen | New `abcdef`, confirm `abcdeg`; submit | "Passwords don't match" on confirm field | | | P1 | Major |
| UAT-CNP-003 | Short password | On screen | Both fields `12345`; submit | "Password too short" | | | P1 | Major |
| UAT-CNP-004 | Independent visibility toggles | On screen | Toggle each eye icon | Each field toggles independently | | | P2 | Minor |
| UAT-CNP-005 | Theme + language | Dark + km | Open both states | Localized, dark-aware | | | P1 | Major |

## Screen 6 — Success (`/reset-password-success`)

| Test ID | Title | Precondition | Steps | Expected Result | Actual Result | Status | Priority | Severity |
|---|---|---|---|---|---|---|---|---|
| UAT-SUC-001 | Back to login | Arrived from reset | Tap primary button | Stack cleared to Login; back button does not return to reset flow | | | P1 | Major |
| UAT-SUC-002 | Theme + language | Dark + km | Open both states | Localized, dark-aware; badge renders | | | P2 | Minor |

## Cross-cutting scenarios

| Test ID | Title | Precondition | Steps | Expected Result | Actual Result | Status | Priority | Severity |
|---|---|---|---|---|---|---|---|---|
| UAT-XC-001 | Offline boot with session | Logged in once; airplane mode | Force-close; relaunch | Authenticated shell instantly; zero network errors | | | P0 | Critical |
| UAT-XC-002 | Boot with no session | Fresh install onboarded; offline | Relaunch | Guest shell | | | P0 | Critical |
| UAT-XC-003 | Offline logout | Authenticated; airplane mode | Profile → logout → confirm | Guest shell; relaunch stays Guest | | | P0 | Critical |
| UAT-XC-004 | Token refresh transparency | Access token expired; online | Trigger any API-backed screen | Data loads; no visible auth interruption; single refresh in proxy log | | | P0 | Critical |
| UAT-XC-005 | Revoked session (refresh fails) | Refresh token revoked server-side | Use an API-backed screen | Calls fail gracefully; **known G-5**: UI may still show Authenticated until relaunch — record behavior | | | P1 | Major |
| UAT-XC-006 | Language switch mid-session | Authenticated | Settings → switch en⇄km | App rebuilds in new language; still Authenticated; no splash replay | | | P1 | Major |
| UAT-XC-007 | Kill mid-login | Slow network | Submit login; kill app before response; relaunch | No phantom session — state matches pre-login | | | P1 | Major |
| UAT-XC-008 | Storage inspection | Rooted/debug device; logged in | Inspect prefs/Hive/files | Session material only in Keychain/Keystore | | | P0 | Critical |
| UAT-XC-009 | Release build mock lockout | Release candidate | Try tester@gmail.com/tester@12345 and OTP 111111 | **Must fail** (blocked until G-1/G-2 remediated — treat as release gate) | | | P0 | Critical |
| UAT-XC-010 | Accessibility pass | TalkBack/VoiceOver | Traverse login + dialog | All controls announced and operable | | | P2 | Major |
