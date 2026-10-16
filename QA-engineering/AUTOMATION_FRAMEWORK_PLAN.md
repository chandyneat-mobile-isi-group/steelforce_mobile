# SteelForce automation framework — plan

**Status:** approved 2026-10-08. **Phases 1–6 done** (foundation, Excel, engine,
API tests, device tests with screenshots, reports/history/write-back); Phase 7
(classifier extensions) and Phase 8 (CI/CD) remain — see
[`../automation/README.md`](../automation/README.md). The framework is built to be
reused by other mobile apps: the engine is project-agnostic, and everything
app-specific lives in a profile under `automation/projects/<name>/` (the folder
structure below reflects this).
**Scope of the first build:** Authentication, Session and Profile, matching the
workbook. Other modules plug in later through the same structure.
**Facts as of:** branch `uat` @ `644056f`, 2026-10-08. Every statement below
was checked against the repository. Where something could not be checked, the
text says so.

---

## 1. Current project structure

| Area | What exists |
|---|---|
| App | Flutter 3.44.9 stable. Clean architecture: `lib/core`, `lib/features/<feature>/{data,domain,presentation}`, `get_it`, `flutter_bloc`, Drift (encrypted). |
| Platforms | Android (no product flavors; `debug`, `main`, `profile` source sets), iOS, web. |
| Environment selection | No flavors. The API host comes from Envied-compiled `.env` (gitignored), **overridable at build time with `--dart-define=API_BASE_URL=…`** (`lib/core/config/app_config.dart:31`). Automation uses this hook to point a build at UAT without touching `.env`. |
| Backend | .NET (`backend/backend-server/src/ISI.Api`), routes under `/api/v1`. No API test suite or Postman collection found in that repo. |
| Devices on this Mac | iOS simulator (iPhone 17 Pro Max, running); Android emulators `Pixel_10_Pro_XL` and `Pixel_Tablet`; macOS; Chrome. |
| CI | None (no `.github/`, Codemagic, GitLab or Bitbucket config). |
| Python | System `python3` 3.9.6 (past end-of-life). pytest, httpx, pydantic and ruff are not installed. **`uv` is installed.** |

## 2. Existing testing capabilities

| Capability | State |
|---|---|
| Unit and widget tests | 237 `*_test.dart` files under `test/`. Full suite: 2,070 passing, 12 failing (the known baseline: test code out of date, not app failures). |
| Auth/profile/session tests | 24 files, **195 tests, all passing** (run 2026-10-08). |
| Integration tests | `integration_test` is in `dev_dependencies`, but **there is no `integration_test/` folder** and no `test_driver/`. No device test exists. |
| Machine-readable results | `flutter test --file-reporter json:<file>` works. It was used to build the workbook's automated run, so Python can parse Flutter results without scraping text. |
| API evidence from the app | Each request carries `X-Correlation-Id`. Debug logs `api.request`, `api.response` and `api.error` carry status, `errorCode`, `dioType`, `host` and `correlationId` (`api_log_interceptor.dart`). This logging goes through `dart:developer` and does appear in `flutter drive` stdout (verified in Phase 5, risk R6). |
| Backend contract tests | None anywhere. |

## 3. Existing Excel structure

`QA-engineering/SteelForce_Test_Cases.xlsx`. Nine sheets:

| Sheet | Rows | Role for the framework |
|---|---|---|
| Summary | — | Formula-driven. The framework doesn't touch it. |
| **Test_Cases** | 36 | **Test definitions** (16 columns, below). |
| Test_Scenarios | 9 | End-to-end journeys → future suites. |
| **Test_Data** | 10 | `TD-001…TD-008, TD-018, TD-019`. The value column points at secret-store names and never holds a secret. |
| **Automation_Mapping** | 36 | TC → status, level, existing test file, gap. |
| **Execution_Results** | 58 + template | Run history (25 columns incl. Issue Source, Correlation ID, Triage Check formula). |
| Bug_Log | 0 | Bugs raised from runs. |
| Triage_Matrix | 16 | Human triage guide. The classifier encodes the same rules. |
| **Dropdowns** | 13 lists | **Allowed values.** The validator reads these, so the workbook stays the single source. |

`Test_Cases` columns: TC ID · Module · Feature · Title · Priority · Test Type ·
Preconditions · Test Data · Steps · Expected Result · API Endpoint · Layers
Exercised · If It Fails — Check First · Evidence to Capture · Code Reference ·
Automation Status.

**Contents:**
- **Modules:** Authentication 20, Session 10, Profile 6.
- **Priority:** P1 24, P2 11, P3 1.
- **Types:** Functional 13, Negative 10, Security 6, Offline 3, UI 2, Localization 1, API 1.
- **Automation status:** Automated 17, Partial 7, Planned 12.

