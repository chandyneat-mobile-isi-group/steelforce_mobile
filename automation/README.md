# Mobile QA automation framework

An Excel-driven automation framework for mobile apps. Python handles
orchestration, test data, API tests, evidence, failure triage and reporting.
UI and device tests stay in the app's own tool (Flutter `flutter_test` /
`integration_test`).

The engine (`src/automation/`) knows nothing about any one app. Each app is a
**project profile** under `projects/<name>/`. SteelForce is the first one.

> Status: **Phases 1–6 done** — Excel reader, validator and filters;
> execution engine; Flutter unit/widget tests, Python API contract tests and
> device tests with screenshots, each with evidence and evidence-based failure
> classification; HTML/Excel reports, execution history, regression detection
> and workbook write-back. Next: classifier extensions (Phase 7), CI/CD
> (Phase 8). See
> [`../QA-engineering/AUTOMATION_FRAMEWORK_PLAN.md`](../QA-engineering/AUTOMATION_FRAMEWORK_PLAN.md).

## Setup

Needs [`uv`](https://docs.astral.sh/uv/). It installs a project-local Python
3.12; nothing is installed system-wide.

```bash
cd automation
uv sync                                # creates .venv with Python 3.12 + dependencies
uv run python -m automation doctor     # checks Python, workbook, Flutter, secrets
```

### Secrets

Copy the template and fill in real values. The copies are gitignored.

```bash
cp projects/steelforce/.env.example projects/steelforce/.env.uat
```

Every secret can also be exported in the shell or in CI, and process values
win over the file. Only names listed under `secrets:` in `project.yaml` are
read from the process. **Never** put a real value in `project.yaml`, an
environment YAML, the workbook, or a test.

## Commands

```bash
uv run python -m automation projects                 # list project profiles
uv run python -m automation config --env uat         # resolved config (secret names only)
uv run python -m automation doctor --env uat         # local setup check
uv run python -m automation validate                 # check the workbook before running
uv run python -m automation run --suite smoke        # or --suite regression
uv run python -m automation run --module authentication --priority critical
uv run python -m automation run --case TC-AUTH-002,TC-AUTH-004
uv run python -m automation run --suite smoke --write-back       # also append results to the workbook
uv run python -m automation run --level device --device "iPhone 17 Pro Max" --env staging
uv run python -m automation report                               # rebuild reports for the latest run
uv run python -m automation report --exec EXEC-20261008-001 --write-back
uv run python -m automation history --case TC-AUTH-002          # one case across runs
```

### How a test case reaches an automated test

Each case's **Automation ID** (sheet `Automation_Mapping`) names its tests
explicitly, separated by `;`:

| Automation ID | Runs |
|---|---|
| `flutter:test/features/authentication/remember_phone_test.dart` | every test in that Dart file (`flutter test`) |
| `flutter:test/…/x_test.dart::exact full test name` | only that test |
| `pytest:tests/api/test_auth.py::test_login` | a Python API test |
| `drive:integration_test/auth/login_device_test.dart` | a device test with screenshots (`flutter drive`) |
| `manual` | nothing — reported as **Not Run**, never as passed |

Each file runs once per execution, however many cases point at it. Evidence
for every run is kept in `reports/EXEC-YYYYMMDD-NNN/`: `report.html`,
`report.xlsx`, `metadata.json`, `results.json`, `logs/run.log`, raw Flutter
output under `flutter/`, HTTP calls under `api/`, device output under
`device/` and screenshots under `screenshots/`.

| Exit code | Meaning |
|---|---|
| 0 | Success |
| 1 | Tests failed |
| 2 | Configuration or usage error |
| 3 | Refused by the environment guard |
| 4 | Nothing to report on yet (no execution / no history for that case) |
| 5 | No failures, but some cases were Blocked (could not run) |

## API tests

A project's API tests live in its profile: endpoint modules in
`projects/<app>/api/`, tests in `projects/<app>/tests/api/`. They import
the profile as a package (`from steelforce.api.auth import AuthApi`) and get
these fixtures from the framework:

| Fixture | Gives |
|---|---|
| `run_context` | the resolved project, environment and secrets |
| `api_client` | the one HTTP client: base URL, prefix, timeouts, correlation id, retries, masked evidence |
| `secret("NAME")` | a secret's value — or the test is **Blocked**, naming what is missing |

Mark tests that are risky to run: `@pytest.mark.destructive`, `sms` or
`lockout`. They are held back unless the run says `--include <marker>`, and
never run on a protected environment.

A missing secret never turns into a pass or a silent skip. The case is
**Blocked** with Issue Source *Test Data*, and the run exits with code 5.

## Device tests

Device tests are Dart files in the app's `integration_test/`, written with
`automationTest(...)` from `integration_test/support/automation_harness.dart`
instead of `testWidgets`. The harness records each test's outcome and takes a
screenshot when a test fails; `captureScreen(tester, 'name')` adds more. The
host driver `test_driver/integration_test.dart` saves both into the
execution folder.

- **Choose a device** with `--device <id or name>` (see `flutter devices`) or
  `flutter.device` in the environment file. Without one, device references
  are **Skipped** and named in the notes; with one that is not booted, they
  are **Blocked**.
- **Configuration** reaches the app as `--dart-define`, mapped from secrets in
  `project.yaml` → `flutter.dart_defines` (SteelForce: `API_BASE_URL`,
  `QA_PHONE`, `QA_PASSWORD`). Values are never written to a file, and every
  exact value is redacted from the kept output.
- Failures on a device are never pinned on one layer by guesswork: a timeout
  is *Unknown/Low* with the cross-checks named (screenshots, the same case's
  API tests, the device log).
- Screenshots of the app can show test-account data on screen (the phone
  number on the login screen). `reports/` is gitignored; share an execution
  folder only with people who may see that account.

## Reports, history and write-back

Every `run` writes `report.html` (open it in a browser; links and
screenshots are relative, so the folder can be zipped) and `report.xlsx`
(same columns as the workbook's `Execution_Results`). `report --exec <id>`
rebuilds both from the stored results at any time.

Each run is also appended to `history/<project>.jsonl` (gitignored). A case
whose last verdict on the same environment was Pass and is now Fail is a
**REGRESSION**; Fail → Pass is **FIXED**. Both are printed, shown in the
reports and kept in `metadata.json`. `history --case <id>` lists a case's runs
and flags a verdict that keeps flipping.

`--write-back` appends one row per automated case to `Execution_Results`
(manual cases stay for people). It refuses while Excel has the file open,
never writes the same run twice, copies the workbook into the execution
folder first, keeps the Triage Check formula going, writes evidence text as
text (never as a formula) and replaces the file atomically. Root Cause is
written as *Probable (…)* — a person confirms it. To see the run on the
Summary sheet, set `Summary!B3` to the execution id.

## Environment safety

An environment with `protected: true` (SteelForce: `production`) is refused
unless **both** of these are given:

```bash
export AUTOMATION_ALLOW_PROTECTED="I understand this targets a protected environment"
uv run python -m automation run --env production --allow-protected
```

Tests marked `destructive`, `sms` or `lockout` are refused on a protected
environment even then. Everywhere else they only run with
`--include destructive,…`.

## Using this framework for another mobile app

1. Copy the `automation/` folder into the other app's repository. Or keep one
   copy and point `AUTOMATION_PROJECTS_DIR` / `--projects-dir` at a folder of
   profiles.
2. Create `projects/<app>/` with the following. Copy `projects/steelforce/`
   as a starting point.
   - `project.yaml`: name (must match the folder), `app_root`, workbook path,
     **sheet and column mapping**, Flutter project dir, secret names, extra
     masking keys.
   - `environments/<env>.yaml`: one per environment, with `workbook_label`
     (its name in the workbook's Environment column). Mark production
     `protected: true`.
   - `flutter.dart_defines` if device tests need configuration, and copy
     `integration_test/support/automation_harness.dart` plus
     `test_driver/integration_test.dart` into the app.
   - `.env.example`: placeholders for the secrets.
3. If the app's workbook uses different column headers, change only
   `workbook.columns`. The engine reads columns by this map, never by
   position or hard-coded header.
4. `uv run python -m automation doctor --project <app>`.

Nothing in `src/automation/` should mention a specific app. If you need to,
the thing belongs in the project profile.

## Development

```bash
uv run pytest                 # framework self-tests (tests/framework)
uv run ruff check . && uv run ruff format --check .
```

```
automation/
├── pyproject.toml           dependencies, pytest + ruff config
├── projects/steelforce/     project profile (config only)
├── src/automation/
│   ├── cli.py               command line
│   ├── core/                config, guard, masking, logger, constants, exceptions
│   ├── excel/               workbook reader, validator, write-back
│   ├── execution/           filters, engine, outcomes, workspace, session
│   ├── mobile/              flutter test runner, device runner (flutter drive), app info
│   ├── api/                 HTTP client, evidence, pytest plugin and runner
│   ├── analysis/            failure classification rules (Flutter, device, API)
│   ├── history/             execution history and regression detection
│   └── reporting/           console summary, HTML and Excel reports
├── reports/  history/       run output (gitignored)
└── tests/framework/         self-tests for the framework itself
```
