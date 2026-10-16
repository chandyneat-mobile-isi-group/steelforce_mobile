from collections.abc import Callable
from pathlib import Path

import pytest

from automation.core.config import load_context
from automation.core.exceptions import WorkbookError
from automation.excel.models import AutomationRef, AutomationRefError, Runner, Severity
from automation.excel.reader import WorkbookReader
from automation.execution.catalog import load_catalog
from tests.framework.conftest import CASE_HEADERS, case_row

# ── Automation IDs ────────────────────────────────────────────────────────


@pytest.mark.parametrize(
    ("text", "runner", "target", "name"),
    [
        ("flutter:test/a_test.dart", Runner.FLUTTER, "test/a_test.dart", None),
        ("pytest:tests/api/test_auth.py::test_login", Runner.PYTEST, "tests/api/test_auth.py", "test_login"),
        (" drive:integration_test/login_test.dart ", Runner.DRIVE, "integration_test/login_test.dart", None),
        ("Manual", Runner.MANUAL, "", None),
    ],
)  # fmt: skip
def test_automation_refs_parse_explicitly(text, runner, target, name) -> None:
    ref = AutomationRef.parse(text)
    assert (ref.runner, ref.target, ref.name) == (runner, target, name)


@pytest.mark.parametrize("text", ["login_test", "appium:x", "flutter:", "manual:x"])
def test_malformed_automation_refs_are_rejected(text: str) -> None:
    with pytest.raises(AutomationRefError):
        AutomationRef.parse(text)


# ── Reader ───────────────────────────────────────────────────────────────


def _context(projects_root: Path):
    return load_context(root=projects_root, environ={})


def test_rows_become_typed_cases_joined_with_their_mapping(
    projects_root: Path, make_workbook: Callable[..., Path]
) -> None:
    make_workbook([case_row("TC-AUTH-001")], {"TC-AUTH-001": "flutter:test/a_test.dart; manual"})
    ctx = _context(projects_root)
    case = WorkbookReader(ctx.workbook_path, ctx.project.workbook).read().cases[0]
    assert case.id == "TC-AUTH-001" and case.row == 2
    assert case.test_data_ids == ("TD-001", "TD-002")
    assert case.suites == ("smoke", "regression")
    assert [str(r) for r in case.automation_refs] == ["flutter:test/a_test.dart", "manual"]
    assert [str(r) for r in case.automated_refs] == ["flutter:test/a_test.dart"]


def test_columns_are_found_by_header_not_position(
    projects_root: Path, make_workbook: Callable[..., Path]
) -> None:
    reordered = ["Notes", *reversed(CASE_HEADERS)]
    make_workbook([case_row()], {}, headers=reordered)
    ctx = _context(projects_root)
    assert WorkbookReader(ctx.workbook_path, ctx.project.workbook).read().cases[0].module == (
        "Authentication"
    )


def test_a_missing_required_column_is_fatal(
    projects_root: Path, make_workbook: Callable[..., Path]
) -> None:
    make_workbook([case_row()], {}, headers=[h for h in CASE_HEADERS if h != "Expected"])
    ctx = _context(projects_root)
    with pytest.raises(WorkbookError, match="Expected"):
        WorkbookReader(ctx.workbook_path, ctx.project.workbook).read()


def test_blank_rows_are_ignored(projects_root: Path, make_workbook: Callable[..., Path]) -> None:
    make_workbook([case_row("TC-AUTH-001"), {}, case_row("TC-AUTH-002")], {})
    ctx = _context(projects_root)
    cases = WorkbookReader(ctx.workbook_path, ctx.project.workbook).read().cases
    assert [c.id for c in cases] == ["TC-AUTH-001", "TC-AUTH-002"]


def test_allowed_values_come_from_the_dropdown_sheet(
    projects_root: Path, make_workbook: Callable[..., Path]
) -> None:
    make_workbook([case_row()], {})
    ctx = _context(projects_root)
    allowed = WorkbookReader(ctx.workbook_path, ctx.project.workbook).read().allowed_values
    assert allowed["priority"] == ["P1", "P2", "P3"]


def test_a_missing_workbook_is_fatal(projects_root: Path) -> None:
    ctx = _context(projects_root)
    with pytest.raises(WorkbookError, match="not found"):
        WorkbookReader(ctx.workbook_path, ctx.project.workbook).read()


# ── Validator ────────────────────────────────────────────────────────────