**How your requested fields map to the workbook.** The parser adapts to the
workbook; it doesn't rename anything.

| Requested | Workbook | Action |
|---|---|---|
| Test Case ID, Module, Feature, Priority, Test Type, Preconditions, Steps, Expected Result, Automation Status | Present | Read as is |
| Scenario | `Title` (the scenario sheet is separate) | Map `Title` → `scenario` |
| Test Data ID | `Test Data` (can hold several, e.g. `TD-003, TD-004`) | Parse as a list |
| Priority “Critical” | `P1/P2/P3` | CLI alias: critical → P1, high → P2, normal → P3 |
| Status | Lives in `Execution_Results`, per run | Not a test-case field |
| **Automation ID** | **Missing** | **Add one column to `Automation_Mapping`** (additive) |
| **Suites (smoke/regression)** | **Missing** | **Add one `Suites` column to `Test_Cases`** (additive) |
| **Environment** | Missing | Add an optional `Environments` column; blank = all except production |
| Issue Source “Automation” | Not in the dropdown | Add the value (additive). Example: the 12 baseline failures are broken test code, which is Automation, not Mobile. |

These are three new columns and one new dropdown value. Nothing is renamed or
removed, and existing formulas keep working.

## 4. Proposed Python architecture

Python orchestrates; each test level runs in its native tool.

```
 Excel (source of truth)
   │ reader → validator → TestCase models → filter (case/module/type/priority/suite/env)
   ▼
 Execution planner ── resolves each case's Automation IDs (explicit, no fuzzy matching)
   ├── pytest:<path>::<test>  → API runner (pytest, in-process plugin collects results + API evidence)
   ├── flutter:<path>[::name] → Flutter runner (`flutter test --file-reporter json`)        unit/widget
   ├── drive:<path>           → Flutter runner (`flutter drive` on a device/simulator)    integration
   └── manual                 → reported as Not Run (never faked)
   ▼
 Results (typed) + Evidence (per execution folder)
   ▼
 Failure analyzer → rule-based classifier → Issue Source, Type, Confidence, missing-evidence list
   ▼
 History store (SQLite, append-only) → regression detection (prev PASS, now FAIL)
   ▼
 Reports: HTML (developers) · results.xlsx (management) · optional write-back to Execution_Results
```

**Design rules:**
- Raw Excel rows never leave `excel/`; everything downstream uses `TestCase`.
- One HTTP client, one config loader, one masking function. Each of these
  exists only once.
- Results are immutable records; reports are views over them.
- The classifier only states a source that evidence supports. Otherwise it
  returns Unknown / Low and lists what is missing.

## 5. Flutter automation integration

- **No new mobile tool.** `flutter_test` + `integration_test` are already
  dependencies and cover widget and device flows. Appium/Patrol would add
  dependencies without a need we have shown. Patrol becomes worth discussing
  only if we must drive **native** OS dialogs (location/notification
  permission prompts). That decision is deferred to Phase 5, with evidence.
- **Unit/widget:** the existing 195 auth/profile tests map as-is
  (`flutter:test/features/authentication/remember_phone_test.dart`).
- **Device:** new Dart tests under `integration_test/auth/…`, run with
  `flutter drive --driver=test_driver/integration_test.dart`. The driver's
  `onScreenshot` saves screenshots to the host; plain `flutter test
  integration_test` cannot.
- **Pointing at UAT:** `--dart-define=API_BASE_URL=<from automation/.env.uat>`.
- **Credentials:** passed by `--dart-define` at test-build time from env vars.
  They are never in the repo, the workbook or the logs. Note: dart-defines are
  compiled into that test build, so test builds are never distributed (R5).
- **Evidence:** screenshot on failure, full Flutter stdout, stack trace,
  device/OS/app version from `flutter devices --machine` and `pubspec.yaml`.

## 6. API automation strategy

API tests check the **backend against the contract**
(`docs/feature/authentication/`). That's what lets a failing mobile test be
classified: if the API contract test passes and the device test fails, look at
Mobile first. If the contract test fails, it's Backend.

- `ApiClient` (httpx): base URL from env config, timeouts matching the app
  (connect 15 s, receive 20 s), `X-Correlation-Id` + `Accept-Language` on
  every call, bounded retry **only** for idempotent GETs on connect errors,
  every call recorded as an evidence record (masked).
- Domain modules for this scope: `auth.py` (login, refresh, me, logout,
  forgot-password, change-password) and `profile.py` (profile, photo). Depots,
  visits, quotations etc. come later. The domain term is **depot**; there will
  be no `customers.py`.
