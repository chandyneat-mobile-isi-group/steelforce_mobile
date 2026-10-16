import json
from pathlib import Path
from typing import Any

import pytest
from openpyxl import Workbook, load_workbook

from automation.cli import EXIT_OK, main
from automation.core.exceptions import WorkbookError
from automation.excel.writer import write_back
from automation.history.store import HistoryStore, entries_from
from automation.reporting.evidence_pack import Collected, _requirement, build_evidence_packs
from automation.reporting.excel_report import build_excel_report
from automation.reporting.html_report import build_html_report
from automation.reporting.record import ExecutionRecord, find_execution
from automation.reporting.rows import DEFAULT_HEADERS, result_row

META = {
    "execution_id": "EXEC-20261008-001",
    "project": "demo",
    "environment": "staging",
    "environment_label": "Staging",
    "app_version": "1.0.0+1",
    "app_revision": "uat @ abc1234",
    "finished_at": "2026-10-08T09:00:00+00:00",
    "totals": {"by_status": {"Pass": 1, "Fail": 1}, "pass_rate": 50.0, "critical_failures": 1},
}


def api_failure(case_id: str = "TC-PRO-001") -> dict[str, Any]:
    return {
        "case_id": case_id,
        "title": "Profile <script>alert(1)</script>",
        "module": "Profile",
        "priority": "P1",
        "status": "Fail",
        "notes": "",
        "outcomes": [{
            "ref": "pytest:tests/api/test_auth.py::test_profile", "status": "Fail",
            "passed": 0, "failed": 1, "skipped": 0, "note": "",
            "failures": [{"ref": "x", "test_name": "test_profile", "message": "=HYPERLINK(\"x\")\x1b[31m"}],
            "evidence": ["api/test_profile.json"],
        }],
        "diagnosis": {
            "source": "Backend", "confidence": "High", "issue_type": "API",
            "reasoning": "Server error.", "team": "Backend",
            "missing_evidence": ["backend log for correlation id c-1"],
            "facts": {"http_status": 500, "endpoint": "GET /api/v1/mobile/auth/profile",
                      "correlation_id": "c-1", "server_trace_id": "t-9",
                      "error_code": "General.Boom"},
        },
        "evidence": ["api/test_profile.json", "screenshots/x/after.png"],
    }  # fmt: skip


def flutter_pass(case_id: str = "TC-AUTH-003") -> dict[str, Any]:
    return {
        "case_id": case_id, "title": "Layout", "module": "Authentication", "priority": "P2",
        "status": "Pass", "notes": "", "diagnosis": None, "evidence": [],
        "outcomes": [{"ref": "flutter:test/a_test.dart", "status": "Pass", "passed": 3,
                      "failed": 0, "skipped": 0, "failures": [], "note": "", "evidence": []}],
    }  # fmt: skip


def write_record(root: Path, results: list[dict], meta: dict = META) -> ExecutionRecord:
    root.mkdir(parents=True, exist_ok=True)
    (root / "metadata.json").write_text(json.dumps(meta))
    (root / "results.json").write_text(json.dumps(results))
    return ExecutionRecord.load(root)


# ── Rows ─────────────────────────────────────────────────────────────────


def test_a_failed_api_case_fills_every_triage_column() -> None:
    row = result_row(api_failure(), META, "Local (unit/widget)")
    assert row["test_result"] == "Fail" and row["issue_detected"] == "Yes"
    assert (row["issue_source"], row["confidence"], row["assigned_team"]) == (
        "Backend", "High", "Backend",
    )  # fmt: skip
    assert row["http_status"] == 500
    assert row["api_endpoint"] == "GET /api/v1/mobile/auth/profile"
    assert row["correlation_id"] == "c-1 / t-9"
    assert row["environment"] == "Staging"
    assert row["root_cause"].startswith("Probable (High): Server error.")
    assert "Screenshots: screenshots/x/after.png" not in row["mobile_evidence"]  # API ref only
    assert row["notes"].endswith(
        "Evidence: reports/EXEC-20261008-001/cases/TC-PRO-001/evidence.html"
    )


