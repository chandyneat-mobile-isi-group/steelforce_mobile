"""Pytest plugin loaded into every API test run (``-p automation.api.pytest_plugin``).

Gives project tests their fixtures (run context, API client, secrets), turns a
missing secret into **Blocked** rather than a pass or a silent skip, holds back
safety-marked tests unless included, and writes one result record per test —
with its masked API calls — for the engine to read.

The runner passes everything through environment variables (``ENV_*`` below),
so the plugin needs no command-line options of its own.
"""

import json
import os
import re
from collections.abc import Callable, Iterator
from pathlib import Path
from typing import Any

import pytest

from automation.api.client import ApiClient
from automation.api.evidence import ApiRecorder
from automation.core.config import RunContext, load_context
from automation.core.constants import SafetyMarker
from automation.core.exceptions import ConfigError
from automation.core.masking import Masker

ENV_PROJECT = "AUTOMATION_PROJECT"
ENV_ENVIRONMENT = "AUTOMATION_ENV"
ENV_PROJECTS_DIR = "AUTOMATION_PROJECTS_DIR"
ENV_RESULTS_FILE = "AUTOMATION_RESULTS_FILE"
ENV_EVIDENCE_DIR = "AUTOMATION_EVIDENCE_DIR"
ENV_INCLUDE = "AUTOMATION_INCLUDE"

BLOCKED_PREFIX = "BLOCKED: "
_RECORDS = pytest.StashKey[dict[str, dict[str, Any]]]()


def blocked(reason: str) -> None:
    """Stop the test as Blocked: it could not run, which is not a pass."""
    pytest.skip(BLOCKED_PREFIX + reason)


def evidence_file_name(nodeid: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", nodeid).strip("_")


# ── Fixtures ──────────────────────────────────────────────────────────────


@pytest.fixture(scope="session")
def run_context() -> RunContext:
    projects_dir = os.environ.get(ENV_PROJECTS_DIR)
    return load_context(
        os.environ.get(ENV_PROJECT),
        os.environ.get(ENV_ENVIRONMENT),
        Path(projects_dir) if projects_dir else None,
    )


@pytest.fixture
def secret(run_context: RunContext) -> Callable[[str], str]:
    """``secret("NAME")`` → value, or the test is Blocked naming what is missing."""

    def get(name: str) -> str:
        value = run_context.secrets.get(name)
        if value is None:
            blocked(f"secret {name} is not configured for {run_context.environment.name}")
        return value  # type: ignore[return-value]

    return get


@pytest.fixture
def api_recorder(run_context: RunContext) -> ApiRecorder:
    return ApiRecorder(Masker(run_context.project.masking.extra_keys))


@pytest.fixture
def api_client(run_context: RunContext, api_recorder: ApiRecorder) -> Iterator[ApiClient]:
    try:
        base_url = run_context.api_base_url
    except ConfigError:
        blocked(
            f"secret {run_context.environment.api.base_url_env} (API base URL) is not "
            f"configured for {run_context.environment.name}"
        )
    with ApiClient(base_url, run_context.environment.api, api_recorder) as client:
        yield client


# ── Safety markers ────────────────────────────────────────────────────────

MARKER_HELP = {
    SafetyMarker.DESTRUCTIVE: "changes data in the target environment",
    SafetyMarker.SMS: "sends a real SMS",
    SafetyMarker.LOCKOUT: "can lock a test account (failed sign-ins)",
}


def pytest_configure(config: pytest.Config) -> None:
    for marker, text in MARKER_HELP.items():
        config.addinivalue_line("markers", f"{marker.value}: {text}")


def _included() -> set[str]:
    return {m.strip() for m in os.environ.get(ENV_INCLUDE, "").split(",") if m.strip()}


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    records = config.stash.setdefault(_RECORDS, {})
    included = _included()
    keep, excluded = [], []
    for item in items:
        risky = {m.name for m in item.iter_markers()} & {m.value for m in SafetyMarker}
        missing = sorted(risky - included)
        if missing:
            excluded.append(item)
            records[item.nodeid] = {
                "nodeid": item.nodeid,
                "outcome": "excluded",
                "message": f"marked {missing}; run with --include {','.join(missing)}",
                "api_calls": [],
            }
        else:
            keep.append(item)
    if excluded:
        config.hook.pytest_deselected(items=excluded)
        items[:] = keep


# ── Result records ────────────────────────────────────────────────────────


@pytest.hookimpl(wrapper=True)
def pytest_runtest_makereport(item: pytest.Item, call: pytest.CallInfo[None]):
    report: pytest.TestReport = yield
    records = item.config.stash.setdefault(_RECORDS, {})
    if report.when == "teardown":
        # A teardown error is never ignored: it turns a pass into a failure.
        previous = records.get(item.nodeid)
        if report.failed and previous and previous["outcome"] == "passed":
            previous.update(outcome="failed", phase="teardown", message=report.longreprtext[-6000:])
        return report
    if report.when == "setup" and report.passed:
        return report
    outcome, message = report.outcome, ""
    if report.skipped:
        reason = report.longrepr[2] if isinstance(report.longrepr, tuple) else str(report.longrepr)
        reason = reason.removeprefix("Skipped: ")
        outcome = "blocked" if reason.startswith(BLOCKED_PREFIX) else "skipped"
        message = reason.removeprefix(BLOCKED_PREFIX)
    elif report.failed:
        message = report.longreprtext[-6000:]
    recorder = item.funcargs.get("api_recorder") if hasattr(item, "funcargs") else None
    calls = [c.to_dict() for c in recorder.calls] if isinstance(recorder, ApiRecorder) else []
    records[item.nodeid] = {
        "nodeid": item.nodeid,
        "outcome": outcome,
        "phase": report.when,
        "message": message,
        "duration_s": round(report.duration, 3),
        "api_calls": calls,
    }
    return report


def _scrubber() -> Callable[[Any], str]:
    """JSON text with masking applied and every exact secret value removed. A
    failure message can quote anything a test touched, so nothing the plugin
    writes is trusted to be clean already."""
    try:
        ctx = load_context(
            os.environ.get(ENV_PROJECT),
            os.environ.get(ENV_ENVIRONMENT),
            Path(p) if (p := os.environ.get(ENV_PROJECTS_DIR)) else None,
        )
    except ConfigError:
        return lambda data: Masker().mask_text(json.dumps(data, indent=2, default=str))
    masker = Masker(ctx.project.masking.extra_keys)
    return lambda data: ctx.secrets.redact(
        masker.mask_text(json.dumps(masker.mask(data), indent=2, default=str))
    )


def pytest_sessionfinish(session: pytest.Session) -> None:
    records = session.config.stash.get(_RECORDS, {})
    scrub = _scrubber()
    evidence_dir = os.environ.get(ENV_EVIDENCE_DIR)
    if evidence_dir:
        for nodeid, record in records.items():
            if record["api_calls"]:
                path = Path(evidence_dir) / f"{evidence_file_name(nodeid)}.json"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(scrub(record["api_calls"]))
    results_file = os.environ.get(ENV_RESULTS_FILE)
    if results_file:
        Path(results_file).write_text(scrub(list(records.values())))
