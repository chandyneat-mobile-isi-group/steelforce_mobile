"""Result records. Immutable once built; reports are views over them."""

from dataclasses import asdict, dataclass, field
from typing import Any

from automation.core.constants import Confidence, IssueSource, ResultStatus


@dataclass(frozen=True)
class TestFailure:
    """One failing automated test inside a test case's evidence."""

    __test__ = False

    ref: str
    test_name: str
    message: str
    stack: str = ""
    load_error: bool = False  # the test file never compiled / loaded


@dataclass(frozen=True)
class Diagnosis:
    source: IssueSource
    confidence: Confidence
    issue_type: str
    reasoning: str
    team: str
    missing_evidence: tuple[str, ...] = ()
    # Evidence facts behind the verdict (HTTP status, endpoint, correlation id,
    # error code, …) — what the workbook's triage columns are filled from.
    facts: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class RefOutcome:
    """What one automation reference produced."""

    ref: str
    status: ResultStatus
    passed: int = 0
    failed: int = 0
    skipped: int = 0
    failures: tuple[TestFailure, ...] = ()
    note: str = ""
    diagnosis: Diagnosis | None = None
    evidence: tuple[str, ...] = ()  # paths relative to the execution folder


@dataclass(frozen=True)
class CaseResult:
    case_id: str
    title: str
    module: str
    priority: str
    status: ResultStatus
    duration_s: float | None  # None when the case shared a batch run (see metadata)
    outcomes: tuple[RefOutcome, ...] = ()
    notes: str = ""
    diagnosis: Diagnosis | None = None
    evidence: tuple[str, ...] = field(default_factory=tuple)

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def combine(outcomes: list[RefOutcome]) -> ResultStatus:
    """A case fails if any of its automated references failed."""
    statuses = {o.status for o in outcomes}
    for status in (ResultStatus.FAIL, ResultStatus.BLOCKED):
        if status in statuses:
            return status
    if ResultStatus.PASS in statuses:
        return ResultStatus.PASS
    if ResultStatus.SKIPPED in statuses:
        return ResultStatus.SKIPPED
    return ResultStatus.NOT_RUN
