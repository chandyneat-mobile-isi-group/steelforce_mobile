# Authentication — Security Documentation

> Generated 2026-07-23 from the actual implementation. App-wide security standard: `docs/skills/security.md`.

---

## 1. Authentication

- Credential login (identifier + password) over the Envied-configured gateway; credentials exist only in memory during submission — never persisted, never logged.
- Session restore is possession-based: holding the device + an intact Keychain/Keystore entry = the session. There is no offline PIN/biometric re-lock (see [Roadmap.md](roadmap.md)).
- Guest is the fail-safe default: any doubt (missing token, corrupt cache, failed refresh) degrades to Guest rather than erroring or blocking.

## 2. Authorization

- Current enforcement is **binary**: authenticated vs. guest, via `AuthGuard` only (`docs/blueprint/offline-architecture.md` §2.4 — inline checks are a review-rejectable anti-pattern). Verified consumers: `MainShell`, notifications sheet, guest home/CTA/preview widgets, language-selection screen.
- Role model (`UserRole`, `SessionManager.can/canAny/canAll`) exists but no screen branches on roles yet — RBAC awaits Organization/Role/Permission sync (`docs/blueprint/offline-architecture.md` §4).
- Client-side gating is UX, not security: the server must independently authorize every API call by token.

## 3. Role permissions (as modeled today)

| Role | Modeled meaning | Enforced anywhere? |
|---|---|---|
| `guest` | Browse-only; protected actions prompt login | Yes — `AuthGuard` |
| `salesRep` / `manager` / `admin` | Reserved for RBAC | Not yet |

## 4. Secure storage

Tokens + cached user exclusively in `flutter_secure_storage` — full inventory in [Database.md](data-model.md) §3. Compliance check against `docs/skills/security.md` §3:

| Rule | Status |
|---|---|
| No tokens/PII in SharedPreferences/Hive/unencrypted DB | ✅ Verified — auth writes only to secure storage |
| Secrets only in secure storage | ✅ |
| Cached user (PII: name, email) in secure storage | ✅ |

## 5. Token flow

Attach → 401 → single-flight refresh → replay-once → clear-on-failure. Full protocol in [API.md](api.md) §4. Security properties:

- Refresh uses a **bare** client — the refresh token is never sent through the interceptor (no recursion, no accidental bearer attach).
- Replay-once flag prevents infinite 401 loops.
- Failed refresh wipes all session material immediately (`TokenStore.clear`).
- ⚠ **G-5**: after that wipe, `SessionManager`/`AuthBloc` still report authenticated until next boot — the UI can act on a dead session (requests will 401 individually). Fix: propagate a session-expired event.

## 6. Encryption

- At rest: delegated to platform secure storage (Keychain / Keystore-backed EncryptedSharedPreferences). No custom cryptography anywhere in the feature (complies with `docs/skills/security.md`).
- In transit: HTTPS via the shared Dio client. ⚠ Certificate pinning is not implemented (app-wide gap, tracked in `docs/skills/security.md`).

## 7. Input validation

| Input | Validation (client) |
|---|---|
| Identifier | `IdentifierField` validates email-or-phone format with its own `validate()`/mode |
| Password (login, reset) | Required, ≥ 6 characters (`auth.password_too_short`) |
| Confirm password | Must match new password (`auth.passwords_dont_match`) |
| OTP | Fixed length (6), `OtpField.validate()`; wrong code clears the boxes |

Server-side validation remains authoritative; client checks are UX-only. ⚠ Password policy (6 chars, no complexity rules) is weaker than typical enterprise policy — confirm against backend policy before release.

## 8. Offline security

- No credential verification offline (by design — no offline password hash exists to attack).
- Cached session = device possession; threat accepted for field usage, mitigated by OS-level device lock. Biometric app-lock is a roadmap item.
- Logout works offline and always clears local state, even if server revocation is skipped — the refresh token remains server-valid until it expires or the server learns of the logout (accepted risk, standard mobile pattern).

## 9. Sensitive data handling

- **Logging**: no auth code logs tokens, passwords, or user PII. The repo has a log redactor (`test/core/logging/log_redactor_test.dart`) at core level. Keep it that way: allowed log content is endpoint + status/error code only (`docs/skills/security.md` §10).
- **Error surfaces**: only typed, localized failure messages reach the UI; raw exceptions/stack traces never do.
- **Screens**: password fields obscured by default with explicit visibility toggles; autofill hints set (`AutofillHints.password` / `newPassword`).

## 10. 🔴 Release-gate findings (must fix before any release build)

| # | Finding | Location | Required action |
|---|---|---|---|
| 1 | Hardcoded mock credentials `tester@gmail.com` / `tester@12345` bypass the network and mint a fake session — **untagged** | `auth_remote_data_source.dart` (`--- MOCK LOGIN FOR TESTING ---`) | Add `// TODO(release-gate):`, gate behind debug-only config, cover with the CI grep gate (`docs/skills/security.md` §11) |
| 2 | Mock OTP `111111` accepted; reset flows simulate success unconditionally — untagged `TODO`s | `lib/routes/app_page.dart` (forgot-password / verify-otp / create-new-password cases) | Same tagging + real endpoint wiring (Blueprint G-2) |
| 3 | Session-expiry not propagated to UI after refresh failure | `app_middleware.dart` | Implement G-5 before production traffic |
| 4 | Zero security tests for auth (wrong-key, cleared-storage, refresh-failure paths) | `test/` | See [QA_Test_Plan.md](testing.md) §Security |
