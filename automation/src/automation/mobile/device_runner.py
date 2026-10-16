"""Runs device tests (``integration_test/``) with ``flutter drive``.

One ``flutter drive`` per test file — that is how the tool works. The host
driver (``test_driver/integration_test.dart``) writes ``results.json`` and the
screenshots into folders passed through the environment; this module turns
them into the same report shape as ``flutter test``, so outcomes, diagnosis
and reports treat both alike.

Configuration reaches the app as ``--dart-define`` values resolved from
Secrets. They are never written to disk, and every exact secret value is
redacted from the tool output before it is kept as evidence.
"""

import json
import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from automation.core.logger import get_logger, log_fields
from automation.core.masking import Masker
from automation.mobile.flutter_runner import BatchResult, FileReport, FlutterTestResult

log = get_logger("device")

REDACTED = "***"
NO_DEVICE = (
    "No device configured: set flutter.device in the environment file or pass "
    "--device (see `flutter devices`)."
)


@dataclass(frozen=True)
class DeviceInfo:
    id: str
    name: str
    os: str

    def to_dict(self) -> dict[str, str]:
        return {"id": self.id, "name": self.name, "os": self.os}


_SIM_RUNTIME = re.compile(r"SimRuntime\.(?P<os>[A-Za-z]+)-(?P<version>[\d-]+)$")


def os_label(sdk: str) -> str:
    """``com.apple.CoreSimulator.SimRuntime.iOS-26-5`` → ``iOS 26.5 (simulator)``."""
    match = _SIM_RUNTIME.search(sdk)
    if not match:
        return sdk
    return f"{match['os']} {match['version'].replace('-', '.')} (simulator)"


def slug(target: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", target).strip("_")


def parse_results(path: Path, target: str) -> FileReport:
    data = json.loads(path.read_text(encoding="utf-8"))
    report = FileReport(target)
    for name, outcome in (data.get("tests") or {}).items():
        outcome = outcome if isinstance(outcome, dict) else {"result": str(outcome)}
        result = "success" if outcome.get("result") == "success" else "failure"
        report.tests.append(FlutterTestResult(name, result, message=outcome.get("details", "")))
    return report


class DeviceRunner:
    def __init__(
        self,
        project_dir: Path,
        device: str | None,
        driver: Path,
        dart_defines: dict[str, str],
        masker: Masker,
        timeout_s: float = 1800,
        flutter: str | None = None,
    ) -> None:
        self._project_dir = project_dir
        self._device = device
        self._driver = driver
        self._defines = dart_defines
        self._masker = masker
        self._timeout_s = timeout_s
        self._flutter = flutter or shutil.which("flutter")
        self.device_info: DeviceInfo | None = None

    def describe(self) -> DeviceInfo | None:
        """Name and OS of the configured device, from ``flutter devices``."""
        if not (self._flutter and self._device):
            return None
        try:
            listed = subprocess.run(
                [self._flutter, "devices", "--machine"],
                cwd=self._project_dir, capture_output=True, text=True, timeout=120, check=False,
            )  # fmt: skip
            devices = json.loads(listed.stdout[listed.stdout.find("[") :] or "[]")
        except (subprocess.TimeoutExpired, json.JSONDecodeError):
            return None
        wanted = self._device.lower()
        for d in devices:
            if wanted in (str(d.get("id", "")).lower(), str(d.get("name", "")).lower()):
                return DeviceInfo(d.get("id", ""), d.get("name", ""), os_label(d.get("sdk", "")))
        return None

    def run(self, targets: list[str], evidence_dir: Path, screenshots_dir: Path) -> BatchResult:
        if self._flutter is None:
            return BatchResult({}, None, "Flutter SDK not found on PATH.")
        if not self._device:
            return BatchResult({}, None, NO_DEVICE)
        self.device_info = self.describe()
        if self.device_info is None:
            return BatchResult({}, None, f"Device {self._device!r} is not connected or booted.")
        if not (self._project_dir / self._driver).is_file():
            return BatchResult({}, None, f"Driver {self._driver} not found in the app.")
        files: dict[str, FileReport] = {}
        extra: dict[str, list[Path]] = {}
        worst: int | None = 0
        for target in targets:
            code, report, evidence = self._run_one(target, evidence_dir, screenshots_dir)
            extra[target] = evidence
            if report is not None:
                files[target] = report
            worst = code if code is None or (worst is not None and code > worst) else worst
        return BatchResult(files, worst, extra_evidence=extra)

    def _run_one(
        self, target: str, evidence_dir: Path, screenshots_dir: Path
    ) -> tuple[int | None, FileReport | None, list[Path]]:
        out = evidence_dir / slug(target)
        shots = screenshots_dir / slug(target)
        out.mkdir(parents=True, exist_ok=True)
        stdout = out / "drive.stdout.txt"
        results = out / "results.json"
        command = [
            self._flutter or "flutter", "drive",
            f"--driver={self._driver.as_posix()}", f"--target={target}",
            "-d", self._device or "",
            *(f"--dart-define={k}={v}" for k, v in self._defines.items()),
        ]  # fmt: skip
        env = {
            **os.environ,
            "AUTOMATION_DEVICE_EVIDENCE": str(out),
            "AUTOMATION_SCREENSHOT_DIR": str(shots),
        }
        log.info("flutter drive", **log_fields(target=target, device=self._device))
        code: int | None
        try:
            with stdout.open("w", encoding="utf-8") as handle:
                code = subprocess.run(
                    command, cwd=self._project_dir, stdout=handle, stderr=subprocess.STDOUT,
                    env=env, timeout=self._timeout_s, check=False,
                ).returncode  # fmt: skip
        except subprocess.TimeoutExpired:
            code = None
            with stdout.open("a", encoding="utf-8") as handle:
                handle.write(f"\n[automation] flutter drive timed out after {self._timeout_s}s\n")
        self._redact(stdout)
        report = None
        if results.is_file():
            self._redact(results)
            report = parse_results(results, target)
            _attach_app_api_errors(report, stdout)
        screenshots = sorted(shots.glob("*.png")) if shots.is_dir() else []
        return code, report, [stdout, *([results] if results.is_file() else []), *screenshots]

    def _redact(self, path: Path) -> None:
        text = path.read_text(encoding="utf-8", errors="replace")
        for value in self._defines.values():
            if len(value) >= 4:  # short values (flags) are not secrets and would shred text
                text = text.replace(value, REDACTED)
        path.write_text(self._masker.mask_text(text), encoding="utf-8")


def _attach_app_api_errors(report: FileReport, stdout: Path, keep: int = 10) -> None:
    """A failing device test carries the app's own failed-request log lines, so
    triage can see what the backend answered (status, path, correlation id)."""
    lines = [
        line.removeprefix("flutter: ").strip()
        for line in stdout.read_text(encoding="utf-8", errors="replace").splitlines()
        if "api.error" in line or "[automation] injected response" in line
    ][-keep:]
    for test in report.tests:
        if test.result != "success":
            test.output.extend(lines)
