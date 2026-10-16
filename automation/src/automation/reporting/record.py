"""An execution as stored on disk — what every report is rebuilt from.

Reports read ``metadata.json`` and ``results.json`` rather than live objects,
so ``report --exec <id>`` produces exactly what the run produced, any time
later. Both files were masked when written.
"""

import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from automation.core.exceptions import AutomationError

_EXEC = re.compile(r"^EXEC-\d{8}-\d{3}$")


class ExecutionNotFoundError(AutomationError):
    pass


@dataclass(frozen=True)
class ExecutionRecord:
    root: Path
    metadata: dict[str, Any]
    results: list[dict[str, Any]]

    @property
    def execution_id(self) -> str:
        return self.metadata["execution_id"]

    @classmethod
    def load(cls, root: Path) -> "ExecutionRecord":
        try:
            metadata = json.loads((root / "metadata.json").read_text(encoding="utf-8"))
            results = json.loads((root / "results.json").read_text(encoding="utf-8"))
        except FileNotFoundError as error:
            raise ExecutionNotFoundError(f"{root.name} is incomplete: {error.filename}") from error
        return cls(root, metadata, results)


def find_execution(reports_dir: Path, execution_id: str | None = None) -> Path:
    """The named execution folder, or the most recent complete one."""
    if execution_id:
        root = reports_dir / execution_id.upper()
        if not root.is_dir():
            raise ExecutionNotFoundError(f"No execution {execution_id} under {reports_dir}")
        return root
    folders = sorted(
        (p for p in reports_dir.glob("EXEC-*") if _EXEC.match(p.name)),
        key=lambda p: p.name,
    )
    complete = [p for p in folders if (p / "results.json").is_file()]
    if not complete:
        raise ExecutionNotFoundError(f"No executions under {reports_dir}")
    return complete[-1]
