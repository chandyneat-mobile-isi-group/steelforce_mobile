"""Decides where a failure most likely comes from — only as far as evidence goes.

Rules are ordered; the first that matches wins; the fallback is always
Unknown / Low with the missing evidence named. Nothing defaults to Mobile and
no HTTP error is assumed to be Backend.

This module covers evidence from Flutter unit/widget tests. Those tests run
against fakes, so Backend, Network, Database and SAP are excluded by
construction. API and device evidence rules arrive with Phases 4, 5 and 7.
"""

import re
from collections.abc import Callable, Sequence
from dataclasses import replace

from automation.analysis.api_rules import diagnose_api_failure
from automation.core.constants import Confidence, IssueSource
from automation.execution.results import Diagnosis, TestFailure

Rule = Callable[[Sequence[TestFailure]], Diagnosis | None]

_COMPILE = re.compile(
    r"Compilation failed|Error: (No named parameter|Method not found|Undefined name|The getter)"
)
_GETIT = re.compile(r"GetIt: Object/factory with type \w+ is not registered")
_ASSERTION = re.compile(r"Expected:.*\n\s*Actual:", re.DOTALL)


def _first(failures: Sequence[TestFailure], pattern: re.Pattern[str]) -> TestFailure | None:
    return next((f for f in failures if pattern.search(f.message)), None)


def compile_error(failures: Sequence[TestFailure]) -> Diagnosis | None:
    hit = _first([f for f in failures if f.load_error], _COMPILE)
    if hit is None:
        return None
    return Diagnosis(
        IssueSource.AUTOMATION,
        Confidence.HIGH,
        "Functional",
        f"{hit.ref} no longer compiles against the app code, so none of its tests ran. "
        "The app's API changed and the test was not updated.",
        "Mobile",
    )


def missing_registration(failures: Sequence[TestFailure]) -> Diagnosis | None:
    hit = _first(failures, _GETIT)
    if hit is None:
        return None
    match = _GETIT.search(hit.message)
    return Diagnosis(
        IssueSource.AUTOMATION,
        Confidence.HIGH,
        "Functional",
        f"Test harness does not register a dependency the screen needs ({match.group(0)}). "
        "The behaviour under test was never reached.",
        "Mobile",
    )


def assertion_mismatch(failures: Sequence[TestFailure]) -> Diagnosis | None:
    hit = _first(failures, _ASSERTION)
    if hit is None:
        return None
    return Diagnosis(
        IssueSource.UNKNOWN,
        Confidence.LOW,
        "Functional",
        f"'{hit.test_name}' saw a different value than it expects. The test runs against "
        "fakes, so Backend, Network, Database and SAP are ruled out: either the app "
        "behaviour changed (Mobile) or the test expectation is out of date (Automation).",
        "Mobile",
        (
            "Compare the expected value with the current app code and its requirement",
            "Check git history of the app file and the test file",
        ),
    )


RULES: tuple[Rule, ...] = (compile_error, missing_registration, assertion_mismatch)


def diagnose_test_failures(failures: Sequence[TestFailure]) -> Diagnosis:
    for rule in RULES:
        diagnosis = rule(failures)
        if diagnosis is not None:
            return diagnosis
    return Diagnosis(
        IssueSource.UNKNOWN,
        Confidence.LOW,
        "Functional",
        "The failure does not match a known pattern.",
        "QA",
        ("Full stack trace in the flutter evidence file", "Steps to reproduce on a device"),
    )


def diagnose_infrastructure(message: str) -> Diagnosis:
    """The runner itself could not run (no SDK, timeout, no results file)."""
    return Diagnosis(
        IssueSource.ENVIRONMENT,
        Confidence.MEDIUM,
        "Functional",
        f"The test run could not complete: {message}",
        "DevOps",
        ("Runner stdout in the flutter evidence folder",),
    )


# ── Device tests: the real app against a real backend ─────────────────────
# Nothing is ruled out by construction here, so the rules only claim what the
# message proves; everything else is Unknown with the cross-checks named.

