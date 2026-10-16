"""Command line: ``python -m automation <command>``.

Exit codes: 0 success · 1 tests failed · 2 configuration/usage error ·
3 refused by the environment guard · 4 nothing to report on yet ·
5 no failures, but some cases were Blocked (could not run).
"""

import argparse
import logging
import shutil
import sys
from collections.abc import Callable, Sequence
from itertools import pairwise
from pathlib import Path

from automation import __version__
from automation.core.config import (
    RunContext,
    available_environments,
    discover_projects,
    load_context,
    projects_dir,
)
from automation.core.exceptions import AutomationError, EnvironmentGuardError
from automation.core.guard import ensure_environment_allowed, ensure_markers_allowed
from automation.core.logger import configure_logging, get_logger
from automation.execution.catalog import Catalog, load_catalog
from automation.execution.filters import CaseFilter
from automation.execution.session import execute, history_dir, reports_dir
from automation.history.store import HistoryStore
from automation.reporting.publish import build_reports, write_back_execution
from automation.reporting.record import ExecutionNotFoundError, ExecutionRecord, find_execution
from automation.reporting.summary import render

EXIT_OK, EXIT_FAILED, EXIT_CONFIG, EXIT_GUARD, EXIT_NOT_READY, EXIT_BLOCKED = 0, 1, 2, 3, 4, 5

PRIORITY_ALIASES = {"critical": "P1", "high": "P2", "normal": "P3", "low": "P3"}

log = get_logger("cli")


def _context(args: argparse.Namespace) -> RunContext:
    return load_context(args.project, args.env, args.projects_dir)


def cmd_projects(args: argparse.Namespace) -> int:
    root = projects_dir(args.projects_dir)
    names = discover_projects(root)
    if not names:
        log.error(f"No projects under {root}")
        return EXIT_CONFIG
    for name in names:
        envs = ", ".join(available_environments(root / name))
        print(f"{name}  (environments: {envs})")
    return EXIT_OK


def cmd_config(args: argparse.Namespace) -> int:
    ctx = _context(args)
    env = ctx.environment
    base_url_set = ctx.secrets.get(env.api.base_url_env) is not None
    print(f"Project       {ctx.project.display_name} ({ctx.project.name})")
    print(f"Environment   {env.name}{'  [PROTECTED]' if env.protected else ''}  {env.description}")
    print(f"App root      {ctx.app_root}")
    print(f"Workbook      {ctx.workbook_path}")
    print(f"Flutter dir   {ctx.flutter_dir}")
    print(f"API base URL  {env.api.base_url_env} = {'set' if base_url_set else 'MISSING'}")
    print(f"API timeouts  connect {env.api.connect_timeout_s}s, read {env.api.read_timeout_s}s")
    print(f"Secrets set   {', '.join(ctx.secrets.names()) or 'none'}")
    return EXIT_OK


def _check(label: str, ok: bool, detail: str) -> bool:
    print(f"[{'ok' if ok else 'FAIL'}] {label}: {detail}")
    return ok


def cmd_doctor(args: argparse.Namespace) -> int:
    ctx = _context(args)
    flutter = shutil.which("flutter")
    results = [
        _check("Python", sys.version_info >= (3, 12), sys.version.split()[0]),
        _check("Workbook", ctx.workbook_path.is_file(), str(ctx.workbook_path)),
        _check(
            "Flutter project",
            (ctx.flutter_dir / "pubspec.yaml").is_file(),
            str(ctx.flutter_dir),
        ),
        _check("Flutter SDK", flutter is not None, flutter or "not on PATH"),
        _check(
            f"Secret {ctx.environment.api.base_url_env}",
            ctx.secrets.get(ctx.environment.api.base_url_env) is not None,
            f"needed for API tests on {ctx.environment.name}",
        ),
    ]
    missing = sorted(set(ctx.project.secrets) - set(ctx.secrets.names()))
    if missing:
        print(f"[info] Secrets not set (needed only by tests that use them): {', '.join(missing)}")
    return EXIT_OK if all(results) else EXIT_CONFIG


def _print_issues(catalog: Catalog) -> None:
    for issue in catalog.issues:
        print(issue)


def cmd_validate(args: argparse.Namespace) -> int:
    ctx = _context(args)
    catalog = load_catalog(ctx)
    _print_issues(catalog)
    errors = len(catalog.errors)
    print(
        f"\n{len(catalog.cases)} test cases · {len(catalog.valid_cases)} valid · "
        f"{errors} error(s) · {len(catalog.issues) - errors} warning(s)"
    )
    return EXIT_CONFIG if errors else EXIT_OK


def cmd_run(args: argparse.Namespace) -> int:
    ctx = _context(args)
    ensure_environment_allowed(ctx.environment, args.allow_protected)
    ensure_markers_allowed(ctx.environment, args.include)
    case_filter = CaseFilter(
        case_ids=tuple(args.case or ()),
        module=args.module,
        test_type=args.test_type,
        priority=args.priority,
        suite=args.suite,
        environment=ctx.environment.name,
        level=args.level,
        protected_environment=ctx.environment.protected,
    )
    execution, catalog, excluded = execute(
        ctx, case_filter, verbose=args.verbose, include=tuple(args.include), device=args.device
    )
    _print_issues(catalog)
    for item in excluded:
        log.error(f"Not executed: {item}")
    if execution is None:
        log.error("No valid test case matches the filters.")
        return EXIT_CONFIG
    print(
        render(
            execution.workspace.execution_id,
            execution.summary.results,
            execution.summary.seconds,
        )
    )
    for change in execution.changes:
        print(f"  {change.describe()}")
    print(f"\n  Evidence: {execution.workspace.root}")
    if execution.reports:
        print(f"  Report:   {execution.reports.html}")
    if args.write_back:
        _write_back(ExecutionRecord.load(execution.workspace.root), ctx)
    if execution.failed:
        return EXIT_FAILED
    return EXIT_BLOCKED if execution.blocked else EXIT_OK


