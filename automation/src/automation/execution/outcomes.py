"""What one Automation ID produced, per runner, with its own diagnosis."""

from dataclasses import replace
from pathlib import Path

from automation.analysis.api_rules import diagnose_api_failure, diagnose_blocked
from automation.analysis.classifier import (
    diagnose_device_failures,
    diagnose_infrastructure,
    diagnose_test_failures,
)
from automation.api.pytest_plugin import evidence_file_name
from automation.api.pytest_runner import PytestBatch
from automation.core.constants import ResultStatus
from automation.excel.models import AutomationRef, Runner
from automation.execution.results import RefOutcome, TestFailure
from automation.mobile.flutter_runner import BatchResult

PYTEST_STATUS = {
    "passed": ResultStatus.PASS,
    "failed": ResultStatus.FAIL,
    "blocked": ResultStatus.BLOCKED,
    "skipped": ResultStatus.SKIPPED,
    "excluded": ResultStatus.SKIPPED,
}
_PRECEDENCE = (ResultStatus.FAIL, ResultStatus.BLOCKED, ResultStatus.PASS, ResultStatus.SKIPPED)


def _relative(paths: list[Path | None], root: Path) -> tuple[str, ...]:
    return tuple(str(p.relative_to(root)) for p in paths if p is not None and p.exists())


def blocked_outcome(ref: AutomationRef, note: str, infrastructure: bool = False) -> RefOutcome:
    diagnosis = diagnose_infrastructure(note) if infrastructure else None
    return RefOutcome(str(ref), ResultStatus.BLOCKED, note=note, diagnosis=diagnosis)


def _diagnose(ref: AutomationRef, failures: tuple[TestFailure, ...]):
    if ref.runner is Runner.DRIVE:
        return diagnose_device_failures(failures)
    return diagnose_test_failures(failures)


def flutter_outcome(ref: AutomationRef, batch: BatchResult | None, root: Path) -> RefOutcome:
    if batch is None:
        return blocked_outcome(ref, "Flutter tests were not run.")
    if batch.infrastructure_error:
        return blocked_outcome(ref, batch.infrastructure_error, infrastructure=True)
    report = batch.files.get(ref.target)
    extra = batch.extra_evidence.get(ref.target, [])
    if report is None:
        if extra:  # a device run that never reported: build, install or launch failed
            outcome = blocked_outcome(
                ref, "The device test produced no results — see drive.stdout.txt.", True
            )
            return replace(outcome, evidence=_relative(list(extra), root))
        return blocked_outcome(ref, "No results reported for this file.")
    tests = report.select(ref.name)
    if not tests:
        return blocked_outcome(ref, f"No test named {ref.name!r}.")
    failures = tuple(
        TestFailure(str(ref), t.name, t.details, t.stack, t.is_load_error)
        for t in tests
        if t.result != "success"
    )
    skipped = sum(1 for t in tests if t.skipped)
    passed = len(tests) - len(failures) - skipped
    if failures:
        status = ResultStatus.FAIL
    else:
        status = ResultStatus.PASS if passed else ResultStatus.SKIPPED
    return RefOutcome(
        str(ref), status, passed, len(failures), skipped, failures,
        diagnosis=_diagnose(ref, failures) if failures else None,
        evidence=_relative([batch.events_path, batch.stdout_path, *extra], root),
    )  # fmt: skip


def pytest_outcome(ref: AutomationRef, batch: PytestBatch | None, root: Path) -> RefOutcome:
    if batch is None:
        return blocked_outcome(ref, "API tests were not run.")
    if batch.infrastructure_error:
        return blocked_outcome(ref, batch.infrastructure_error, infrastructure=True)
    records = batch.for_ref(ref.target, ref.name)
    if not records:
        return blocked_outcome(ref, "No results reported for this test (check the Automation ID).")
    statuses = [PYTEST_STATUS.get(r["outcome"], ResultStatus.BLOCKED) for r in records]
    status = next(s for s in _PRECEDENCE if s in statuses)
    failed = [r for r in records if r["outcome"] == "failed"]
    failures = tuple(TestFailure(str(ref), r["nodeid"], r.get("message", "")) for r in failed)
    notes = sorted({r["message"] for r in records if r["outcome"] in {"blocked", "excluded"}})
    if failed:
        diagnosis = diagnose_api_failure(failed[0].get("message", ""), failed[0]["api_calls"])
    elif status is ResultStatus.BLOCKED:
        diagnosis = diagnose_blocked("; ".join(notes))
    else:
        diagnosis = None
    api_files = [
        batch.evidence_dir / f"{evidence_file_name(r['nodeid'])}.json"
        if batch.evidence_dir
        else None
        for r in records
    ]
    return RefOutcome(
        str(ref), status,
        passed=statuses.count(ResultStatus.PASS),
        failed=len(failed),
        skipped=statuses.count(ResultStatus.SKIPPED),
        failures=failures,
        note="; ".join(notes),
        diagnosis=diagnosis,
        evidence=_relative([*api_files, batch.results_path, batch.stdout_path], root),
    )  # fmt: skip
