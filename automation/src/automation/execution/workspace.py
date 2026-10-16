"""One folder per execution, never reused: ``reports/EXEC-YYYYMMDD-NNN/``."""

import json
import re
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

from automation.core.masking import DEFAULT_MASKER, Masker

SUBFOLDERS = ("logs", "flutter", "api", "device", "screenshots")
_ID = re.compile(r"^EXEC-(\d{8})-(\d{3})$")


def next_execution_id(reports_dir: Path, today: date) -> str:
    stamp = today.strftime("%Y%m%d")
    used = [
        int(m.group(2))
        for p in reports_dir.glob(f"EXEC-{stamp}-*")
        if (m := _ID.match(p.name)) and m.group(1) == stamp
    ]
    return f"EXEC-{stamp}-{max(used, default=0) + 1:03d}"


@dataclass(frozen=True)
class Workspace:
    execution_id: str
    root: Path
    masker: Masker = DEFAULT_MASKER

    @classmethod
    def create(cls, reports_dir: Path, today: date, masker: Masker = DEFAULT_MASKER) -> "Workspace":
        reports_dir.mkdir(parents=True, exist_ok=True)
        execution_id = next_execution_id(reports_dir, today)
        root = reports_dir / execution_id
        root.mkdir()  # fails rather than overwrite an existing execution
        for name in SUBFOLDERS:
            (root / name).mkdir()
        return cls(execution_id, root, masker)

    def path(self, *parts: str) -> Path:
        return self.root.joinpath(*parts)

    def write_json(self, relative: str, data: Any) -> Path:
        """Masked before writing: evidence never holds a secret."""
        target = self.path(relative)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            json.dumps(self.masker.mask(data), indent=2, ensure_ascii=False, default=str),
            encoding="utf-8",
        )
        return target
