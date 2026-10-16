import json
from datetime import date
from pathlib import Path

import pytest

from automation.analysis.classifier import diagnose_test_failures
from automation.core.constants import Confidence, IssueSource, ResultStatus
from automation.excel.models import AutomationRef, TestCase
from automation.execution.engine import MANUAL_NOTE, PARTIAL_NOTE, Engine
from automation.execution.filters import CaseFilter
from automation.execution.results import TestFailure
from automation.execution.workspace import Workspace, next_execution_id
from automation.mobile.flutter_runner import (
    BatchResult,
    FileReport,
    FlutterTestResult,
    parse_events,
)
from automation.reporting.summary import totals


def make_case(
    case_id: str = "TC-AUTH-001", refs: str = "flutter:test/a_test.dart", **kw
) -> TestCase:
    values = dict(
        id=case_id, row=2, module="Authentication", feature="Login", scenario="s",
        priority="P1", test_type="Functional", preconditions="", steps="1", expected_result="ok",
        automation_status="Automated", suites=("smoke",), environments=(),
        automation_refs=tuple(AutomationRef.parse(r) for r in refs.split(";")),
    )  # fmt: skip
    values.update(kw)
    return TestCase(**values)


# ── Filters ──────────────────────────────────────────────────────────────


def test_filters_combine_and_ignore_case() -> None:
    cases = [make_case("TC-AUTH-001"), make_case("TC-PRO-001", module="Profile", priority="P2")]
    f = CaseFilter(module="profile", priority="P2")
    assert [c.id for c in f.apply(cases)] == ["TC-PRO-001"]
    assert [c.id for c in CaseFilter(case_ids=("tc-auth-001",)).apply(cases)] == ["TC-AUTH-001"]
    assert CaseFilter(suite="regression").apply(cases) == []


def test_blank_environments_mean_everywhere_except_protected() -> None:
    case = make_case()
    assert CaseFilter(environment="uat").matches(case)
    assert not CaseFilter(environment="production", protected_environment=True).matches(case)
    tagged = make_case(environments=("production",))
    assert CaseFilter(environment="production", protected_environment=True).matches(tagged)


def test_level_selects_by_runner() -> None:
    case = make_case(refs="flutter:test/a_test.dart")
    assert CaseFilter(level="flutter").matches(case)
    assert not CaseFilter(level="api").matches(case)


# ── Flutter reporter events ───────────────────────────────────────────────


def _events(project: Path) -> list[str]:
    a, b = project / "test/a_test.dart", project / "test/b_test.dart"
    return [
        json.dumps(e)
        for e in [
            {"type": "suite", "suite": {"id": 0, "path": str(a)}},
            {"type": "suite", "suite": {"id": 1, "path": str(b)}},
            {"type": "testStart", "test": {"id": 1, "name": "loading x", "suiteID": 0}},
            {"type": "testDone", "testID": 1, "result": "success", "hidden": True},
            {"type": "testStart", "test": {"id": 2, "name": "passes", "suiteID": 0}},
            {"type": "testDone", "testID": 2, "result": "success", "hidden": False},
            {"type": "testStart", "test": {"id": 3, "name": "fails", "suiteID": 1}},
            {"type": "print", "testID": 3, "message": "GetIt: Object/factory with type FooBloc is not registered"},
            {"type": "error", "testID": 3, "error": "Test failed. See exception logs above."},
            {"type": "testDone", "testID": 3, "result": "error", "hidden": False},
        ]
    ] + ["not json"]  # fmt: skip


def test_events_group_by_file_and_keep_printed_exceptions(tmp_path: Path) -> None:
    files = parse_events(_events(tmp_path), tmp_path)
    assert [t.name for t in files["test/a_test.dart"].tests] == ["passes"]  # hidden dropped
    failing = files["test/b_test.dart"].tests[0]
    assert failing.result == "error"
    assert "FooBloc is not registered" in failing.details


# ── Classifier ───────────────────────────────────────────────────────────


def _failure(message: str, load_error: bool = False) -> TestFailure:
    return TestFailure("flutter:test/a_test.dart", "t", message, "", load_error)


@pytest.mark.parametrize(
    ("failure", "source", "confidence"),
    [
        (_failure("Compilation failed ... Error: No named parameter with the name 'x'", True),
         IssueSource.AUTOMATION, Confidence.HIGH),
        (_failure("GetIt: Object/factory with type ActiveRouteBloc is not registered"),
         IssueSource.AUTOMATION, Confidence.HIGH),
        (_failure("Expected: 'cust-1'\n  Actual: ''"), IssueSource.UNKNOWN, Confidence.LOW),
        (_failure("something odd"), IssueSource.UNKNOWN, Confidence.LOW),
    ],
)  # fmt: skip
def test_classifier_uses_evidence_and_never_defaults_to_mobile(failure, source, confidence) -> None:
    diagnosis = diagnose_test_failures([failure])
    assert (diagnosis.source, diagnosis.confidence) == (source, confidence)
    assert diagnosis.source is not IssueSource.MOBILE


def test_unknown_always_names_the_missing_evidence() -> None:
    assert diagnose_test_failures([_failure("something odd")]).missing_evidence


# ── Engine ───────────────────────────────────────────────────────────────


