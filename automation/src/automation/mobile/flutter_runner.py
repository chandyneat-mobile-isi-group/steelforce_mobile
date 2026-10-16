"""Runs Flutter unit/widget tests and reads their machine-readable results.

Python orchestrates; the tests themselves stay in Dart. Results come from
``flutter test --file-reporter json:<file>`` (one JSON event per line), never
from scraping console text.
"""

import json
import shutil
import subprocess
from collections.abc import Iterable
from dataclasses import dataclass, field
from pathlib import Path

from automation.core.logger import get_logger, log_fields

log = get_logger("flutter")

LOADING_PREFIX = "loading "
MAX_DETAILS = 8000


@dataclass
class FlutterTestResult:
    name: str
    result: str  # success | failure | error
    skipped: bool = False
    message: str = ""
    stack: str = ""
    # Widget-test exceptions arrive as `print` events; the `error` event then
    # only says "Test failed. See exception logs above.".
    output: list[str] = field(default_factory=list)

    @property
    def is_load_error(self) -> bool:
        return self.name.startswith(LOADING_PREFIX)

    @property
    def details(self) -> str:
        """Error text plus the printed exception, capped for evidence and triage."""
        return "\n".join([self.message, *self.output]).strip()[:MAX_DETAILS]


@dataclass
class FileReport:
    path: str
    tests: list[FlutterTestResult] = field(default_factory=list)

    def select(self, name: str | None) -> list[FlutterTestResult]:
        """All tests, or only the test whose full name is exactly ``name``."""
        if name is None:
            return self.tests
        return [t for t in self.tests if t.name == name or t.is_load_error]


@dataclass
class BatchResult:
    files: dict[str, FileReport]
    exit_code: int | None
    infrastructure_error: str = ""  # the batch itself could not run
    stdout_path: Path | None = None
    events_path: Path | None = None
    # Per test file: further evidence (device runs: drive output, screenshots).
    extra_evidence: dict[str, list[Path]] = field(default_factory=dict)


def parse_events(lines: Iterable[str], project_dir: Path) -> dict[str, FileReport]:
    """Group reporter events by test file, keyed by path relative to the project."""
    suites: dict[int, str] = {}
    tests: dict[int, tuple[str, FlutterTestResult]] = {}
    files: dict[str, FileReport] = {}
    for line in lines:
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = event.get("type")
        if kind == "suite":
            suites[event["suite"]["id"]] = _relative(event["suite"].get("path") or "", project_dir)
        elif kind == "testStart":
            test = event["test"]
            path = suites.get(test.get("suiteID"), "")
            tests[test["id"]] = (path, FlutterTestResult(test.get("name", ""), "running"))
        elif kind == "error" and event.get("testID") in tests:
            result = tests[event["testID"]][1]
            if not result.message:
                result.message = event.get("error", "")
                result.stack = event.get("stackTrace", "")
        elif kind == "print" and event.get("testID") in tests:
            tests[event["testID"]][1].output.append(event.get("message", ""))
        elif kind == "testDone" and event.get("testID") in tests and not event.get("hidden"):
            path, result = tests[event["testID"]]
            result.result = event.get("result", "error")
            result.skipped = bool(event.get("skipped"))
            files.setdefault(path, FileReport(path)).tests.append(result)
    return files


def _relative(path: str, project_dir: Path) -> str:
    try:
        return Path(path).resolve().relative_to(project_dir.resolve()).as_posix()
    except ValueError:
        return path


class FlutterRunner:
    def __init__(self, project_dir: Path, timeout_s: float = 1800, flutter: str | None = None):
        self._project_dir = project_dir
        self._timeout_s = timeout_s
        self._flutter = flutter or shutil.which("flutter")

    def run(self, targets: list[str], evidence_dir: Path, label: str = "flutter") -> BatchResult:
        if self._flutter is None:
            return BatchResult({}, None, "Flutter SDK not found on PATH.")
        evidence_dir.mkdir(parents=True, exist_ok=True)
        events = evidence_dir / f"{label}.events.jsonl"
        stdout = evidence_dir / f"{label}.stdout.txt"
        command = [self._flutter, "test", *targets, "--file-reporter", f"json:{events}"]
        log.info("flutter test", **log_fields(files=len(targets)))
        try:
            with stdout.open("w", encoding="utf-8") as out:
                completed = subprocess.run(
                    command,
                    cwd=self._project_dir,
                    stdout=out,
                    stderr=subprocess.STDOUT,
                    timeout=self._timeout_s,
                    check=False,
                )
        except subprocess.TimeoutExpired:
            return BatchResult(
                {}, None, f"flutter test timed out after {self._timeout_s:.0f}s.", stdout
            )
        if not events.is_file():
            return BatchResult(
                {}, completed.returncode, "flutter test produced no results file.", stdout
            )
        with events.open(encoding="utf-8") as handle:
            files = parse_events(handle, self._project_dir)
        return BatchResult(files, completed.returncode, "", stdout, events)