- **Safety markers** on every API test: `destructive` (changes data),
  `sms` (sends a real SMS), `lockout` (can lock an account). These are
  excluded by default and never allowed on production.
- Fixtures: `api_client`, `signed_in_rep` (TD-001), `temp_password_rep`
  (TD-002), loaded from `test_data/` by TD ID.

## 7. Test execution strategy

CLI (stdlib `argparse`):

```
python -m automation validate
python -m automation run [--env uat] [--suite smoke|regression] [--module authentication]
                         [--type negative] [--priority critical] [--case TC-AUTH-002]
                         [--level api|flutter|device] [--include destructive,sms]
python -m automation report [--exec EXEC-20261008-001]
python -m automation history --case TC-AUTH-002
```

- **Order:** validate → resolve → API tests → Flutter unit/widget → device
  tests. A run halts before execution if validation fails.
- **Invalid cases are reported and skipped**; valid ones still run.
- **Serial by default.** Parallel is designed in (the runners are independent)
  but switched off; see §12.
- **Execution ID:** `EXEC-YYYYMMDD-NNN`, unique per run.

## 8. Reporting strategy

Per execution, under `automation/reports/EXEC-…/` (gitignored):

- **`report.html`:** a self-contained page (stdlib templating, no extra
  dependency). Shows totals, pass rate, duration, failures by Issue Source,
  each failure's evidence and reasoning, and a regression banner.
- **`results.xlsx`:** the same columns as `Execution_Results`, so management
  reads one format.
- **Write-back (opt-in, `--write-back`):** appends rows to the master
  workbook's `Execution_Results`. It never overwrites, and it refuses if the
  file is open or locked.

## 9. Evidence strategy

```
automation/reports/EXEC-20261008-001/
├── metadata.json      env, git commit, app version, device, OS, filters, start/end, tool versions
├── report.html
├── results.xlsx
├── logs/run.log       structured log (masked)
├── api/<TC>/<n>.json  method, URL, status, ms, correlation id, masked request/response
├── flutter/<TC>.json  parsed reporter events + raw stdout
└── screenshots/<TC>/…
```

**Masking** happens in one place, before anything is written. Keys like
`password`, `token`, `otp`, `authorization`, `refreshToken`, `resetToken` are
masked, plus value shapes (JWT, phone numbers). The framework's own unit tests
assert this.

## 10. Root-cause analysis strategy

An ordered rule set over typed evidence. Each rule returns `(source, type,
confidence, reasoning, missing_evidence)`. The first rule that matches wins,
and the fallback is **Unknown / Low**. Examples:

| Evidence | Classification |
|---|---|
| Dart compile error, missing GetIt registration in a test, fixture error, Python exception inside the framework | **Automation**, High |
| Test account refused (`Auth.InvalidCredentials` / `AccountLocked` / `Inactive`) | Test Data, High (Medium if the account was verified active) |
| Connect error / `connectionTimeout`, no response | Network, Medium |
| Wrong host vs configured env, or 502/503 everywhere | Environment |
| `receiveTimeout` | **Unknown, Low**: “search backend log for correlation id …” |
| 5xx on a request that passed contract validation | Backend, High |
| `Sap.ApiError` / backend says SAP failed | SAP |
| API contract test passed, device test failed on displayed value | Mobile, High |
| Device test failed with no API evidence collected | Unknown, Low, listing what is missing |

It **never** classifies a failure as Mobile by default, nor treats every HTTP
error as Backend. Each rule has a unit test.

## 11. CI/CD strategy (later — Phase 8)

Not built until the local framework is stable. Target pipeline:

```
push → validate Excel → framework self-tests → flutter analyze + flutter test
     → API contract (UAT) → device smoke (emulator / Firebase Test Lab) → regression (nightly)
     → reports as artifacts → pass/fail gate
```

Secrets come from CI variables. Reports are uploaded as artifacts, and
history is persisted outside the runner.

## 12. Risks and limitations

