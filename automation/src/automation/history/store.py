"""Append-only history of case results, and what changed since the last run.

Stored as JSON Lines under ``history/<project>.jsonl`` (gitignored): one
record per case per execution, never rewritten. Execution folders can be
deleted to save space; the history that regressions are judged against stays.
"""

import json
from collections.abc import Iterable
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from automation.core.constants import ResultStatus
from automation.core.logger import get_logger

log = get_logger("history")

# Only a verdict can regress or be fixed; Blocked/Skipped/Not Run say nothing.
VERDICTS = frozenset({ResultStatus.PASS.value, ResultStatus.FAIL.value})


@dataclass(frozen=True)
class HistoryEntry:
    execution_id: str
    finished_at: str
    environment: str
    app_version: str
    app_revision: str
    case_id: str
    status: str
    source: str = ""
    confidence: str = ""


@dataclass(frozen=True)
class Change:
    case_id: str
    kind: str  # regression | fixed
    previous_status: str
    previous_execution: str
    status: str

    def describe(self) -> str:
        verb = "REGRESSION" if self.kind == "regression" else "FIXED"
        return (
            f"{verb} {self.case_id}: {self.previous_status} in {self.previous_execution} "
            f"→ {self.status} now"
        )


def entries_from(metadata: dict[str, Any], results: Iterable[dict[str, Any]]) -> list[HistoryEntry]:
    out = []
    for r in results:
        diagnosis = r.get("diagnosis") or {}
        out.append(
            HistoryEntry(
                execution_id=metadata["execution_id"],
                finished_at=metadata.get("finished_at", ""),
                environment=metadata.get("environment", ""),
                app_version=metadata.get("app_version", ""),
                app_revision=metadata.get("app_revision", ""),
                case_id=r["case_id"],
                status=str(r["status"]),
                source=str(diagnosis.get("source", "")),
                confidence=str(diagnosis.get("confidence", "")),
            )
        )
    return out


class HistoryStore:
    def __init__(self, path: Path) -> None:
        self.path = path

    @classmethod
    def for_project(cls, history_dir: Path, project: str) -> "HistoryStore":
        return cls(history_dir / f"{project}.jsonl")

    def entries(
        self, case_id: str | None = None, environment: str | None = None
    ) -> list[HistoryEntry]:
        if not self.path.is_file():
            return []
        found = []
        with self.path.open(encoding="utf-8") as handle:
            for number, line in enumerate(handle, 1):
                try:
                    entry = HistoryEntry(**json.loads(line))
                except (json.JSONDecodeError, TypeError):
                    log.warning(f"Skipping unreadable history line {number} in {self.path.name}")
                    continue
                if case_id and entry.case_id.upper() != case_id.upper():
                    continue
                if environment and entry.environment != environment:
                    continue
                found.append(entry)
        return found

    def contains(self, execution_id: str) -> bool:
        return any(e.execution_id == execution_id for e in self.entries())

    def append(self, entries: list[HistoryEntry]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as handle:
            for entry in entries:
                handle.write(json.dumps(asdict(entry), ensure_ascii=False) + "\n")

    def changes(self, current: list[HistoryEntry]) -> list[Change]:
        """Pass→Fail (regression) and Fail→Pass (fixed) against each case's last
        verdict on the same environment, ignoring the current execution."""
        if not current:
            return []
        ids = {e.execution_id for e in current}
        environment = current[0].environment
        last: dict[str, HistoryEntry] = {}
        for entry in self.entries(environment=environment):
            if entry.execution_id not in ids and entry.status in VERDICTS:
                last[entry.case_id] = entry  # file order is execution order
        found = []
        for entry in current:
            before = last.get(entry.case_id)
            if before is None or entry.status not in VERDICTS or before.status == entry.status:
                continue
            kind = "regression" if entry.status == ResultStatus.FAIL.value else "fixed"
            found.append(
                Change(entry.case_id, kind, before.status, before.execution_id, entry.status)
            )
        return found
