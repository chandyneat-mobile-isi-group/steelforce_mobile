# Authentication — Business Rules

> Generated 2026-07-23 from the actual implementation. Referenced from [UseCases.md](use-cases.md).

---

## 1. Validation rules

| ID | Rule | Enforced by |
|---|---|---|
| BR-V1 | Login/reset identifier must be a syntactically valid email **or** phone number | `IdentifierField.validate()` (client) |
| BR-V2 | Passwords (login, new, confirm) must be ≥ 6 characters | Field validators (`auth.password_too_short`) |
| BR-V3 | Confirm password must equal new password | `CreateNewPasswordScreen` validator |
| BR-V4 | OTP must be exactly 6 digits before verification | `OtpField.validate()`; auto-submit on 6th digit |
| BR-V5 | Client validation is UX-only — the server remains authoritative for every credential decision | Architecture principle |

## 2. Workflow rules

| ID | Rule | Enforced by |
|---|---|---|
| BR-W1 | Only one login attempt may be in flight; extra submissions are dropped, not queued | `droppable()` transformer on `LoginSubmittedEvent` |
| BR-W2 | Successful login clears the entire navigation stack to the shell | `LoginScreen` `BlocListener` (`pushNamedAndRemoveUntil`) |
| BR-W3 | Guest is the default resting state; entering it is idempotent and never an error | `AuthGuestState` semantics; `_onGuest` |
| BR-W4 | Logout always succeeds locally, regardless of connectivity or server response | `AuthRepositoryImpl.logout` |
| BR-W5 | No global auth-state listener may drive navigation; each surface owns its transition | `docs/skills/engineering-standard.md` §4 (prohibited pattern, previously reverted) |
| BR-W6 | Reset flow is strictly linear (identifier → code → new password → success) with `pushReplacement` between steps — users cannot back into a consumed step | `app_page.dart` + `VerifyScreen._navigateToCreateNewPassword` |
| BR-W7 | Resend OTP is throttled client-side: 30 s cooldown after every send | `VerifyScreen.resendCooldown` timer |

## 3. Permissions

| ID | Rule | Enforced by |
|---|---|---|
| BR-P1 | Every auth-gated action must go through `AuthGuard` — inline `isAuthenticated` checks are prohibited | Playbook §12 anti-pattern list; review gate |
| BR-P2 | Declining login ("Later") must leave the user exactly where they were, still able to browse | `LoginRequiredDialog` contract |
| BR-P3 | A user's roles come only from the server payload; empty roles degrade to `guest` capabilities | `User.primaryRole`; `SessionManager.roles` |
| BR-P4 | Role-based (non-binary) authorization is not yet a shipped rule — do not encode per-role UI branches until Organization/Role/Permission sync exists | `docs/blueprint/offline-architecture.md` §4 |

## 4. Offline rules

| ID | Rule | Enforced by |
|---|---|---|
| BR-O1 | Boot-time session resolution must complete with zero network calls | `AuthRepositoryImpl.getCurrentUser` (local-only) |
| BR-O2 | Login requires connectivity and must fail fast (typed `NetworkFailure`) when offline — never a hanging spinner | `NetworkInfo.isConnected` pre-check |
| BR-O3 | A missing/corrupt cached session degrades to Guest — never a crash, never a blocking error screen | Null-safe reads in `AuthLocalDataSourceImpl` |
| BR-O4 | Offline is never presented as a blocking dialog on auth surfaces | `docs/blueprint/offline-architecture.md` §5 |

## 5. Sync rules

| ID | Rule | Enforced by |
|---|---|---|
| BR-Y1 | Authentication participates in **no** sync queue; its only server reconciliation is token refresh | Design (see [Architecture.md](architecture.md) §6) |
| BR-Y2 | Token refresh is single-flight: N concurrent 401s produce exactly one refresh request | `AuthInterceptor._refreshCompleter` |
| BR-Y3 | A request is replayed at most once after refresh; a second 401 propagates | `__auth_retried__` flag |
| BR-Y4 | Refresh/replay must never pass through the intercepted client (no recursion; refresh token never bearer-wrapped) | Bare `refreshClient` |

## 6. Deletion rules

| ID | Rule | Enforced by |
|---|---|---|
| BR-D1 | Logout and failed refresh delete **all** session material (both tokens + cached user) atomically-in-intent | `clear()` deletes all three keys |
| BR-D2 | Session restore requires **both** cached user and token — a partial session is treated as none | `getCurrentUser` both-present check |
| BR-D3 | ⚠ Open rule (not implemented): whether logout must also purge other features' per-user local data on shared devices | Tracked in [Roadmap.md](roadmap.md) / `docs/blueprint/offline-architecture.md` §3.2 |

## 7. Retention rules

| ID | Rule | Enforced by |
|---|---|---|
| BR-T1 | A cached session has no client-side TTL; lifetime is bounded by server refresh-token validity | Design decision (field reps offline for days) |
| BR-T2 | No login history/audit data is retained on-device by this feature | Implementation (nothing is written beyond the session) |

## 8. SAP rules

| ID | Rule | Enforced by |
|---|---|---|
| BR-SAP1 | Auth never calls SAP directly; identity flows to SAP only through the gateway the bearer token authenticates | Architecture (SAP client is a tracked stub) |
| BR-SAP2 | Future: the signed-in user's identity/roles scope which SAP data (depots, routes, orders) syncs to the device | `docs/blueprint/sync-architecture.md` (planned) |

## 9. Release rules (compliance)

| ID | Rule | Status |
|---|---|---|
| BR-REL1 | Every debug shortcut must carry `// TODO(release-gate):` and be stripped from release builds | 🔴 **Violated** — mock login (G-1) and mock reset flow (G-2) are untagged; see [Security.md](security.md) §10 |
| BR-REL2 | No secrets/endpoints hardcoded — gateway host comes from Envied `.env` | ✅ Compliant (`Env.apiBaseUrl`; the old hardcoded host was removed) |
