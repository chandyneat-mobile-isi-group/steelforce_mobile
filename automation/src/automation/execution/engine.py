"""Turns selected test cases into results.

Each runner runs once per execution with every distinct target the selected
cases reference; outcomes are then mapped back to each case through its
explicit Automation IDs. Manual cases are reported as Not Run — never as
passed.
"""

import time
from dataclasses import dataclass, field
from typing import Protocol

from automation.core.constants import ResultStatus
from automation.core.logger import FAIL, PASS, get_logger, log_fields
from automation.excel.models import AutomationRef, Runner, TestCase
from automation.execution.outcomes import flutter_outcome, pytest_outcome
from automation.execution.results import CaseResult, RefOutcome, combine
from automation.execution.workspace import Workspace
from automation.mobile.flutter_runner import BatchResult

log = get_logger("engine")

MANUAL_NOTE = "Manual test — execute in UAT and record the result in the workbook."
PARTIAL_NOTE = "Automated part only — a manual UAT run is still required."
NO_DEVICE_NOTE = "no device selected (pass --device or set flutter.device)"


class FlutterRunnerLike(Protocol):
    def run(self, targets: list[str], evidence_dir, label: str = ...) -> BatchResult: ...


class PytestRunnerLike(Protocol):
    def run(self, targets: list[str], evidence_root): ...


class DeviceRunnerLike(Protocol):
    def run(self, targets: list[str], evidence_dir, screenshots_dir) -> BatchResult: ...


@dataclass
class RunSummary:
    results: list[CaseResult]
    seconds: dict[str, float] = field(default_factory=dict)
    exit_codes: dict[str, int | None] = field(default_factory=dict)


def _target(ref: AutomationRef) -> str:
    return f"{ref.target}::{ref.name}" if ref.name and ref.runner is Runner.PYTEST else ref.target


class Engine:
    def __init__(
        self,
        workspace: Workspace,
        flutter: FlutterRunnerLike,
        pytest_runner: PytestRunnerLike | None = None,
        runners: frozenset[Runner] | None = None,
        device_runner: DeviceRunnerLike | None = None,
    ) -> None:
        self._workspace = workspace
        self._flutter = flutter
        self._pytest = pytest_runner
        self._device = device_runner
        # `--level` restricts which references run, not only which cases.
        self._runners = runners

    def _refs(self, case: TestCase) -> tuple[AutomationRef, ...]:
        return tuple(
            r for r in case.automated_refs if self._runners is None or r.runner in self._runners
        )

    def run(self, cases: list[TestCase]) -> RunSummary:
        summary = RunSummary([])
        flutter_batch = self._timed(summary, "flutter", cases, Runner.FLUTTER)
        pytest_batch = self._timed(summary, "api", cases, Runner.PYTEST)
        device_batch = self._timed(summary, "device", cases, Runner.DRIVE)
        batches = {
            Runner.FLUTTER: flutter_batch,
            Runner.PYTEST: pytest_batch,
            Runner.DRIVE: device_batch,
        }
        for case in cases:
            result = self._case_result(case, batches)
            level = {ResultStatus.PASS: PASS, ResultStatus.FAIL: FAIL}.get(result.status, 20)
            log.log(level, result.case_id, **log_fields(status=result.status.value))
            summary.results.append(result)
        return summary

    def _timed(self, summary: RunSummary, label: str, cases: list[TestCase], runner: Runner):
        targets = sorted({_target(r) for c in cases for r in self._refs(c) if r.runner is runner})
        if not targets:
            return None
        if (runner is Runner.PYTEST and self._pytest is None) or (
            runner is Runner.DRIVE and self._device is None
        ):
            return None
        started = time.monotonic()
        if runner is Runner.FLUTTER:
            batch = self._flutter.run(targets, self._workspace.path("flutter"))
        elif runner is Runner.DRIVE:
            batch = self._device.run(  # type: ignore[union-attr]
                targets, self._workspace.path("device"), self._workspace.path("screenshots")
            )
        else:
            batch = self._pytest.run(targets, self._workspace.root)  # type: ignore[union-attr]
        summary.seconds[label] = round(time.monotonic() - started, 1)
        summary.exit_codes[label] = batch.exit_code
        return batch

    def _outcome(self, ref: AutomationRef, batches: dict) -> RefOutcome:
        root = self._workspace.root
        if ref.runner is Runner.PYTEST:
            return pytest_outcome(ref, batches[Runner.PYTEST], root)
        if ref.runner is Runner.DRIVE and self._device is None:
            # Not choosing a device is a choice, like --level; it blocks nothing.
            return RefOutcome(str(ref), ResultStatus.SKIPPED, note=NO_DEVICE_NOTE)
        return flutter_outcome(ref, batches[ref.runner], root)

    def _case_result(self, case: TestCase, batches: dict) -> CaseResult:
        refs = self._refs(case)
        if not refs:
            return self._result(case, ResultStatus.NOT_RUN, (), MANUAL_NOTE)
        outcomes = tuple(self._outcome(r, batches) for r in refs)
        status = combine(list(outcomes))
        notes = [PARTIAL_NOTE] if case.automation_status.lower() == "partial" else []
        # A reference that did not run is always named, even when the case passed.
        notes += [
            f"Not run: {o.ref} — {o.note}" for o in outcomes if o.status is ResultStatus.SKIPPED
        ]
        return self._result(case, status, outcomes, " ".join(notes))

    @staticmethod
    def _result(
        case: TestCase,
        status: ResultStatus,
        outcomes: tuple[RefOutcome, ...],
        notes: str = "",
    ) -> CaseResult:
        # The case carries the diagnosis of the first outcome that decided its status.
        deciding = next((o for o in outcomes if o.status is status and o.diagnosis), None)
        evidence = tuple(dict.fromkeys(p for o in outcomes for p in o.evidence))
        return CaseResult(
            case_id=case.id,
            title=case.scenario,
            module=case.module,
            priority=case.priority,
            status=status,
            duration_s=None,
            outcomes=outcomes,
            notes=notes,
            diagnosis=deciding.diagnosis if deciding else None,
            evidence=evidence,
        )
