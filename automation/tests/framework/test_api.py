import json
import threading
from collections.abc import Iterator
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import httpx
import pytest

from automation.analysis.api_rules import diagnose_api_failure, diagnose_blocked
from automation.api.client import ApiClient, ApiTransportError
from automation.api.pytest_runner import PytestRunner
from automation.core.config import ApiSettings, load_context
from automation.core.constants import Confidence, IssueSource, ResultStatus
from automation.excel.models import AutomationRef
from automation.execution.outcomes import pytest_outcome

JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
SETTINGS = ApiSettings(base_url_env="X", api_prefix="/api/v1", retries=2)

# ── Client ───────────────────────────────────────────────────────────────


def _client(handler, settings: ApiSettings = SETTINGS) -> ApiClient:
    return ApiClient("https://host.test/", settings, transport=httpx.MockTransport(handler))


def test_every_request_carries_prefix_correlation_language_and_bearer() -> None:
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json={"data": {"ok": True}})

    response = _client(handler).get("/auth/me", token="t0ken")
    request = seen[0]
    assert str(request.url) == "https://host.test/api/v1/auth/me"
    assert request.headers["Authorization"] == "Bearer t0ken"
    assert request.headers["Accept-Language"] == "en"
    assert len(request.headers["X-Correlation-Id"]) == 36
    assert response.data == {"ok": True}
    assert response.call.correlation_id == request.headers["X-Correlation-Id"]


def test_evidence_is_masked_but_the_test_still_sees_real_values() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={"data": {"accessToken": JWT}})

    client = _client(handler)
    response = client.post("/login", json={"phoneNumber": "+85512000111", "password": "hunter2"})
    assert response.data["accessToken"] == JWT  # the test can use the token
    evidence = json.dumps(client.recorder.calls[0].to_dict())
    for secret in ("hunter2", JWT, "12000111", "t0ken"):
        assert secret not in evidence


def test_connect_errors_retry_idempotent_requests_only() -> None:
    attempts: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        attempts.append(request.method)
        raise httpx.ConnectError("refused", request=request)

    client = _client(handler)
    with pytest.raises(ApiTransportError) as error:
        client.get("/x")
    assert attempts == ["GET", "GET", "GET"]  # 1 + retries
    assert error.value.call.transport_error == "connect_error"
    attempts.clear()
    with pytest.raises(ApiTransportError):
        client.post("/x", json={})
    assert attempts == ["POST"]  # a POST is never replayed


def test_a_read_timeout_is_recorded_as_such_and_not_retried() -> None:
    attempts: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        attempts.append(request.method)
        raise httpx.ReadTimeout("slow", request=request)

    with pytest.raises(ApiTransportError) as error:
        _client(handler).get("/x")
    assert error.value.call.transport_error == "read_timeout"
    assert attempts == ["GET"]


def test_the_deciding_call_is_summarised_for_the_workbook() -> None:
    call = _call(429, "TOO_MANY_REQUESTS") | {
        "server_trace_id": "t-1", "response_headers": {"Retry-After": "60"},
    }  # fmt: skip
    facts = diagnose_api_failure("", [_call(200), call]).facts
    assert facts == {
        "http_status": 429, "endpoint": "GET /api/v1/mobile/auth/profile",
        "correlation_id": "c-1", "server_trace_id": "t-1",
        "error_code": "TOO_MANY_REQUESTS", "retry_after": "60", "api_calls": 2,
    }  # fmt: skip


def test_nested_error_envelopes_give_code_and_server_trace_id() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        body = {"success": False, "error": {"code": "TOO_MANY_REQUESTS", "traceId": "abc123"}}
        return httpx.Response(429, json=body)

    call = _client(handler).post("/x", json={}).call
    assert (call.error_code, call.server_trace_id) == ("TOO_MANY_REQUESTS", "abc123")


def _rate_limited_then_ok(retry_after: str):
    responses = [
        httpx.Response(429, headers={"Retry-After": retry_after}, json={"error": {"code": "TOO_MANY_REQUESTS"}}),
        httpx.Response(200, json={"data": {"ok": True}}),
    ]  # fmt: skip
    return lambda request: responses.pop(0)