_MISSING_DEFINE = re.compile(r"were not passed as --dart-define")
# The app's own request log (core/network/interceptors/api_log_interceptor.dart).
_APP_API_ERROR = re.compile(
    r"api\.error method=(?P<method>\S+) path=(?P<path>\S+) host=(?P<host>\S+) "
    r"status=(?P<status>\S+).*?errorCode=(?P<code>\S+) correlationId=(?P<corr>\S+) "
    r"dioType=(?P<dio>\S+)"
)
# Written by integration_test/support/automation_harness.dart for a response
# the test made up itself.
_INJECTED = re.compile(r"\[automation\] injected response: (?P<method>\S+) (?P<path>\S+)")
_DIO_TRANSPORT = {
    "connectionError": "connect_error",
    "connectionTimeout": "connect_timeout",
    "receiveTimeout": "read_timeout",
    "sendTimeout": "write_timeout",
}
_TIMED_OUT = re.compile(r"Timed out after \d+s waiting for (?P<what>[^.\n]+)")

DEVICE_CROSS_CHECKS = (
    "Screenshots in the execution's screenshots/ folder",
    "Run the API tests of the same case: if they pass, the backend is answering correctly",
    "Device log (Xcode / logcat) around the failure time",
)


def _missing_define(failures: Sequence[TestFailure]) -> Diagnosis | None:
    hit = _first(failures, _MISSING_DEFINE)
    if hit is None:
        return None
    return Diagnosis(
        IssueSource.TEST_DATA,
        Confidence.HIGH,
        "Functional",
        f"'{hit.test_name}' did not receive its account or configuration — the secrets "
        "behind flutter.dart_defines are not set for this environment.",
        "QA",
        ("Set the secrets named in project.yaml flutter.dart_defines",),
    )


def _app_api_errors(failures: Sequence[TestFailure]) -> Diagnosis | None:
    """The app logged failed requests during the test: judge them like API
    evidence. The last one decides, as for API tests."""
    injected = {(m["method"], m["path"]) for f in failures for m in _INJECTED.finditer(f.message)}
    calls = [
        {
            "method": m["method"],
            "url": f"https://{m['host']}{m['path']}",
            "status": int(m["status"]) if m["status"].isdigit() else None,
            "error_code": "" if m["code"].startswith("Client.") else m["code"],
            "correlation_id": m["corr"],
            "transport_error": ""
            if m["status"].isdigit()
            else _DIO_TRANSPORT.get(m["dio"], "transport"),
        }
        for f in failures
        for m in _APP_API_ERROR.finditer(f.message)
        if (m["method"], m["path"]) not in injected
    ]
    if not calls and injected:
        return Diagnosis(
            IssueSource.UNKNOWN,
            Confidence.LOW,
            "Functional",
            "The failing response was made up by the test itself, so Backend, Network and "
            "Test Data are ruled out: either the app handles that response wrongly (Mobile) "
            "or the test expects the wrong thing (Automation).",
            "Mobile",
            (
                "Compare the screenshot with the expected result in the workbook",
                "Read the test's expectation against the app code that handles the response",
            ),
        )
    if not calls:
        return None
    diagnosis = diagnose_api_failure(failures[0].message, calls)
    return replace(diagnosis, reasoning=f"From the app's request log: {diagnosis.reasoning}")


def _timed_out(failures: Sequence[TestFailure]) -> Diagnosis | None:
    hit = _first(failures, _TIMED_OUT)
    if hit is None:
        return None
    what = _TIMED_OUT.search(hit.message).group("what")  # type: ignore[union-attr]
    return Diagnosis(
        IssueSource.UNKNOWN,
        Confidence.LOW,
        "Functional",
        f"The app never reached {what}. On a device this can be the app (Mobile), a slow "
        "or failing backend (Backend), the connection (Network) or the account (Test Data).",
        "QA",
        DEVICE_CROSS_CHECKS,
    )


def diagnose_device_failures(failures: Sequence[TestFailure]) -> Diagnosis:
    for rule in (compile_error, _missing_define, _app_api_errors, _timed_out):
        diagnosis = rule(failures)
        if diagnosis is not None:
            return diagnosis
    first = failures[0]
    return Diagnosis(
        IssueSource.UNKNOWN,
        Confidence.LOW,
        "Functional",
        f"'{first.test_name}' failed on the device: {first.message.splitlines()[0][:200]}",
        "QA",
        DEVICE_CROSS_CHECKS,
    )
