import json
import stat
from datetime import date
from pathlib import Path

import pytest

from automation.analysis.classifier import diagnose_device_failures
from automation.core.constants import Confidence, IssueSource, ResultStatus
from automation.core.masking import Masker
from automation.execution.engine import Engine
from automation.execution.results import TestFailure
from automation.execution.workspace import Workspace
from automation.mobile.device_runner import (
    NO_DEVICE,
    DeviceRunner,
    os_label,
    parse_results,
    slug,
)
from automation.mobile.flutter_runner import BatchResult, FileReport, FlutterTestResult
from tests.framework.test_execution import FakeFlutter, make_case

TARGET = "integration_test/auth/login_device_test.dart"
SECRET = "hunter2-device"

# A stand-in for the flutter tool: `devices --machine` lists one simulator;
# `drive` writes what test_driver/integration_test.dart would, and echoes the
# secret dart-define to stdout the way a careless log line might.
FAKE_FLUTTER = """#!/bin/sh
if [ "$1" = "devices" ]; then
  echo 'Waiting for devices...'
  echo '[{"id":"SIM-1","name":"iPhone Test","sdk":"iOS 26.0"}]'
  exit 0
fi
for arg in "$@"; do case "$arg" in --dart-define=QA_PASSWORD=*) pw="${arg#*=QA_PASSWORD=}";; esac; done
echo "launching with $pw"
echo "flutter: [isi.error] api.error method=GET path=/api/v1/x host=h status=500 ms=1 errorCode=General.Boom correlationId=c-1 dioType=badResponse"
mkdir -p "$AUTOMATION_DEVICE_EVIDENCE" "$AUTOMATION_SCREENSHOT_DIR"
printf 'PNG' > "$AUTOMATION_SCREENSHOT_DIR/login-screen.png"
cat > "$AUTOMATION_DEVICE_EVIDENCE/results.json" <<'JSON'
{"tests": {"signs in": {"result": "success"},
           "shows profile": {"result": "failure", "details": "Timed out after 30s waiting for the profile screen."}},
 "screenshots": []}
JSON
exit 1
"""


@pytest.fixture
def fake_flutter(tmp_path: Path) -> str:
    path = tmp_path / "flutter"
    path.write_text(FAKE_FLUTTER)
    path.chmod(path.stat().st_mode | stat.S_IEXEC)
    return str(path)


def _runner(tmp_path: Path, flutter: str, device: str | None = "SIM-1") -> DeviceRunner:
    app = tmp_path / "app"
    (app / "test_driver").mkdir(parents=True, exist_ok=True)
    (app / "test_driver" / "integration_test.dart").touch()
    return DeviceRunner(
        app, device, Path("test_driver/integration_test.dart"),
        {"QA_PASSWORD": SECRET, "FLAG": "1"}, Masker(), flutter=flutter,
    )  # fmt: skip


def test_simulator_runtimes_read_as_os_versions() -> None:
    assert os_label("com.apple.CoreSimulator.SimRuntime.iOS-26-5") == "iOS 26.5 (simulator)"
    assert os_label("Android 15 (API 35)") == "Android 15 (API 35)"


def test_results_file_becomes_a_file_report(tmp_path: Path) -> None:
    path = tmp_path / "results.json"
    path.write_text(json.dumps({"tests": {"a": {"result": "success"}, "b": "failure"}}))
    report = parse_results(path, TARGET)
    assert [(t.name, t.result) for t in report.tests] == [("a", "success"), ("b", "failure")]


def test_drive_results_screenshots_and_redacted_output(tmp_path: Path, fake_flutter: str) -> None:
    runner = _runner(tmp_path, fake_flutter)
    batch = runner.run([TARGET], tmp_path / "exec" / "device", tmp_path / "exec" / "screenshots")

    assert batch.infrastructure_error == ""
    assert batch.exit_code == 1
    assert runner.device_info is not None and runner.device_info.os == "iOS 26.0"
    tests = {t.name: t for t in batch.files[TARGET].tests}
    assert {n: t.result for n, t in tests.items()} == {
        "signs in": "success",
        "shows profile": "failure",
    }
    assert "status=500" in tests["shows profile"].details  # app request log attached
    assert tests["signs in"].output == []
    evidence = batch.extra_evidence[TARGET]
    assert any(p.name == "login-screen.png" for p in evidence)
    stdout = next(p for p in evidence if p.name == "drive.stdout.txt").read_text()
    assert SECRET not in stdout and "launching with ***" in stdout