| # | Risk | Mitigation |
|---|---|---|
| R1 | **Account lockout:** wrong-password tests can lock the shared QA account (5 failures, backend rule). | Negative login tests use a dedicated throwaway account and the `lockout` marker; they never run against TD-001. |
| R2 | **SMS reset flow** sends real SMS, and the OTP can't be read automatically. | `sms` marker, off by default. OTP verify/reset stay manual unless Backend provides a UAT-only test hook. |
| R3 | **Destructive tests** (change-password, photo upload) change shared accounts. | `destructive` marker; reset steps documented per TD; never on production. |
| R4 | **Refresh-token rotation:** reusing an old refresh token ends the session. | Refresh tests get their own fresh session. |
| R5 | Credentials passed by `--dart-define` are compiled into the test build. | Test builds are local/CI only and never distributed; values come from env vars. |
| R6 | App `api.*` logs go through `dart:developer`; it was unverified whether `flutter drive` stdout includes them. | **Resolved in Phase 5 (EXEC-20261008-012, iOS simulator):** they do (`flutter: [isi.error] api.error …`). The device runner attaches them to failing tests and the classifier reads them like API evidence. |
| R7 | Native permission dialogs can't be driven by `integration_test`. | Pre-grant permissions (`adb shell pm grant`, `simctl privacy`); revisit Patrol only if needed. |
| R8 | The workbook is edited by people; it can be open in Excel during write-back. | Write-back is opt-in, detects locks, and appends only. Per-run `results.xlsx` is always written. |
| R9 | **Parallel execution:** shared accounts, rate limits (429) and one simulator make parallel unsafe today. | Serial now. Enable per level once accounts are per-worker. |
| R10 | System Python is 3.9 (end-of-life). | Project-local Python 3.12 via `uv`; nothing installed system-wide. |
| R11 | The workbook covers only auth/profile. | The architecture is module-agnostic; new modules add cases plus API modules. |

## 13. Implementation phases

| Phase | Delivers | Done when |
|---|---|---|
| **1 Foundation** | `automation/` project (uv, Python 3.12, `pyproject.toml`, ruff + pytest config), config loader (YAML + `.env.<env>`, production guard), structured masked logger, exceptions, CLI skeleton, `.env.example`, gitignore entries | `python -m automation --help` works; self-tests for config, guard and masking pass |
| **2 Excel** | Reader, typed models, validator (rules from `Dropdowns`), filters, the 3 additive columns + 1 dropdown value | `validate` reports real errors; self-tests on fixture workbooks |
| **3 Execution engine** | Automation-ID resolver, planner, result model, execution IDs, evidence folders, history store | A run over the mapped Flutter tests records results |
| **4 API** | `ApiClient`, auth/profile modules, fixtures, markers, contract checks for login/me/profile/refresh | Contract tests run against UAT with real results |
| **5 Flutter** | Flutter runner (json reporter), `integration_test/auth/*` device tests, `test_driver`, screenshots, R6 check | Login smoke passes on the iOS simulator against UAT |
| **6 Reporting** | HTML, results.xlsx, write-back, regression detection | Reports generated from a real run |
| **7 Failure analysis** | Classifier rules + evidence linking | Every failure in a run has a source and confidence, with tests for every rule |
| **8 CI/CD** | Pipeline | Only after phases 1–7 are stable |

### Proposed folder structure

```
mobile/
├── QA-engineering/SteelForce_Test_Cases.xlsx      ← source of truth (3 columns added)
├── integration_test/                              ← Phase 5, Dart device tests
│   ├── auth/login_test.dart
│   └── support/                                   ← robots, evidence hooks
├── test_driver/integration_test.dart              ← Phase 5, screenshot driver
└── automation/
    ├── pyproject.toml   uv.lock   README.md
    ├── projects/
    │   └── steelforce/                  ← everything app-specific; add a folder per app
    │       ├── project.yaml             workbook path + column map, Flutter dir, secret names
    │       ├── environments/            dev.yaml  uat.yaml  staging.yaml  production.yaml
    │       ├── .env.example             placeholders (created by hand — see README)
    │       ├── test_data/               Phase 2+: TD-xxx → values / secret names
    │       └── api/                     Phase 4: this app's endpoint modules
    ├── src/automation/                  ← generic engine, names no app
    │   ├── __main__.py  cli.py
    │   ├── core/        config.py  logger.py  masking.py  exceptions.py  constants.py
    │   ├── excel/       reader.py  validator.py  writer.py  models.py
    │   ├── api/         client.py  (generic HTTP client; endpoint modules live in the profile)
    │   ├── mobile/      flutter_runner.py  devices.py  artifacts.py
    │   ├── execution/   planner.py  runner.py  filters.py  mapping.py
    │   ├── analysis/    evidence.py  classifier.py  rules.py
    │   ├── reporting/   html_report.py  excel_report.py  summary.py
    │   ├── history/     store.py  regression.py
    │   └── data/        test_data.py
    ├── tests/
    │   ├── framework/   ← self-tests (parser, validator, config, client, classifier, reports)
    │   └── api/         ← product API tests (test_auth.py, test_profile.py)
    └── reports/         ← gitignored, one folder per execution
```

**Dependencies (Python only; the Flutter app is untouched):** runtime
`pytest`, `openpyxl`, `httpx`, `pydantic`, `pyyaml`, `python-dotenv`; dev
`ruff`. `httpx.MockTransport` replaces a mocking library, stdlib templating
replaces Jinja/pytest-html, and stdlib `sqlite3` holds history.