class FakeFlutter:
    def __init__(self, batch: BatchResult) -> None:
        self.batch = batch
        self.calls: list[list[str]] = []

    def run(self, targets, evidence_dir, label="flutter") -> BatchResult:
        self.calls.append(targets)
        return self.batch


def _report(path: str, *results: tuple[str, str]) -> FileReport:
    return FileReport(
        path, [FlutterTestResult(n, r, message="Expected: 1\n Actual: 2") for n, r in results]
    )


@pytest.fixture
def workspace(tmp_path: Path) -> Workspace:
    return Workspace.create(tmp_path / "reports", date(2026, 10, 8))


def _run(workspace: Workspace, batch: BatchResult, *cases: TestCase):
    flutter = FakeFlutter(batch)
    return Engine(workspace, flutter).run(list(cases)), flutter


def test_each_file_runs_once_and_maps_back_to_every_case(workspace: Workspace) -> None:
    batch = BatchResult({"test/a_test.dart": _report("test/a_test.dart", ("ok", "success"))}, 0)
    summary, flutter = _run(workspace, batch, make_case("TC-AUTH-001"), make_case("TC-AUTH-002"))
    assert flutter.calls == [["test/a_test.dart"]]
    assert [r.status for r in summary.results] == [ResultStatus.PASS, ResultStatus.PASS]


def test_one_failing_reference_fails_the_case_with_a_diagnosis(workspace: Workspace) -> None:
    batch = BatchResult(
        {
            "test/a_test.dart": _report("test/a_test.dart", ("ok", "success")),
            "test/b_test.dart": _report("test/b_test.dart", ("broken", "failure")),
        },
        1,
    )
    summary, _ = _run(
        workspace, batch, make_case(refs="flutter:test/a_test.dart;flutter:test/b_test.dart")
    )
    result = summary.results[0]
    assert result.status is ResultStatus.FAIL
    assert result.diagnosis is not None and result.diagnosis.source is IssueSource.UNKNOWN


def test_manual_cases_are_not_run_never_passed(workspace: Workspace) -> None:
    summary, flutter = _run(workspace, BatchResult({}, 0), make_case(refs="manual"))
    assert summary.results[0].status is ResultStatus.NOT_RUN
    assert summary.results[0].notes == MANUAL_NOTE
    assert flutter.calls == []


def test_partial_cases_say_a_manual_run_is_still_needed(workspace: Workspace) -> None:
    batch = BatchResult({"test/a_test.dart": _report("test/a_test.dart", ("ok", "success"))}, 0)
    summary, _ = _run(workspace, batch, make_case(automation_status="Partial"))
    assert summary.results[0].notes == PARTIAL_NOTE


def test_a_runner_that_cannot_run_blocks_with_an_environment_diagnosis(
    workspace: Workspace,
) -> None:
    summary, _ = _run(
        workspace, BatchResult({}, None, "Flutter SDK not found on PATH."), make_case()
    )
    result = summary.results[0]
    assert result.status is ResultStatus.BLOCKED
    assert result.diagnosis is not None and result.diagnosis.source is IssueSource.ENVIRONMENT


def test_a_file_with_no_results_is_blocked_not_passed(workspace: Workspace) -> None:
    summary, _ = _run(workspace, BatchResult({}, 0), make_case())
    assert summary.results[0].status is ResultStatus.BLOCKED


def test_a_named_test_selects_exactly_that_test(workspace: Workspace) -> None:
    batch = BatchResult(
        {"test/a_test.dart": _report("test/a_test.dart", ("good", "success"), ("bad", "failure"))},
        1,
    )
    summary, _ = _run(workspace, batch, make_case(refs="flutter:test/a_test.dart::good"))
    assert summary.results[0].status is ResultStatus.PASS
    summary, _ = _run(workspace, batch, make_case(refs="flutter:test/a_test.dart::missing"))
    assert summary.results[0].status is ResultStatus.BLOCKED


def test_api_and_device_refs_are_blocked_until_their_runner_exists(workspace: Workspace) -> None:
    summary, _ = _run(
        workspace, BatchResult({}, 0), make_case(refs="pytest:tests/api/test_auth.py")
    )
    assert summary.results[0].status is ResultStatus.BLOCKED


# ── Workspace and totals ──────────────────────────────────────────────────


def test_execution_ids_increment_and_never_reuse_a_folder(tmp_path: Path) -> None:
    reports = tmp_path / "reports"
    first = Workspace.create(reports, date(2026, 10, 8))
    second = Workspace.create(reports, date(2026, 10, 8))
    assert (first.execution_id, second.execution_id) == ("EXEC-20261008-001", "EXEC-20261008-002")
    assert next_execution_id(reports, date(2026, 10, 9)) == "EXEC-20261009-001"
    assert (second.root / "screenshots").is_dir()


def test_evidence_is_masked_on_write(workspace: Workspace) -> None:
    path = workspace.write_json("api/x.json", {"password": "hunter2", "phone": "012345678"})
    text = path.read_text()
    assert "hunter2" not in text and "012345678" not in text


def test_pass_rate_counts_only_executed_cases(workspace: Workspace) -> None:
    batch = BatchResult({"test/a_test.dart": _report("test/a_test.dart", ("ok", "success"))}, 0)
    summary, _ = _run(workspace, batch, make_case(), make_case("TC-AUTH-002", refs="manual"))
    t = totals(summary.results)
    assert (t.total, t.executed, t.pass_rate) == (2, 1, 100.0)
