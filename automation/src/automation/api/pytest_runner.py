"""Runs a project's Python API tests in a separate pytest process.

A subprocess keeps the project's tests isolated from the framework's own
self-tests and gives each execution a clean interpreter. Results come back as
the JSON records written by ``automation.api.pytest_plugin``.
"""

import json
import os
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from automation.api import pytest_plugin as plugin
from automation.core.config import RunContext
from automation.core.logger import get_logger, log_fields
from automation.core.masking import Masker

log = get_logger("pytest")


@dataclass
class PytestBatch:
    records: dict[str, dict[str, Any]]
    exit_code: int | None
    infrastructure_error: str = ""
    stdout_path: Path | None = None
    evidence_dir: Path | None = None
    results_path: Path | None = None

    def for_ref(self, target: str, name: str | None) -> list[dict[str, Any]]:
        """Records for one Automation ID: an exact test, or every test in the file."""
        if name is not None:
            nodeid = f"{target}::{name}"
            return [r for n, r in self.records.items() if n == nodeid or n.startswith(nodeid + "[")]
        return [r for n, r in self.records.items() if n.split("::", 1)[0] == target]


@dataclass
class PytestRunner:
    ctx: RunContext
    projects_dir: Path
    include: tuple[str, ...] = ()
    timeout_s: float = 1800
    python: str = field(default=sys.executable)

    def run(self, targets: list[str], evidence_root: Path) -> PytestBatch:
        evidence_dir = evidence_root / "api"
        evidence_dir.mkdir(parents=True, exist_ok=True)
        results = evidence_root / "pytest.results.json"
        stdout = evidence_root / "pytest.stdout.txt"
        env = {
            **os.environ,
            plugin.ENV_PROJECT: self.ctx.project.name,
            plugin.ENV_ENVIRONMENT: self.ctx.environment.name,
            plugin.ENV_PROJECTS_DIR: str(self.projects_dir),
            plugin.ENV_RESULTS_FILE: str(results),
            plugin.ENV_EVIDENCE_DIR: str(evidence_dir),
            plugin.ENV_INCLUDE: ",".join(self.include),
            # The profile folder is importable as a package: `steelforce.api.auth`.
            "PYTHONPATH": os.pathsep.join(
                p for p in (str(self.projects_dir), os.environ.get("PYTHONPATH", "")) if p
            ),
        }
        command = [
            self.python, "-m", "pytest", *targets,
            "-p", "automation.api.pytest_plugin",
            "--rootdir", str(self.ctx.project_dir),
            "-o", "addopts=", "-q", "-rN", "--no-header", "-p", "no:cacheprovider",
        ]  # fmt: skip
        log.info("pytest", **log_fields(targets=len(targets)))
        try:
            with stdout.open("w", encoding="utf-8") as out:
                completed = subprocess.run(
                    command,
                    cwd=self.ctx.project_dir,
                    env=env,
                    stdout=out,
                    stderr=subprocess.STDOUT,
                    timeout=self.timeout_s,
                    check=False,
                )
        except subprocess.TimeoutExpired:
            self._scrub(stdout)
            return PytestBatch({}, None, f"pytest timed out after {self.timeout_s:.0f}s.", stdout)
        self._scrub(stdout)
        if not results.is_file():
            return PytestBatch(
                {},
                completed.returncode,
                "pytest produced no results (see pytest.stdout.txt).",
                stdout,
            )
        records = {r["nodeid"]: r for r in json.loads(results.read_text(encoding="utf-8"))}
        return PytestBatch(records, completed.returncode, "", stdout, evidence_dir, results)

    def _scrub(self, path: Path) -> None:
        """pytest prints failure messages, which can quote anything a test held."""
        masker = Masker(self.ctx.project.masking.extra_keys)
        text = path.read_text(encoding="utf-8", errors="replace")
        path.write_text(self.ctx.secrets.redact(masker.mask_text(text)), encoding="utf-8")
