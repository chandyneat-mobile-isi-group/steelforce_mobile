# Authentication — Future Improvements Roadmap

> Generated 2026-07-23. Ordered by dependency and risk, not wishlist priority. Items referencing G-n map to the [Blueprint](README.md) §12 gap analysis. All infrastructure-dependent items must respect the module-by-module rule (`docs/skills/engineering-standard.md` §2).

---

## P0 — Correctness & release safety

1. **Tag and gate every mock** (G-1, G-2): `// TODO(release-gate):` on the mock-login branch and the three `app_page.dart` reset stubs; wire the CI grep gate so a release build fails while they exist.
2. **Test debt** (G-3): domain/data/bloc/interceptor suites per [QA_Test_Plan.md](testing.md) §8 — the interceptor suite is a security control (100% branch).
3. **Session-expiry propagation** (G-5): on failed refresh, surface a signal (e.g. interceptor → `SessionManager` stream → `AuthBloc` emits `UnauthenticatedState` → affected surfaces degrade to Guest with a non-blocking notice). This finally gives `UnauthenticatedState` its intended job.

## P1 — Real backend wiring

4. **Reset-flow domain slice** (G-2): repository methods + use cases (`RequestPasswordReset`, `VerifyOtp`, `ResetPassword`), AuthBloc events named as the code comments anticipate (`VerifyOtpRequestedEvent`, `ResetPasswordRequestedEvent`), endpoint constants, and replacement of the `app_page.dart` callbacks. Screens need no redesign — they were built callback-first for exactly this handoff.
5. **Identifier rename** (G-6): `LoginSubmittedEvent.email` → `identifier` once the backend contract distinguishes email/phone; expose `IdentifierField.mode` in the payload if required.
6. **Contract tests** for `UserModel.fromMap` (G-7): unknown role names currently throw (`UserRole.values.byName`) — decide skip-vs-fail and pin with a test.

## P2 — Security hardening

7. **Certificate pinning** on `AppNetwork` clients (app-wide item, auth benefits first).
8. **Biometric / PIN app-lock** for cached sessions: optional re-lock on app foreground after a timeout — mitigates the device-possession threat for shared field devices.
9. **Logout data hygiene** (BR-D3): define and implement whether logout purges other features' per-user data (ties into the encrypted-DB user scoping and `WorkflowSession.userId` work in `docs/blueprint/offline-architecture.md` §3.2).
10. **Password policy alignment** with backend (length/complexity/breach checks) once the real auth service is live.

## P3 — Authorization & enterprise identity

11. **RBAC activation**: per-role gating via `SessionManager.can/canAny` once Organization/Role/Permission sync exists (`docs/blueprint/offline-architecture.md` §4 — currently "Missing"). `AuthGuard` should grow a `requireRole(...)` variant so gating stays centralized (BR-P1).
12. **Post-login action resume**: after a guard-triggered login, optionally resume the originally requested action instead of landing on the shell (UX decision — see UC-4 note).
13. **SSO / directory integration** if ISI group identity requires it (gateway-side first).

## P4 — UX & polish

14. **Request-access flow**: wire `LoginScreen.onRequestAccess` (currently unwired) to a real "request an account" path for new reps.
15. **Auth telemetry**: login success/failure rates, guard-dialog conversion ("Login Now" vs "Later"), refresh-failure counts — PII-free, per `docs/skills/security.md` §10.
16. **Accessibility pass**: semantic labels on OtpField boxes and visibility toggles; large-font audits (QA DEV-04/05 formalized).

## P5 — Architecture housekeeping

17. Align `AuthBloc` DI registration (factory vs root-singleton) with a comment or `registerLazySingleton`.
18. Replace the silent `catch (_)` in best-effort logout with a debug-level structured log (`core/logging/app_logger.dart` when it exists).
19. Reachability-based `NetworkInfo` (ADR-005, core-owned — G-4): auth's fail-fast login inherits it.

## AI-assisted (exploratory)

20. **Anomaly signals**: on-device heuristics for unusual login patterns (new geography burst, brute-force retry pacing) surfaced to the gateway — design only after real auth telemetry (item 15) exists.
