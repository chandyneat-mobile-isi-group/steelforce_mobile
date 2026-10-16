"""Classifies a failed API test from the HTTP evidence it recorded.

The decisive call is the last one that went wrong (no response, or a status
of 400+); if every call succeeded, the response did not match what the test
expects from the documented contract. Each rule says what it is sure of and
what would confirm it. Nothing here defaults to Backend: a timeout, a refused
login or a 404 each point somewhere else.
"""

from collections.abc import Sequence
from dataclasses import replace
from typing import Any

from automation.core.constants import Confidence, IssueSource
from automation.execution.results import Diagnosis

TEST_ACCOUNT_CODES = frozenset(
    {
        "invalid_grant",
        "Auth.InvalidCredentials",
        "Auth.AccountLocked",
        "Auth.AccountInactive",
        "Auth.PasswordExpired",
    }
)


# Cloudflare answers these itself when it cannot reach the server behind it
# (520 to 527, and 530 for a tunnel that is down — "Error 1033").
EDGE_ORIGIN_UNREACHABLE = frozenset({520, 521, 522, 523, 524, 525, 526, 527, 530})


def _decisive(calls: Sequence[dict[str, Any]]) -> dict[str, Any] | None:
    bad = [c for c in calls if c.get("transport_error") or (c.get("status") or 0) >= 400]
    if bad:
        return bad[-1]
    return calls[-1] if calls else None


def _where(call: dict[str, Any]) -> str:
    status = call.get("status")
    code = call.get("error_code") or ""
    parts = [f"{call['method']} {call['url']}", f"HTTP {status}" if status else "", code]
    return " · ".join(p for p in parts if p)


def _corr(call: dict[str, Any]) -> str:
    trace = call.get("server_trace_id")
    ids = f"correlation id {call.get('correlation_id')}" + (
        f" / server trace id {trace}" if trace else ""
    )
    return f"backend log for {ids}"


def _facts(call: dict[str, Any], calls: Sequence[dict[str, Any]]) -> dict[str, Any]:
    url = call.get("url", "")
    path = url[url.find("/api/") :] if "/api/" in url else url
    headers = {k.lower(): v for k, v in (call.get("response_headers") or {}).items()}
    facts = {
        "http_status": call.get("status"),
        "endpoint": f"{call.get('method', '')} {path}",
        "correlation_id": call.get("correlation_id", ""),
        "server_trace_id": call.get("server_trace_id", ""),
        "error_code": call.get("error_code") or call.get("transport_error", ""),
        "retry_after": headers.get("retry-after", ""),
        "api_calls": len(calls),
    }
    return {k: v for k, v in facts.items() if v not in (None, "")}


def diagnose_api_failure(message: str, calls: Sequence[dict[str, Any]]) -> Diagnosis:
    call = _decisive(calls)
    diagnosis = _diagnose(message, call)
    return replace(diagnosis, facts=_facts(call, calls)) if call else diagnosis


def _diagnose(message: str, call: dict[str, Any] | None) -> Diagnosis:
    if call is None:
        return Diagnosis(
            IssueSource.AUTOMATION,
            Confidence.HIGH if "AssertionError" not in message else Confidence.MEDIUM,
            "Functional",
            "The test failed before making any API call — the problem is in the test or its "
            "fixtures, not in the system under test.",
            "QA",
        )
    where = _where(call)
    transport, status, code = (
        call.get("transport_error"),
        call.get("status") or 0,
        call.get("error_code") or "",
    )
    if transport in {"connect_error", "connect_timeout"}:
        return Diagnosis(
            IssueSource.NETWORK, Confidence.MEDIUM, "Integration",
            f"No connection to the server ({transport}) — the request never reached it. {where}",
            "DevOps",
            ("Is the host reachable from this machine (VPN, DNS)?",
             "Does it fail from another network?"),
        )  # fmt: skip
    if transport:
        return Diagnosis(
            IssueSource.UNKNOWN, Confidence.LOW, "Performance",
            f"The request was sent but no answer arrived ({transport}); the server may have "
            f"processed it. {where}",
            "Backend", (_corr(call),),
        )  # fmt: skip
    if status in EDGE_ORIGIN_UNREACHABLE:
        return Diagnosis(
            IssueSource.ENVIRONMENT, Confidence.HIGH, "Integration",
            f"The edge (Cloudflare) could not reach the server behind it (HTTP {status}); the "
            f"request never reached the application. {where}",
            "DevOps",
            ("Is the environment's server / tunnel up? Re-run once it answers normally",),
        )  # fmt: skip
    if status >= 500:
        if code.startswith("Sap."):
            return Diagnosis(
                IssueSource.SAP, Confidence.HIGH, "Integration",
                f"The backend reports an SAP failure. {where}", "SAP", (_corr(call),),
            )  # fmt: skip
        return Diagnosis(
            IssueSource.BACKEND, Confidence.HIGH, "API",
            f"Server error on a request built from the documented contract. {where}",
            "Backend", (_corr(call),),
        )  # fmt: skip
    if code in TEST_ACCOUNT_CODES or (status == 401 and call["url"].endswith("/auth/login")):
        return Diagnosis(
            IssueSource.TEST_DATA, Confidence.HIGH, "Functional",
            f"The test account was refused. {where}", "QA",
            ("Check the account in the admin portal (active, not locked, password current)",),
        )  # fmt: skip
    if status == 403:
        return Diagnosis(
            IssueSource.TEST_DATA, Confidence.MEDIUM, "Security",
            f"Permission refused — the test user's role may lack it. {where}", "QA",
            ("Role and permissions of the test user in the portal",),
        )  # fmt: skip
    if status in {404, 405}:
        return Diagnosis(
            IssueSource.ENVIRONMENT, Confidence.MEDIUM, "API",
            f"Route or record not found on this environment. {where}", "Backend",
            ("Is this route deployed on the environment (OpenAPI spec)?", _corr(call)),
        )  # fmt: skip
    if status == 429:
        return Diagnosis(
            IssueSource.ENVIRONMENT, Confidence.MEDIUM, "Performance",
            f"Rate limited, still refused after waiting for Retry-After when allowed. {where}",
            "DevOps",
            ("How many calls this run made to the endpoint (api evidence) — a burst from the "
             "tests themselves means test pacing (Automation)",
             "Rate-limit settings for this environment"),
        )  # fmt: skip
    if status >= 400:
        return Diagnosis(
            IssueSource.BACKEND, Confidence.MEDIUM, "API",
            f"The server refused a request built from the documented contract. {where}",
            "Backend", ("Confirm the request still matches the contract document", _corr(call)),
        )  # fmt: skip
    return Diagnosis(
        IssueSource.BACKEND, Confidence.MEDIUM, "API",
        f"The response does not match the documented contract. {where}",
        "Backend",
        ("Confirm the contract document is current", "Full response in the API evidence file"),
    )  # fmt: skip


def diagnose_blocked(message: str) -> Diagnosis:
    """A test that could not run because its data or configuration is missing."""
    return Diagnosis(
        IssueSource.TEST_DATA,
        Confidence.HIGH,
        "Functional",
        f"Not executed: {message}",
        "QA",
        ("Provide the value in the environment's .env file or the CI secrets",),
    )
