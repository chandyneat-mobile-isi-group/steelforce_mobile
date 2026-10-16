"""``report.xlsx`` for one execution: a Summary sheet and a Results sheet whose
columns match the workbook's Execution_Results sheet, so rows can be copied
across by hand when write-back is not wanted."""

from pathlib import Path
from typing import Any

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill

from automation.excel.writer import put_cell
from automation.reporting.evidence_pack import evidence_note
from automation.reporting.record import ExecutionRecord
from automation.reporting.rows import result_row

HEADER_FILL = PatternFill("solid", fgColor="1F3A5F")
STATUS_FILL = {
    "Pass": PatternFill("solid", fgColor="D9F2E3"),
    "Fail": PatternFill("solid", fgColor="F8D7DA"),
    "Blocked": PatternFill("solid", fgColor="FFF1CC"),
}
WIDTHS = {"case_id": 14, "title": 40, "error_message": 50, "root_cause": 60, "notes": 50}


def _header(ws, row: int, labels: list[str]) -> None:
    for column, label in enumerate(labels, 1):
        cell = ws.cell(row, column, label)
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = HEADER_FILL
        cell.alignment = Alignment(vertical="center", wrap_text=True)


def _summary(ws, record: ExecutionRecord, changes: list[dict[str, Any]]) -> None:
    meta = record.metadata
    totals = meta.get("totals", {})
    rate = totals.get("pass_rate")
    lines: list[tuple[str, Any]] = [
        ("Execution", record.execution_id),
        ("Project", meta.get("project", "")),
        ("Environment", meta.get("environment", "")),
        ("App", " @ ".join(p for p in (meta.get("app_version"), meta.get("app_revision")) if p)),
        ("Started", meta.get("started_at", "")),
        ("Finished", meta.get("finished_at", "")),
        ("Pass rate (executed)", "n/a" if rate is None else f"{rate}%"),
        ("Critical (P1) failures", totals.get("critical_failures", 0)),
        ("", ""),
    ]
    lines += [(status, count) for status, count in totals.get("by_status", {}).items()]
    if totals.get("by_source"):
        lines += [("", ""), ("Failures by source", "")]
        lines += list(totals["by_source"].items())
    if changes:
        lines += [("", ""), ("Changes since last run", "")]
        lines += [(c["case_id"], f"{c['kind']}: {c['previous_status']} → {c['status']}")
                  for c in changes]  # fmt: skip
    for row, (key, value) in enumerate(lines, 1):
        put_cell(ws, row, 1, key)
        put_cell(ws, row, 2, value)
        ws.cell(row, 1).font = Font(bold=bool(key))
    ws.column_dimensions["A"].width = 28
    ws.column_dimensions["B"].width = 60


def build_excel_report(
    record: ExecutionRecord, headers: dict[str, str], local_label: str = ""
) -> Path:
    wb = Workbook()
    summary = wb.active
    summary.title = "Summary"
    _summary(summary, record, record.metadata.get("changes", []))

    ws = wb.create_sheet("Results")
    fields = list(headers)
    fields.insert(fields.index("case_id") + 1, "title")
    fields.insert(fields.index("title") + 1, "priority")
    labels = [headers.get(f, f.replace("_", " ").title()) for f in fields]
    _header(ws, 1, labels)
    for row, result in enumerate(record.results, 2):
        note = evidence_note(record.root, result["case_id"])
        values = result_row(result, record.metadata, local_label, note)
        values |= {"title": result.get("title", ""), "priority": result.get("priority", "")}
        for column, field in enumerate(fields, 1):
            put_cell(ws, row, column, values.get(field, ""))
            ws.cell(row, column).alignment = Alignment(vertical="top", wrap_text=True)
        fill = STATUS_FILL.get(str(result["status"]))
        if fill:
            ws.cell(row, fields.index("test_result") + 1).fill = fill
    for column, field in enumerate(fields, 1):
        ws.column_dimensions[ws.cell(1, column).column_letter].width = WIDTHS.get(field, 18)
    ws.freeze_panes = "C2"
    ws.auto_filter.ref = ws.dimensions

    target = record.root / "report.xlsx"
    wb.save(target)
    return target
