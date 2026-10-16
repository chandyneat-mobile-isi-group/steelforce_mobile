"""Builds the reports for an execution and, when asked, writes it back to the
workbook. Used by ``run`` right after an execution and by ``report`` later."""

from dataclasses import dataclass
from pathlib import Path

from automation.core.config import ProjectConfig, RunContext
from automation.core.constants import ResultStatus
from automation.core.exceptions import WorkbookError
from automation.core.logger import get_logger
from automation.excel.writer import WriteBackResult, write_back
from automation.execution.catalog import load_catalog
from automation.reporting.evidence_pack import build_evidence_packs, evidence_note
from automation.reporting.excel_report import build_excel_report
from automation.reporting.html_report import build_html_report
from automation.reporting.record import ExecutionRecord
from automation.reporting.rows import DEFAULT_HEADERS, result_row

log = get_logger("publish")


@dataclass(frozen=True)
class Reports:
    html: Path
    excel: Path
    # case id → (evidence items captured, items the workbook asks for)
    evidence: dict[str, tuple[int, int]]


def execution_headers(project: ProjectConfig) -> dict[str, str]:
    """Field → header of the results sheet; the profile overrides the defaults."""
    return DEFAULT_HEADERS | project.workbook.columns.get("execution_results", {})


def build_reports(record: ExecutionRecord, ctx: RunContext) -> Reports:
    """Evidence packs first: the HTML report links to them."""
    try:
        required = {c.id: c.extra.get("evidence", "") for c in load_catalog(ctx).cases}
    except WorkbookError as error:
        log.warning(f"Evidence packs without the workbook's checklist: {error}")
        required = {}
    evidence = build_evidence_packs(record, required, ctx.flutter_dir)
    headers = execution_headers(ctx.project)
    local = ctx.project.workbook.local_environment_label
    return Reports(build_html_report(record), build_excel_report(record, headers, local), evidence)


def write_back_execution(record: ExecutionRecord, ctx: RunContext) -> WriteBackResult:
    """Appends every automated result; manual cases (Not Run) stay for people."""
    sheet = ctx.project.workbook.sheets.get("execution_results")
    if not sheet:
        raise WorkbookError("The project profile names no execution_results sheet.")
    local = ctx.project.workbook.local_environment_label
    rows = [
        result_row(r, record.metadata, local, evidence_note(record.root, r["case_id"]))
        for r in record.results
        if str(r["status"]) != ResultStatus.NOT_RUN
    ]
    return write_back(ctx.workbook_path, sheet, execution_headers(ctx.project), rows, record.root)