def _issues(projects_root: Path) -> list[str]:
    return [str(i) for i in load_catalog(_context(projects_root)).issues]


def test_a_valid_workbook_has_no_issues(
    projects_root: Path, make_workbook: Callable[..., Path], dart_test: Callable[[str], str]
) -> None:
    ref = dart_test("test/a_test.dart")
    make_workbook([case_row()], {"TC-AUTH-001": f"flutter:{ref}"})
    assert _issues(projects_root) == []


@pytest.mark.parametrize(
    ("overrides", "expected"),
    [
        ({"Expected": ""}, "Expected Result is empty"),
        ({"Steps": None}, "Steps is empty"),
        ({"Priority": "Urgent"}, "Invalid Priority: 'Urgent'"),
        ({"Type": "Smoke"}, "Invalid Test Type: 'Smoke'"),
        ({"Status": "Done"}, "Invalid Automation Status: 'Done'"),
        ({"Suites": "nightly"}, "Unknown suite 'nightly'"),
        ({"Envs": "qa"}, "Unknown environment 'qa'"),
        ({"ID": "AUTH-1"}, "does not match"),
    ],
)
def test_each_rule_reports_the_case_and_reason(
    projects_root: Path,
    make_workbook: Callable[..., Path],
    dart_test: Callable[[str], str],
    overrides: dict[str, str],
    expected: str,
) -> None:
    ref = dart_test("test/a_test.dart")
    case = case_row(**overrides)
    make_workbook([case], {case["ID"]: f"flutter:{ref}"})
    issues = _issues(projects_root)
    assert any(expected in i and i.startswith("ERROR") for i in issues), issues


def test_duplicate_ids_are_errors_on_every_copy(
    projects_root: Path, make_workbook: Callable[..., Path], dart_test: Callable[[str], str]
) -> None:
    ref = dart_test("test/a_test.dart")
    make_workbook([case_row(), case_row()], {"TC-AUTH-001": f"flutter:{ref}"})
    duplicates = [i for i in _issues(projects_root) if "Duplicate Test Case ID" in i]
    assert len(duplicates) == 2


def test_automated_status_needs_an_automation_id(
    projects_root: Path, make_workbook: Callable[..., Path]
) -> None:
    make_workbook([case_row(Status="Automated")], {"TC-AUTH-001": "manual"})
    assert any("no Automation ID is mapped" in i for i in _issues(projects_root))


def test_an_automation_id_must_point_at_an_existing_file(
    projects_root: Path, make_workbook: Callable[..., Path]
) -> None:
    make_workbook([case_row()], {"TC-AUTH-001": "flutter:test/missing_test.dart"})
    assert any("points at a missing file" in i for i in _issues(projects_root))


def test_a_bad_automation_id_is_an_error_for_that_case(
    projects_root: Path, make_workbook: Callable[..., Path]
) -> None:
    make_workbook([case_row()], {"TC-AUTH-001": "appium:login"})
    assert any("unknown runner 'appium'" in i for i in _issues(projects_root))


def test_planned_case_with_a_mapped_test_is_only_a_warning(
    projects_root: Path, make_workbook: Callable[..., Path], dart_test: Callable[[str], str]
) -> None:
    ref = dart_test("test/a_test.dart")
    make_workbook([case_row(Status="Planned")], {"TC-AUTH-001": f"flutter:{ref}"})
    catalog = load_catalog(_context(projects_root))
    assert [i.severity for i in catalog.issues] == [Severity.WARNING]
    assert [c.id for c in catalog.valid_cases] == ["TC-AUTH-001"]


def test_invalid_cases_are_excluded_valid_ones_kept(
    projects_root: Path, make_workbook: Callable[..., Path], dart_test: Callable[[str], str]
) -> None:
    ref = dart_test("test/a_test.dart")
    make_workbook(
        [case_row("TC-AUTH-001"), case_row("TC-AUTH-002", Priority="Urgent")],
        {"TC-AUTH-001": f"flutter:{ref}", "TC-AUTH-002": f"flutter:{ref}"},
    )
    catalog = load_catalog(_context(projects_root))
    assert [c.id for c in catalog.valid_cases] == ["TC-AUTH-001"]
    assert catalog.invalid_ids == {"TC-AUTH-002"}


def test_the_real_steelforce_workbook_is_valid() -> None:
    catalog = load_catalog(load_context("steelforce", "uat", environ={}))
    assert catalog.errors == []
    assert len(catalog.cases) >= 36