def test_no_device_blocks_with_the_fix(tmp_path: Path, fake_flutter: str) -> None:
    batch = _runner(tmp_path, fake_flutter, device=None).run([TARGET], tmp_path, tmp_path)
    assert batch.infrastructure_error == NO_DEVICE


def test_a_device_that_is_not_booted_blocks(tmp_path: Path, fake_flutter: str) -> None:
    batch = _runner(tmp_path, fake_flutter, device="Pixel").run([TARGET], tmp_path, tmp_path)
    assert "not connected or booted" in batch.infrastructure_error


@pytest.mark.parametrize(
    ("message", "source", "confidence"),
    [
        ("QA_PHONE / QA_PASSWORD were not passed as --dart-define.", IssueSource.TEST_DATA, Confidence.HIGH),
        ("Timed out after 30s waiting for the login screen.", IssueSource.UNKNOWN, Confidence.LOW),
        ("Expected: <Instance of 'AuthenticatedState'>", IssueSource.UNKNOWN, Confidence.LOW),
    ],
)  # fmt: skip
def test_device_failures_never_rule_out_the_backend(message, source, confidence) -> None:
    diagnosis = diagnose_device_failures([TestFailure("drive:x", "t", message)])
    assert (diagnosis.source, diagnosis.confidence) == (source, confidence)
    if source is IssueSource.UNKNOWN:
        assert any("API tests" in m for m in diagnosis.missing_evidence)


APP_LOG = (
    "Expected: <Instance of 'AuthenticatedState'>\n"
    "api.error method=POST path=/api/v1/mobile/auth/login host=stg.example status=530 ms=60 "
    "signedIn=false errorCode=Client.Unknown correlationId=null dioType=badResponse"
)


def test_the_apps_own_request_log_decides_a_device_failure() -> None:
    diagnosis = diagnose_device_failures([TestFailure("drive:x", "signs in", APP_LOG)])
    assert (diagnosis.source, diagnosis.confidence) == (IssueSource.ENVIRONMENT, Confidence.HIGH)
    assert diagnosis.reasoning.startswith("From the app's request log")
    assert diagnosis.facts["http_status"] == 530
    assert diagnosis.facts["endpoint"] == "POST /api/v1/mobile/auth/login"


def test_an_offline_request_in_the_app_log_points_at_the_network() -> None:
    line = APP_LOG.replace("status=530", "status=null").replace("badResponse", "connectionError")
    diagnosis = diagnose_device_failures([TestFailure("drive:x", "t", line)])
    assert diagnosis.source is IssueSource.NETWORK


def test_a_response_the_test_made_up_is_never_blamed_on_the_backend() -> None:
    log = APP_LOG.replace("status=530", "status=400") + (
        "\n[automation] injected response: POST /api/v1/mobile/auth/login 400"
    )
    diagnosis = diagnose_device_failures([TestFailure("drive:x", "refused", log)])
    assert diagnosis.source is IssueSource.UNKNOWN
    assert "made up by the test" in diagnosis.reasoning


class FakeDevice:
    def __init__(self, batch: BatchResult) -> None:
        self.batch = batch

    def run(self, targets, evidence_dir, screenshots_dir) -> BatchResult:
        return self.batch


def test_device_refs_flow_through_the_engine_with_screenshots(tmp_path: Path) -> None:
    workspace = Workspace.create(tmp_path / "reports", date(2026, 10, 8))
    shot = workspace.path("screenshots", slug(TARGET), "after-sign-in.png")
    shot.parent.mkdir(parents=True)
    shot.write_bytes(b"PNG")
    report = FileReport(TARGET, [FlutterTestResult("signs in", "success")])
    device = FakeDevice(BatchResult({TARGET: report}, 0, extra_evidence={TARGET: [shot]}))
    engine = Engine(workspace, FakeFlutter(BatchResult({}, 0)), device_runner=device)

    result = engine.run([make_case(refs=f"drive:{TARGET}")]).results[0]
    assert result.status is ResultStatus.PASS
    assert f"screenshots/{slug(TARGET)}/after-sign-in.png" in result.evidence


def test_without_a_device_device_refs_are_skipped_and_named(tmp_path: Path) -> None:
    workspace = Workspace.create(tmp_path / "reports", date(2026, 10, 8))
    report = FileReport("test/a_test.dart", [FlutterTestResult("ok", "success")])
    engine = Engine(workspace, FakeFlutter(BatchResult({"test/a_test.dart": report}, 0)))
    case = make_case(refs=f"flutter:test/a_test.dart;drive:{TARGET}")
    result = engine.run([case]).results[0]
    assert result.status is ResultStatus.PASS  # the device part did not block the case
    assert f"Not run: drive:{TARGET} — no device selected" in result.notes
