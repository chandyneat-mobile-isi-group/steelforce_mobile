from pathlib import Path

import pytest

from automation.cli import EXIT_CONFIG, EXIT_GUARD, EXIT_NOT_READY, EXIT_OK, build_parser, main
from automation.core.constants import PRODUCTION_CONSENT_ENV, PRODUCTION_CONSENT_VALUE
from tests.framework.conftest import case_row


def run(projects_root: Path, *args: str) -> int:
    return main([*args, "--projects-dir", str(projects_root)])


def test_projects_lists_profiles_and_environments(
    projects_root: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    assert run(projects_root, "projects") == EXIT_OK
    assert "demo  (environments: production, uat)" in capsys.readouterr().out


def test_config_shows_secret_status_never_values(
    projects_root: Path, project_dir: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    (project_dir / ".env.uat").write_text("DEMO_API_BASE_URL=https://uat.example\n")
    assert run(projects_root, "config") == EXIT_OK
    out = capsys.readouterr().out
    assert "DEMO_API_BASE_URL = set" in out
    assert "uat.example" not in out


def test_unknown_environment_is_a_config_error(projects_root: Path) -> None:
    assert run(projects_root, "config", "--env", "qa") == EXIT_CONFIG


def test_run_against_production_without_consent_is_refused(projects_root: Path) -> None:
    assert run(projects_root, "run", "--env", "production") == EXIT_GUARD


def test_report_and_history_with_nothing_recorded_say_so(projects_root: Path) -> None:
    assert run(projects_root, "report") == EXIT_NOT_READY
    assert run(projects_root, "history", "--case", "TC-AUTH-001") == EXIT_NOT_READY


def test_validate_passes_a_clean_workbook(
    projects_root: Path, make_workbook, dart_test, capsys: pytest.CaptureFixture[str]
) -> None:
    make_workbook([case_row()], {"TC-AUTH-001": f"flutter:{dart_test('test/a_test.dart')}"})
    assert run(projects_root, "validate") == EXIT_OK
    assert "1 test cases · 1 valid · 0 error(s)" in capsys.readouterr().out


def test_validate_fails_and_lists_each_error(
    projects_root: Path, make_workbook, capsys: pytest.CaptureFixture[str]
) -> None:
    make_workbook([case_row(Priority="Urgent")], {"TC-AUTH-001": "manual"})
    assert run(projects_root, "validate") == EXIT_CONFIG
    assert "TC-AUTH-001 row 2 Priority: Invalid Priority: 'Urgent'" in capsys.readouterr().out


def test_validate_without_a_workbook_is_a_config_error(projects_root: Path) -> None:
    assert run(projects_root, "validate") == EXIT_CONFIG


def test_run_with_no_matching_case_is_a_config_error(
    projects_root: Path, make_workbook, dart_test
) -> None:
    make_workbook([case_row()], {"TC-AUTH-001": f"flutter:{dart_test('test/a_test.dart')}"})
    assert run(projects_root, "run", "--module", "nothing") == EXIT_CONFIG


def test_risky_markers_on_production_are_refused_before_anything_runs(
    projects_root: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv(PRODUCTION_CONSENT_ENV, PRODUCTION_CONSENT_VALUE)
    code = run(projects_root, "run", "--env", "production", "--allow-protected", "--include", "sms")
    assert code == EXIT_GUARD


@pytest.mark.parametrize(
    ("value", "expected"), [("critical", "P1"), ("High", "P2"), ("p3", "P3"), ("normal", "P3")]
)
def test_priority_accepts_aliases(value: str, expected: str) -> None:
    args = build_parser().parse_args(["run", "--priority", value])
    assert args.priority == expected


def test_case_and_include_accept_comma_lists() -> None:
    args = build_parser().parse_args(
        ["run", "--case", "TC-AUTH-002, TC-AUTH-004", "--include", "destructive,sms"]
    )
    assert args.case == ["TC-AUTH-002", "TC-AUTH-004"]
    assert args.include == ["destructive", "sms"]