def test_a_429_is_waited_out_once_and_both_attempts_are_evidence() -> None:
    slept: list[float] = []
    settings = SETTINGS.model_copy(update={"rate_limit_max_wait_s": 65})
    client = ApiClient(
        "https://h/",
        settings,
        transport=httpx.MockTransport(_rate_limited_then_ok("60")),
        sleep=slept.append,
    )
    response = client.post("/refresh", json={})
    assert response.status == 200
    assert slept == [60.0]
    assert [c.status for c in client.recorder.calls] == [429, 200]


@pytest.mark.parametrize(("max_wait", "retry_after"), [(0, "60"), (30, "60"), (65, "soon")])
def test_a_429_is_returned_as_is_when_waiting_is_off_too_long_or_unparseable(
    max_wait, retry_after
) -> None:
    slept: list[float] = []
    settings = SETTINGS.model_copy(update={"rate_limit_max_wait_s": max_wait})
    client = ApiClient(
        "https://h/",
        settings,
        transport=httpx.MockTransport(_rate_limited_then_ok(retry_after)),
        sleep=slept.append,
    )
    assert client.post("/refresh", json={}).status == 429
    assert slept == []


# ── API classification rules ──────────────────────────────────────────────


def _call(status=None, code="", transport="", url="https://h/api/v1/mobile/auth/profile"):
    body = {"errorCode": code} if code else {}
    return {"method": "GET", "url": url, "status": status, "transport_error": transport,
            "error_code": code, "correlation_id": "c-1", "response_body": body}  # fmt: skip


@pytest.mark.parametrize(
    ("call", "source", "confidence"),
    [
        (_call(transport="connect_timeout"), IssueSource.NETWORK, Confidence.MEDIUM),
        (_call(transport="read_timeout"), IssueSource.UNKNOWN, Confidence.LOW),
        (_call(500), IssueSource.BACKEND, Confidence.HIGH),
        (_call(530), IssueSource.ENVIRONMENT, Confidence.HIGH),
        (_call(522), IssueSource.ENVIRONMENT, Confidence.HIGH),
        (_call(502, "Sap.ApiError"), IssueSource.SAP, Confidence.HIGH),
        (_call(400, "invalid_grant", url="https://h/api/v1/mobile/auth/login"), IssueSource.TEST_DATA, Confidence.HIGH),
        (_call(403), IssueSource.TEST_DATA, Confidence.MEDIUM),
        (_call(404), IssueSource.ENVIRONMENT, Confidence.MEDIUM),
        (_call(429), IssueSource.ENVIRONMENT, Confidence.MEDIUM),
        (_call(422, "General.Validation"), IssueSource.BACKEND, Confidence.MEDIUM),
        (_call(200), IssueSource.BACKEND, Confidence.MEDIUM),
    ],
)  # fmt: skip
def test_api_failures_are_classified_from_their_evidence(call, source, confidence) -> None:
    diagnosis = diagnose_api_failure("AssertionError", [call])
    assert (diagnosis.source, diagnosis.confidence) == (source, confidence)


def test_the_last_bad_call_decides_not_an_earlier_good_one() -> None:
    calls = [_call(200), _call(500), _call(200)]
    assert diagnose_api_failure("", calls).source is IssueSource.BACKEND


def test_a_failure_before_any_call_is_the_tests_own_problem() -> None:
    assert diagnose_api_failure("KeyError: 'x'", []).source is IssueSource.AUTOMATION


def test_timeouts_ask_for_the_backend_log_by_correlation_id() -> None:
    diagnosis = diagnose_api_failure("", [_call(transport="read_timeout")])
    assert any("c-1" in m for m in diagnosis.missing_evidence)


def test_blocked_names_what_is_missing() -> None:
    assert "DEMO_PASSWORD" in diagnose_blocked("secret DEMO_PASSWORD is not configured").reasoning


# ── End to end: project API tests → pytest runner → plugin → outcomes ─────


class _Stub(BaseHTTPRequestHandler):
    def _reply(self, status: int, body: dict) -> None:
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_POST(self) -> None:
        self.rfile.read(int(self.headers.get("Content-Length", 0)))
        self._reply(200, {"data": {"accessToken": JWT}})

    def do_GET(self) -> None:
        self._reply(500, {"errorCode": "General.Boom", "detail": "kaboom"})

    def log_message(self, *args: object) -> None:
        pass