def test_local_only_results_are_labelled_local_and_carry_no_triage() -> None:
    meta = dict(META, device={"name": "iPhone", "os": "iOS 26.5"})
    row = result_row(flutter_pass(), meta, "Local (unit/widget)")
    assert row["environment"] == "Local (unit/widget)"
    assert (row["device"], row["os_version"]) == ("host (no device)", "n/a")
    assert row["issue_source"] == "" and row["error_message"] == ""
    assert row["mobile_evidence"] == "a_test.dart: 3 passed"


# ── History and regressions ───────────────────────────────────────────────


def test_regressions_and_fixes_are_judged_against_the_last_verdict(tmp_path: Path) -> None:
    store = HistoryStore(tmp_path / "h.jsonl")
    first = dict(META, execution_id="EXEC-1")
    store.append(entries_from(first, [flutter_pass("TC-A"), api_failure("TC-B")]))
    blocked = dict(flutter_pass("TC-A"), status="Blocked")
    store.append(entries_from(dict(META, execution_id="EXEC-2"), [blocked]))
    store.append(
        entries_from(dict(META, execution_id="X", environment="uat"), [api_failure("TC-A")])
    )

    now = entries_from(
        dict(META, execution_id="EXEC-3"), [api_failure("TC-A"), dict(flutter_pass("TC-B"))]
    )
    changes = {c.case_id: (c.kind, c.previous_execution) for c in store.changes(now)}
    # Blocked in EXEC-2 is not a verdict; the uat run is another environment.
    assert changes == {"TC-A": ("regression", "EXEC-1"), "TC-B": ("fixed", "EXEC-1")}


