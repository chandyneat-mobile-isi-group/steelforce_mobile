"""One execution, end to end: validate → filter → run → evidence → summary."""

import logging
import os
from dataclasses import asdict, dataclass, field
from datetime import UTC, date, datetime
from pathlib import Path

from automation import __version__
from automation.api.pytest_runner import PytestRunner
from automation.core.config import AUTOMATION_ROOT, RunContext
from automation.core.constants import ResultStatus
from automation.core.logger import configure_logging, get_logger, log_fields
from automation.core.masking import Masker
from automation.excel.models import TestCase
from automation.execution.catalog import Catalog, load_catalog
from automation.execution.engine import Engine, RunSummary
from automation.execution.filters import LEVEL_RUNNERS, CaseFilter
from automation.execution.workspace import Workspace
from automation.history.store import Change, HistoryStore, entries_from
from automation.mobile.app_info import app_version, git_revision
from automation.mobile.device_runner import DeviceRunner
from automation.mobile.flutter_runner import FlutterRunner
from automation.reporting.publish import Reports, build_reports
from automation.reporting.record import ExecutionRecord
from automation.reporting.summary import totals

log = get_logger("session")

REPORTS_DIR = AUTOMATION_ROOT / "reports"
HISTORY_DIR = AUTOMATION_ROOT / "history"


def reports_dir() -> Path:
    """``$AUTOMATION_REPORTS_DIR`` or ``automation/reports`` (CI and tests move it)."""
    return Path(os.environ.get("AUTOMATION_REPORTS_DIR") or REPORTS_DIR)


def history_dir() -> Path:
    return Path(os.environ.get("AUTOMATION_HISTORY_DIR") or HISTORY_DIR)


@dataclass(frozen=True)
class Execution:
    workspace: Workspace
    selected: list[TestCase]
    summary: RunSummary
    changes: list[Change] = field(default_factory=list)
    reports: Reports | None = None

    @property
    def failed(self) -> bool:
        return any(r.status is ResultStatus.FAIL for r in self.summary.results)

    @property
    def blocked(self) -> bool:
        return any(r.status is ResultStatus.BLOCKED for r in self.summary.results)


def select(catalog: Catalog, case_filter: CaseFilter) -> tuple[list[TestCase], list[str]]:
    """Cases to run, plus requested ids that cannot run (invalid or unknown)."""
    selected = case_filter.apply(catalog.valid_cases)
    skipped_invalid = sorted(
        c.id for c in case_filter.apply(catalog.cases) if c.id in catalog.invalid_ids
    )
    known = {c.id.upper() for c in catalog.cases}
    unknown = [i for i in case_filter.case_ids if i.upper() not in known]
    return selected, skipped_invalid + [f"{i} (not in workbook)" for i in unknown]


def execute(
    ctx: RunContext,
    case_filter: CaseFilter,
    reports_root: Path | None = None,
    today: date | None = None,
    verbose: bool = False,
    include: tuple[str, ...] = (),
    device: str | None = None,
    history_root: Path | None = None,
) -> tuple[Execution | None, Catalog, list[str]]:
    catalog = load_catalog(ctx)
    selected, excluded = select(catalog, case_filter)
    if not selected:
        return None, catalog, excluded

    masker = Masker(ctx.project.masking.extra_keys)
    workspace = Workspace.create(reports_root or reports_dir(), today or date.today(), masker)
    configure_logging(
        logging.DEBUG if verbose else logging.INFO, workspace.path("logs", "run.log"), masker
    )
    started = datetime.now(UTC)
    log.info(
        f"Starting {workspace.execution_id}",
        **log_fields(project=ctx.project.name, env=ctx.environment.name, cases=len(selected)),
    )
    pytest_runner = PytestRunner(ctx, ctx.project_dir.parent, include)
    runners = LEVEL_RUNNERS.get(case_filter.level) if case_filter.level else None
    device = device or ctx.environment.flutter.device
    # Without a device, device tests are skipped — unless they were asked for.
    wants_device = bool(device) or case_filter.level == "device"
    device_runner = device_runner_for(ctx, masker, device) if wants_device else None
    engine = Engine(
        workspace,
        FlutterRunner(ctx.flutter_dir),
        pytest_runner,
        frozenset(runners) if runners else None,
        device_runner,
    )
    summary = engine.run(selected)
    metadata = _metadata(ctx, workspace, case_filter, selected, excluded, summary, started)
    if device_runner and device_runner.device_info is not None:
        metadata["device"] = device_runner.device_info.to_dict()
    results = [r.to_dict() for r in summary.results]

    # Judged against history before this run joins it.
    store = HistoryStore.for_project(history_root or history_dir(), ctx.project.name)
    current = entries_from(metadata, results)
    changes = store.changes(current)
    metadata["changes"] = [asdict(c) for c in changes]
    workspace.write_json("metadata.json", metadata)
    workspace.write_json("results.json", results)
    store.append(current)

    reports = build_reports(ExecutionRecord.load(workspace.root), ctx)
    return Execution(workspace, selected, summary, changes, reports), catalog, excluded


def device_runner_for(ctx: RunContext, masker: Masker, device: str | None) -> DeviceRunner:
    """Dart-defines are resolved from Secrets; a missing secret is left out so
    the test reports exactly which value it did not receive."""
    settings = ctx.project.flutter
    defines = {
        name: value
        for name, secret in settings.dart_defines.items()
        if (value := ctx.secrets.get(secret))
    }
    return DeviceRunner(
        ctx.flutter_dir,
        device,
        settings.integration_driver,
        defines,
        masker,
        settings.device_timeout_s,
    )


def _metadata(ctx, workspace, case_filter, selected, excluded, summary, started) -> dict:
    t = totals(summary.results)
    return {
        "execution_id": workspace.execution_id,
        "framework_version": __version__,
        "project": ctx.project.name,
        "environment": ctx.environment.name,
        "environment_label": ctx.environment.workbook_label or ctx.environment.name,
        "app_version": app_version(ctx.flutter_dir),
        "app_revision": git_revision(ctx.app_root),
        "workbook": str(ctx.workbook_path),
        "filters": {k: v for k, v in vars(case_filter).items() if v and not k.startswith("_")},
        "selected": [c.id for c in selected],
        "excluded": excluded,
        "started_at": started.isoformat(),
        "finished_at": datetime.now(UTC).isoformat(),
        "runner_seconds": summary.seconds,
        "runner_exit_codes": summary.exit_codes,
        "totals": {
            "by_status": t.by_status,
            "by_source": t.by_source,
            "pass_rate": t.pass_rate,
            "critical_failures": t.critical_failures,
        },
    }
