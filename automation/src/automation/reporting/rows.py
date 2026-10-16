"""One case result → one Execution_Results row, keyed by framework field.

The Excel report and the workbook write-back both use this, so a result reads
the same everywhere. Column headers come from the project profile; this module
knows only fields. Root Cause is written as *probable* — a person confirms it.
"""

from typing import Any

from automation.core.constants import ResultStatus

MAX_MESSAGE = 500

# Framework field → default header (the SteelForce workbook's names).
DEFAULT_HEADERS: dict[str, str] = {
    "run_id": "Run ID",
    "case_id": "TC ID",
    "executed_on": "Executed On",
    "executed_by": "Executed By",
    "environment": "Environment",
    "app_version": "App Version",
    "device": "Device",
    "os_version": "OS Version",
    "test_result": "Test Result",
    "issue_detected": "Issue Detected",
    "issue_source": "Issue Source",
    "issue_type": "Issue Type",
    "error_message": "Error Message",
    "http_status": "HTTP Status",
    "api_endpoint": "API Endpoint",
    "correlation_id": "Correlation ID",
    "error_code": "errorCode / dioType",
    "mobile_evidence": "Mobile Evidence",
    "backend_evidence": "Backend Evidence",
    "root_cause": "Root Cause",
    "bug_id": "Bug ID",
    "assigned_team": "Assigned Team",
    "confidence": "Confidence",
    "notes": "Notes",
}

RUNNER_LABELS = {"flutter": "flutter test", "drive": "device", "pytest": "API"}
_MOBILE_RUNNERS = ("flutter:", "drive:")


def _runner(ref: str) -> str:
    return ref.split(":", 1)[0]


def _short(ref: str) -> str:
    target = ref.split(":", 1)[-1]
    return target.rsplit("/", 1)[-1]


def _counts(outcome: dict[str, Any]) -> str:
    parts = [f"{outcome.get(k, 0)} {k}" for k in ("passed", "failed", "skipped") if outcome.get(k)]
    return f"{_short(outcome['ref'])}: {', '.join(parts) or outcome['status']}"


def _evidence(outcomes: list[dict[str, Any]], mobile: bool) -> str:
    chosen = [o for o in outcomes if o["ref"].startswith(_MOBILE_RUNNERS) == mobile]
    lines = [_counts(o) for o in chosen]
    shots = [e for o in chosen for e in o.get("evidence", []) if e.startswith("screenshots/")]
    if shots:
        lines.append("Screenshots: " + ", ".join(shots))
    return "; ".join(lines)


def _first_message(outcomes: list[dict[str, Any]]) -> str:
    for o in outcomes:
        for failure in o.get("failures", []):
            if failure.get("message"):
                return failure["message"].strip()[:MAX_MESSAGE]
    for o in outcomes:
        if o["status"] == ResultStatus.BLOCKED and o.get("note"):
            return o["note"][:MAX_MESSAGE]
    return ""


def environment_label(
    outcomes: list[dict[str, Any]], metadata: dict[str, Any], local_label: str
) -> str:
    """Local results (unit/widget only) are not results *on* an environment."""
    local = outcomes and all(_runner(o["ref"]) == "flutter" for o in outcomes)
    if local and local_label:
        return local_label
    return metadata.get("environment_label") or metadata.get("environment", "")


def result_row(
    result: dict[str, Any],
    metadata: dict[str, Any],
    local_label: str = "",
    evidence_summary: str = "",
) -> dict[str, Any]:
    outcomes = result.get("outcomes", [])
    status = str(result["status"])
    diagnosis = result.get("diagnosis") or {}
    facts = diagnosis.get("facts") or {}
    failed = status == ResultStatus.FAIL
    triaged = status in (ResultStatus.FAIL, ResultStatus.BLOCKED) and diagnosis
    runners = sorted({RUNNER_LABELS.get(_runner(o["ref"]), _runner(o["ref"])) for o in outcomes})
    # The device describes only results that actually ran on it.
    on_device = any(_runner(o["ref"]) == "drive" for o in outcomes)
    device = (metadata.get("device") or {}) if on_device else {}
    root_cause = ""
    if triaged:
        needed = "; ".join(diagnosis.get("missing_evidence") or ())
        root_cause = f"Probable ({diagnosis['confidence']}): {diagnosis['reasoning']}" + (
            f" Needed: {needed}" if needed else ""
        )
    evidence = f"reports/{metadata['execution_id']}"
    if status != ResultStatus.NOT_RUN:
        evidence += f"/cases/{result['case_id']}/evidence.html"
    notes = [result.get("notes", ""), evidence_summary, f"Evidence: {evidence}"]
    return {
        "run_id": metadata["execution_id"],
        "case_id": result["case_id"],
        "executed_on": (metadata.get("finished_at") or "")[:10],
        "executed_by": f"automation ({', '.join(runners)})" if runners else "automation",
        "environment": environment_label(outcomes, metadata, local_label),
        "app_version": " @ ".join(
            p for p in (metadata.get("app_version"), metadata.get("app_revision")) if p
        ),
        "device": device.get("name") or "host (no device)",
        "os_version": device.get("os") or "n/a",
        "test_result": status,
        "issue_detected": "Yes" if failed else "No",
        "issue_source": diagnosis.get("source", "") if triaged else "",
        "issue_type": diagnosis.get("issue_type", "") if triaged else "",
        "error_message": _first_message(outcomes) if status != ResultStatus.PASS else "",
        "http_status": facts.get("http_status", ""),
        "api_endpoint": facts.get("endpoint", ""),
        "correlation_id": " / ".join(
            p for p in (facts.get("correlation_id"), facts.get("server_trace_id")) if p
        ),
        "error_code": facts.get("error_code", ""),
        "mobile_evidence": _evidence(outcomes, mobile=True),
        "backend_evidence": _evidence(outcomes, mobile=False),
        "root_cause": root_cause,
        "bug_id": "",
        "assigned_team": diagnosis.get("team", "") if triaged else "",
        "confidence": diagnosis.get("confidence", "") if triaged else "",
        "notes": " ".join(n for n in notes if n),
    }