@pytest.fixture
def stub_url() -> Iterator[str]:
    server = ThreadingHTTPServer(("127.0.0.1", 0), _Stub)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    yield f"http://127.0.0.1:{server.server_address[1]}"
    server.shutdown()


DEMO_TESTS = f'''
import pytest

def test_login_ok(api_client):
    r = api_client.post("/login", json={{"password": "hunter2"}})
    assert r.status == 200 and r.data["accessToken"] == "{JWT}"

def test_profile(api_client):
    r = api_client.get("/profile")
    assert r.status == 200, f"profile answered {{r.status}}"

def test_needs_a_secret(secret):
    secret("DEMO_PASSWORD")

@pytest.mark.lockout
def test_wrong_password(api_client):
    raise AssertionError("must not run without --include lockout")
'''


def test_api_tests_run_end_to_end_with_evidence_and_classification(
    projects_root: Path, project_dir: Path, stub_url: str, tmp_path: Path
) -> None:
    (project_dir / ".env.uat").write_text(f"DEMO_API_BASE_URL={stub_url}\n")
    (project_dir / "tests" / "api").mkdir(parents=True)
    (project_dir / "tests" / "api" / "test_demo.py").write_text(DEMO_TESTS)
    ctx = load_context(root=projects_root, environ={})
    root = tmp_path / "exec"
    batch = PytestRunner(ctx, projects_root).run(["tests/api/test_demo.py"], root)

    assert batch.infrastructure_error == "", (root / "pytest.stdout.txt").read_text()
    outcomes = {n.split("::")[1]: r["outcome"] for n, r in batch.records.items()}
    assert outcomes == {
        "test_login_ok": "passed",
        "test_profile": "failed",
        "test_needs_a_secret": "blocked",
        "test_wrong_password": "excluded",
    }

    evidence = "".join(p.read_text() for p in (root / "api").glob("*.json"))
    assert "hunter2" not in evidence and JWT not in evidence

    failed = pytest_outcome(
        AutomationRef.parse("pytest:tests/api/test_demo.py::test_profile"), batch, root
    )
    assert failed.status is ResultStatus.FAIL
    assert failed.diagnosis is not None and failed.diagnosis.source is IssueSource.BACKEND
    facts = failed.diagnosis.facts
    assert (facts["http_status"], facts["error_code"]) == (500, "General.Boom")
    assert facts["endpoint"] == "GET /api/v1/profile" and facts["correlation_id"]
    assert any(e.startswith("api/") for e in failed.evidence)

    blocked = pytest_outcome(
        AutomationRef.parse("pytest:tests/api/test_demo.py::test_needs_a_secret"), batch, root
    )
    assert blocked.status is ResultStatus.BLOCKED
    assert "DEMO_PASSWORD" in blocked.note

    marked = pytest_outcome(
        AutomationRef.parse("pytest:tests/api/test_demo.py::test_wrong_password"), batch, root
    )
    assert marked.status is ResultStatus.SKIPPED
    assert "--include lockout" in marked.note


LEAKY_TEST = """
def test_quotes_its_secret_in_the_failure(secret):
    value = secret("DEMO_PASSWORD")
    assert value == "something else", f"compared {value}"
"""


def test_a_secret_quoted_in_a_failure_never_reaches_the_evidence(
    projects_root: Path, project_dir: Path, stub_url: str, tmp_path: Path
) -> None:
    (project_dir / ".env.uat").write_text(
        f"DEMO_API_BASE_URL={stub_url}\nDEMO_PASSWORD=pa55-w0rd-xyz\n"
    )
    (project_dir / "tests" / "api").mkdir(parents=True)
    (project_dir / "tests" / "api" / "test_leaky.py").write_text(LEAKY_TEST)
    ctx = load_context(root=projects_root, environ={})
    root = tmp_path / "exec"
    batch = PytestRunner(ctx, projects_root).run(["tests/api/test_leaky.py"], root)

    assert [r["outcome"] for r in batch.records.values()] == ["failed"]
    written = "".join(p.read_text() for p in root.rglob("*") if p.is_file())
    assert "pa55-w0rd-xyz" not in written
    assert "compared ***" in (root / "pytest.results.json").read_text()
