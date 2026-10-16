"""Appends execution results to the workbook's results sheet.

The workbook is the source of truth that people edit, so writing to it is
careful: refuse while Excel has it open, copy it first, never write the same
run twice, keep the sheet's formula columns (the Triage Check) going on new
rows, and replace the file atomically so a crash cannot leave half a workbook.
"""

import os
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from openpyxl import load_workbook
from openpyxl.cell.cell import ILLEGAL_CHARACTERS_RE
from openpyxl.formula.translate import Translator
from openpyxl.worksheet.worksheet import Worksheet

from automation.core.exceptions import WorkbookError

REQUIRED = ("run_id", "case_id")


@dataclass(frozen=True)
class WriteBackResult:
    rows_written: int
    first_row: int
    backup: Path


def cell_text(value: Any) -> Any:
    if isinstance(value, str):
        return ILLEGAL_CHARACTERS_RE.sub("", value)  # e.g. ANSI colour codes from tool output
    return value


def put_cell(ws: Worksheet, row: int, column: int, value: Any) -> None:
    cell = ws.cell(row, column)
    cell.value = cell_text(value)
    if isinstance(cell.value, str) and cell.value.startswith("="):
        cell.data_type = "s"  # evidence text, never a formula


def _lock_file(path: Path) -> Path:
    return path.with_name(f"~${path.name}")


def _header_columns(ws: Worksheet) -> dict[str, int]:
    return {str(c.value).strip(): c.column for c in ws[1] if c.value is not None}


def _last_used_row(ws: Worksheet, columns: list[int]) -> int:
    last = 1
    for row in range(2, ws.max_row + 1):
        if any(ws.cell(row, c).value not in (None, "") for c in columns):
            last = row
    return last


def _formula_template(ws: Worksheet, column: int, before: int) -> tuple[int, str] | None:
    for row in range(before, 1, -1):
        value = ws.cell(row, column).value
        if isinstance(value, str) and value.startswith("="):
            return row, value
    return None


def write_back(
    workbook_path: Path,
    sheet_name: str,
    headers: dict[str, str],
    rows: list[dict[str, Any]],
    backup_dir: Path,
) -> WriteBackResult:
    if not rows:
        raise WorkbookError("Nothing to write back: no automated results in this execution.")
    if _lock_file(workbook_path).exists():
        raise WorkbookError(f"{workbook_path.name} is open in Excel — close it and retry.")
    wb = load_workbook(workbook_path)
    if sheet_name not in wb.sheetnames:
        raise WorkbookError(f"Sheet {sheet_name!r} not found in {workbook_path.name}")
    ws = wb[sheet_name]
    present = _header_columns(ws)
    columns = {f: present[h] for f, h in headers.items() if h in present}
    missing = [headers[f] for f in REQUIRED if f not in columns]
    if missing:
        raise WorkbookError(f"{sheet_name} has no column {', '.join(missing)}")

    run_ids = {r["run_id"] for r in rows}
    run_col, id_col = columns["run_id"], columns["case_id"]
    for row in range(2, ws.max_row + 1):
        if ws.cell(row, run_col).value in run_ids:
            raise WorkbookError(
                f"{sheet_name} already holds results for {ws.cell(row, run_col).value} "
                f"(row {row}); write-back never duplicates a run."
            )

    start = _last_used_row(ws, [run_col, id_col]) + 1
    formula_columns = [c for c in present.values() if c not in columns.values()]
    for offset, values in enumerate(rows):
        target = start + offset
        for field, column in columns.items():
            put_cell(ws, target, column, values.get(field, ""))
            if not ws.cell(target, column).has_style and start > 2:
                ws.cell(target, column)._style = ws.cell(2, column)._style
        for column in formula_columns:
            if ws.cell(target, column).value not in (None, ""):
                continue  # pre-filled formula rows keep theirs
            template = _formula_template(ws, column, target - 1)
            if template:
                origin = ws.cell(template[0], column).coordinate
                destination = ws.cell(target, column).coordinate
                ws.cell(target, column).value = Translator(template[1], origin).translate_formula(
                    destination
                )

    backup_dir.mkdir(parents=True, exist_ok=True)
    backup = backup_dir / f"{workbook_path.stem}.before-write-back{workbook_path.suffix}"
    shutil.copy2(workbook_path, backup)
    temporary = workbook_path.with_name(f".{workbook_path.stem}.writing{workbook_path.suffix}")
    wb.save(temporary)
    os.replace(temporary, workbook_path)
    return WriteBackResult(len(rows), start, backup)
