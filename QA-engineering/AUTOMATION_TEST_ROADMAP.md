# Automation roadmap — Authentication & Profile

Where automation stands for the 36 auth, session and profile cases, and what
to automate next. Per-case detail is in the `Automation_Mapping` sheet of
[`SteelForce_Test_Cases.xlsx`](SteelForce_Test_Cases.xlsx).

## 1. Today

| Status | Cases |
|---|---|
| Automated | 17 |
| Partial | 7 |
| Manual only | 12 |

The existing tests are unit and widget tests with fakes. They run in CI in
seconds and passed 195/195 on 2026-10-08. **Nothing yet runs against the real
UAT backend or on a device.** So these tests can say the app logic is right,
but not where a live failure comes from. That's what the later phases add.

## 2. Layers

| Layer | Tool | Finds | Runs |
|---|---|---|---|
| Unit / widget | `flutter test`, mocktail, in-memory Drift | Mobile logic, validation, error mapping, layout | Every PR |
| Integration on device | `integration_test/` + `flutter drive` (Firebase Test Lab later) | Mobile flows end to end with a faked or UAT backend | Nightly |
| API contract | Backend repo / Postman collection against UAT | Backend vs contract (`docs/feature/authentication/`) | Nightly, before mobile E2E |
| Manual UAT | This workbook | What automation can't do: SMS, real accounts, Khmer reading | Each release candidate |

The contract layer is what separates **Mobile from Backend** when a device
test fails. If the contract checks pass and the device test fails, look at
mobile first; if the contract checks fail, it's Backend.

## 3. Phases

### Phase 1 — close the unit/widget gaps (mobile repo, cheap)

| Case | Test to add |
|---|---|
| TC-AUTH-001 | Widget test: both login validators, and no request sent |
| TC-AUTH-004 | Widget test: the error pill shows the server message |
| TC-AUTH-005 | Repository test: one case per `Auth.*` errorCode |
| TC-AUTH-006, 007, 018 | Repository tests: offline, unreachable, 5xx, timeout, `/auth/me` failure (tokens cleared) |
| TC-AUTH-010 | Splash routing test for a pending temporary password |
| TC-AUTH-012, 013 | OTP screen widget test: incomplete code, paste, auto-submit, 30 s cooldown, failed resend |
| TC-AUTH-020 | Widget test in `km` with `NetworkFailure` on each reset step |
| TC-SES-001 | AuthBloc restore test: cached profile plus token, offline |
| TC-SES-009 | After the expected UX is agreed: widget test for what happens on expiry |

### Phase 2 — device integration tests (mobile repo)

There is no `integration_test/` folder yet. Start with:

1. Login, then the main shell (TD-001).
2. Temporary password: forced change, then the main shell (TD-002, reset before each run).
3. Logout blocked by unsent work, then sync, then logout.
4. Rep switch wipes data (TD-001, then TD-005).

The test reads credentials from `--dart-define` values injected by CI
secrets, **never** from the repository or this workbook. Every failed step
saves a screenshot and the `api.*` log lines (with correlation ids) as
artifacts, so the result can be triaged with
[`ISSUE_TRIAGE_GUIDE.md`](ISSUE_TRIAGE_GUIDE.md).

### Phase 3 — UAT pipeline

1. API contract checks for login, refresh-token, me, profile, profile-photo
   and the forgot-password steps.
2. Device tests on Firebase Test Lab against UAT, after the contract checks
   pass.
3. Results go into `Execution_Results` with Issue Source pre-filled from the
   failing layer.

### Stays manual

- **SMS reset (TC-AUTH-011…015):** needs a real handset receiving the SMS.
- **Lockout (TC-AUTH-019):** a backend rule; a backend API test should own it.
- **Khmer reading quality:** a person reads it.

## 4. Done means

A case moves to **Automated** only when its test is in `test/` or
`integration_test/`, runs in CI, and has passed at least once. Record the run
in `Execution_Results` with the real date and pass count.