def _write_back(record: ExecutionRecord, ctx: RunContext) -> None:
    result = write_back_execution(record, ctx)
    print(
        f"  Workbook: {result.rows_written} row(s) appended to Execution_Results from row "
        f"{result.first_row} (backup: {result.backup.name}). "
        f"Set Summary!B3 to {record.execution_id} to see this run."
    )


def cmd_report(args: argparse.Namespace) -> int:
    ctx = _context(args)
    try:
        root = find_execution(reports_dir(), args.execution_id)
    except ExecutionNotFoundError as error:
        log.error(str(error))
        return EXIT_NOT_READY
    record = ExecutionRecord.load(root)
    reports = build_reports(record, ctx)
    print(f"{record.execution_id}\n  HTML:  {reports.html}\n  Excel: {reports.excel}")
    if args.write_back:
        _write_back(record, ctx)
    return EXIT_OK


def cmd_history(args: argparse.Namespace) -> int:
    ctx = _context(args)
    store = HistoryStore.for_project(history_dir(), ctx.project.name)
    entries = store.entries(args.case, args.env)
    if not entries:
        log.error(f"No history for {args.case}" + (f" on {args.env}" if args.env else ""))
        return EXIT_NOT_READY
    print(f"{args.case.upper()} — last {min(args.limit, len(entries))} of {len(entries)} run(s)")
    print(f"  {'Execution':<18} {'Env':<9} {'Result':<8} {'Source':<12} App")
    for e in entries[-args.limit :]:
        source = f"{e.source} ({e.confidence})" if e.source else ""
        print(f"  {e.execution_id:<18} {e.environment:<9} {e.status:<8} {source:<12} "
              f"{e.app_version} @ {e.app_revision}")  # fmt: skip
    verdicts = [e.status for e in entries if e.status in ("Pass", "Fail")]
    flips = sum(1 for a, b in pairwise(verdicts) if a != b)
    if flips >= 2:
        print(f"  Flaky? The verdict changed {flips} times across {len(verdicts)} runs.")
    return EXIT_OK


def _priority(value: str) -> str:
    return PRIORITY_ALIASES.get(value.lower(), value.upper())


def _csv(value: str) -> list[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument(
        "--project", help="project profile (default: the only one, or $AUTOMATION_PROJECT)"
    )
    common.add_argument("--env", help="environment (default: the project's default_environment)")
    common.add_argument("--projects-dir", type=Path, help="folder holding project profiles")
    common.add_argument("-v", "--verbose", action="store_true", help="debug logging")

    parser = argparse.ArgumentParser(
        prog="python -m automation",
        description="Excel-driven QA automation for mobile apps.",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = parser.add_subparsers(dest="command", required=True)

    commands: dict[str, tuple[str, Callable[[argparse.Namespace], int]]] = {
        "projects": ("list project profiles", cmd_projects),
        "config": ("show the resolved configuration (no secret values)", cmd_config),
        "doctor": ("check the local setup", cmd_doctor),
        "validate": ("validate the Excel test cases", cmd_validate),
        "report": ("build reports for an execution", cmd_report),
        "history": ("show execution history for a test case", cmd_history),
    }
    for name, (help_text, handler) in commands.items():
        p = sub.add_parser(name, parents=[common], help=help_text)
        p.set_defaults(handler=handler)
        if name == "report":
            p.add_argument("--exec", dest="execution_id", help="execution id (default: the latest)")
            p.add_argument(
                "--write-back", action="store_true", help="append results to the workbook"
            )
        if name == "history":
            p.add_argument("--case", required=True, help="test case id")
            p.add_argument("--limit", type=int, default=20, help="runs to show (default 20)")

    run = sub.add_parser("run", parents=[common], help="execute test cases")
    run.set_defaults(handler=cmd_run)
    run.add_argument("--suite", help="smoke, regression, … (from the workbook's Suites column)")
    run.add_argument("--module", help="workbook Module, case-insensitive")
    run.add_argument("--type", dest="test_type", help="workbook Test Type, case-insensitive")
    run.add_argument("--priority", type=_priority, help="P1/P2/P3 or critical/high/normal")
    run.add_argument("--case", type=_csv, help="one or more test case ids, comma-separated")
    run.add_argument("--level", choices=["api", "flutter", "device"], help="only one test level")
    run.add_argument(
        "--include", type=_csv, default=[], help="opt in to marked tests: destructive,sms,lockout"
    )
    run.add_argument("--device", help="device id or name for device tests (`flutter devices`)")
    run.add_argument("--allow-protected", action="store_true", help="see the environment guard")
    run.add_argument("--write-back", action="store_true", help="append results to the workbook")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    configure_logging(logging.DEBUG if args.verbose else logging.INFO)
    try:
        return args.handler(args)
    except EnvironmentGuardError as error:
        log.error(str(error))
        return EXIT_GUARD
    except AutomationError as error:
        log.error(str(error))
        return EXIT_CONFIG
