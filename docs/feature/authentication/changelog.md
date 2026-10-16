# Authentication — Changelog

> Reconstructed 2026-07-23 from git history on `demo/app01` (paths: `lib/features/authentication`, `lib/core/{auth,session,middleware}`) and the current implementation. Author identities per repo commits (mobile engineering team).

---

## [1.3.0] — 2026-07-23 (`bc1c20f` "complete language change")

- **Changes**: Full app-restart-on-language-change model finalized; auth-aware `_resolveInitialRoute` keeps signed-in users and guests on the shell across language switches (`_splashShown` latch prevents splash replay). Locale set finalized as **en + km** (kh→km migration).
- **Migration notes**: any doc referencing `kh.json` should read `assets/lang/km.json`.
- **Breaking changes**: none.

## [1.2.0] — 2026-07-13 (`ca78a0e` "resetpasword")

- **Changes**: Password-recovery UI added — `ForgotPasswordScreen`, `VerifyScreen` (6-digit OTP, 30 s resend cooldown), `CreateNewPasswordScreen`, `SuccessScreen`; routes `/forgot-password`, `/verify-otp`, `/create-new-password`, `/reset-password-success`. Screens are callback-driven; `app_page.dart` wires **placeholder** implementations (OTP `111111`).
- **Migration notes**: real backend wiring pending (Blueprint G-2).
- **Breaking changes**: none.

## [1.1.0] — 2026-07-13 (`0823fdf` "completed guest user, theme, app_coach")

- **Changes**: Guest-first model completed — `AuthGuestState` as default resting state, `AuthGuestRequested` event, `AuthGuard` + `context.requireAuth`, `LoginRequiredDialog`, guest shell surfaces gated via the guard; AppCoach no longer auto-launches. Global auth-redirect listener removed after causing duplicate redirects (documented as a prohibited pattern).
- **Breaking changes**: navigation ownership moved from global listener to per-surface transitions.

## [1.0.0] — 2026-07-07 → 2026-07-10 (`b307c5a` "improve architecture", `3a12e60` "UI demo 80%")

- **Changes**: Clean-Architecture auth triad established — `User`/`UserRole`/`AuthToken` entities, `AuthRepository` + 3 use cases, `AuthRepositoryImpl`, secure-storage local datasource (also serving as `TokenStore`), Dio remote datasource with typed exception mapping, `AuthBloc` (droppable login) mirroring `SessionManager`, `AuthInterceptor` with single-flight refresh, `registerAuthFeature` DI module, redesigned aurora/glass `LoginScreen`.
- **Migration notes**: `AuthBloc` provided at app root; per-route `BlocProvider` removed from `/login`.
- **Breaking changes**: none recorded.

## [0.x] — 2026-07-02 → 2026-07-06 (`640bcf5` … `62eb6fd`)

- Initial app scaffolding, main shell, early login UI iterations.

---

## Known technical debt carried forward

| Item | Introduced | Tracking |
|---|---|---|
| Untagged mock login credentials | 1.0.0 era | Blueprint G-1 / [Security.md](security.md) §10 — release blocker |
| Mocked reset-flow callbacks in `app_page.dart` | 1.2.0 | Blueprint G-2 |
| No automated tests for the feature | since inception | Blueprint G-3 |
| Session-expiry not propagated to UI on failed refresh | 1.0.0 | Blueprint G-5 |