def test_history_command_lists_runs_and_flags_flakiness(
    projects_root: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    store = HistoryStore.for_project(tmp_path / "history", "demo")
    for n, result in enumerate([flutter_pass("TC-A"), api_failure("TC-A"), flutter_pass("TC-A")]):
        store.append(entries_from(dict(META, execution_id=f"EXEC-{n}"), [result]))
    assert main(["history", "--case", "tc-a", "--projects-dir", str(projects_root)]) == EXIT_OK
    out = capsys.readouterr().out
    assert "EXEC-1" in out and "Backend (High)" in out and "Flaky?" in out


# ── HTML and Excel reports ────────────────────────────────────────────────


def test_html_report_escapes_test_output_and_shows_screenshots(tmp_path: Path) -> None:
    record = write_record(tmp_path / "EXEC-20261008-001", [api_failure(), flutter_pass()])
    html = build_html_report(record).read_text()
    assert "<script>alert(1)</script>" not in html
    assert "&lt;script&gt;" in html
    assert '<img class="shot" src="screenshots/x/after.png"' in html
    assert "General.Boom" in html and "Needs attention" in html


def test_excel_report_uses_the_results_sheet_columns(tmp_path: Path) -> None:
    record = write_record(tmp_path / "EXEC-20261008-001", [api_failure(), flutter_pass()])
    ws = load_workbook(build_excel_report(record, DEFAULT_HEADERS))["Results"]
    headers = [c.value for c in ws[1]]
    assert headers[:4] == ["Run ID", "TC ID", "Title", "Priority"]
    row = {h: c.value for h, c in zip(headers, ws[2], strict=True)}
    assert row["Test Result"] == "Fail" and row["HTTP Status"] == 500
    assert row["Error Message"].startswith("=HYPERLINK")  # text, not a live formula


def test_report_command_rebuilds_the_latest_execution(
    projects_root: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    write_record(tmp_path / "reports" / "EXEC-20261008-001", [flutter_pass()])
    write_record(tmp_path / "reports" / "EXEC-20261008-002", [flutter_pass()],
                 dict(META, execution_id="EXEC-20261008-002"))  # fmt: skip
    assert find_execution(tmp_path / "reports").name == "EXEC-20261008-002"
    assert main(["report", "--projects-dir", str(projects_root)]) == EXIT_OK
    assert (tmp_path / "reports" / "EXEC-20261008-002" / "report.html").is_file()


# ── Write-back ───────────────────────────────────────────────────────────


@pytest.fixture
def results_workbook(tmp_path: Path) -> Path:
    wb = Workbook()
    ws = wb.active
    ws.title = "Execution_Results"
    ws.append([*DEFAULT_HEADERS.values(), "Triage Check"])
    ws.append(["OLD-RUN", "TC-AUTH-001"] + [None] * 22 + ['=IF(I2="","",I2)'])
    path = tmp_path / "cases.xlsx"
    wb.save(path)
    return path


def _rows(*results: dict) -> list[dict]:
    return [result_row(r, META) for r in results]


def test_write_back_appends_keeps_formulas_and_backs_up(results_workbook: Path) -> None:
    backups = results_workbook.parent / "backup"
    result = write_back(
        results_workbook, "Execution_Results", DEFAULT_HEADERS,
        _rows(api_failure(), flutter_pass()), backups,
    )  # fmt: skip
    assert (result.rows_written, result.first_row) == (2, 3)
    assert result.backup.is_file()
    ws = load_workbook(results_workbook)["Execution_Results"]
    assert ws["B3"].value == "TC-PRO-001" and ws["I3"].value == "Fail"
    assert ws["Y3"].value == '=IF(I3="","",I3)'  # the triage formula follows the new row
    assert ws["M3"].value.startswith("=HYPERLINK") and ws["M3"].data_type == "s"
    assert "\x1b" not in ws["M3"].value


def test_write_back_never_duplicates_a_run(results_workbook: Path) -> None:
    args = (results_workbook, "Execution_Results", DEFAULT_HEADERS, _rows(flutter_pass()))
    write_back(*args, results_workbook.parent)
    with pytest.raises(WorkbookError, match="never duplicates"):
        write_back(*args, results_workbook.parent)


def test_write_back_refuses_while_excel_has_the_file_open(results_workbook: Path) -> None:
    results_workbook.with_name(f"~${results_workbook.name}").touch()
    with pytest.raises(WorkbookError, match="open in Excel"):
        write_back(results_workbook, "Execution_Results", DEFAULT_HEADERS,
                   _rows(flutter_pass()), results_workbook.parent)  # fmt: skip


# ── Evidence packs ────────────────────────────────────────────────────────

API_EVIDENCE = "Screenshot; debug log lines api.request/api.response/api.error (method, path, status, errorCode, correlationId, dioType, host); timestamp. Mask tokens and phone numbers."
UI_EVIDENCE = "Screenshot (EN + KM where text changes); screen name; device/OS; app version."


def test_evidence_packs_mark_captured_and_missing_items_honestly(tmp_path: Path) -> None:
    root = tmp_path / "EXEC-20261008-001"
    (root / "api").mkdir(parents=True)
    calls = [
        {
            "method": "GET",
            "url": "***/api/v1/mobile/auth/profile",
            "status": 500,
            "elapsed_ms": 12,
            "error_code": "General.Boom",
            "correlation_id": "c-1",
        }
    ]
    (root / "api" / "test_profile.json").write_text(json.dumps(calls))
    (root / "screenshots" / "x").mkdir(parents=True)
    (root / "screenshots" / "x" / "after.png").write_bytes(b"PNG")
    record = write_record(root, [api_failure(), flutter_pass()])

    counts = build_evidence_packs(
        record, {"TC-PRO-001": API_EVIDENCE, "TC-AUTH-003": UI_EVIDENCE}, tmp_path
    )
    # API case: screenshot, api log, timestamp, masking — all four captured.
    assert counts["TC-PRO-001"] == (4, 4)
    # UI case on fakes: no screenshot (EN + KM) — device, version, screen name only.
    assert counts["TC-AUTH-003"] == (2, 4)
    page = (root / "cases" / "TC-PRO-001" / "evidence.html").read_text()
    assert "/api/v1/mobile/auth/profile" in page and "c-1" in page
    assert "&lt;script&gt;" in page and "<script>alert" not in page
    assert (root / "cases" / "TC-PRO-001" / "after.png").is_file()
    ui = (root / "cases" / "TC-AUTH-003" / "evidence.html").read_text()
    assert "Capture EN and KM on a device" in ui


@pytest.mark.parametrize(
    ("item", "captured"),
    [
        ("Sync Center / pending sheet before and after reconnect", False),
        ("Screenshot of the offline state", False),
        ("api.* log lines after reconnect (correlationId)", False),
        ("Something the framework has never heard of", False),
    ],
)  # fmt: skip
def test_items_without_evidence_are_never_marked_captured(item: str, captured: bool) -> None:
    got = Collected([], [], [], [], "Computer", "n/a")
    assert _requirement(item, got, META).captured is captured
