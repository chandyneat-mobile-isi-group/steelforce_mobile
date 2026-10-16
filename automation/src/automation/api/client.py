"""The one HTTP client for API tests.

Centralises base URL, prefix, timeouts, correlation id, language, bounded
retries and evidence. Projects build their endpoint modules on top of it;
tests never call ``httpx`` directly.
"""

import time
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

import httpx

from automation.api.evidence import ApiCall, ApiRecorder
from automation.core.config import ApiSettings
from automation.core.exceptions import AutomationError
from automation.core.logger import get_logger, log_fields

log = get_logger("api")

IDEMPOTENT = frozenset({"GET", "HEAD", "OPTIONS"})
_TRANSPORT_ERRORS: tuple[tuple[type[httpx.TransportError], str], ...] = (
    (httpx.ConnectTimeout, "connect_timeout"),
    (httpx.ReadTimeout, "read_timeout"),
    (httpx.WriteTimeout, "write_timeout"),
    (httpx.PoolTimeout, "pool_timeout"),
    (httpx.ConnectError, "connect_error"),
    (httpx.RemoteProtocolError, "protocol_error"),
)


class ApiTransportError(AutomationError):
    """No HTTP response arrived. ``call`` holds the evidence."""

    def __init__(self, call: ApiCall) -> None:
        super().__init__(f"{call.method} {call.url}: {call.transport_error}")
        self.call = call


@dataclass(frozen=True)
class ApiResponse:
    status: int
    body: Any
    headers: dict[str, str]
    call: ApiCall

    @property
    def data(self) -> Any:
        """The ``data`` member of an enveloped body, or the body itself."""
        return self.body.get("data", self.body) if isinstance(self.body, dict) else self.body


def _classify_transport(error: httpx.TransportError) -> str:
    return next((name for kind, name in _TRANSPORT_ERRORS if isinstance(error, kind)), "transport")


def _body(response: httpx.Response) -> Any:
    if not response.content:
        return None
    try:
        return response.json()
    except ValueError:
        return response.text[:2000]


class ApiClient:
    def __init__(
        self,
        base_url: str,
        settings: ApiSettings,
        recorder: ApiRecorder | None = None,
        language: str = "en",
        transport: httpx.BaseTransport | None = None,
        sleep: Callable[[float], None] = time.sleep,
    ) -> None:
        self._settings = settings
        self._sleep = sleep
        self.recorder = recorder or ApiRecorder()
        self._language = language
        timeout = httpx.Timeout(settings.read_timeout_s, connect=settings.connect_timeout_s)
        self._http = httpx.Client(
            base_url=base_url.rstrip("/") + settings.api_prefix,
            timeout=timeout,
            transport=transport,
        )

    def close(self) -> None:
        self._http.close()

    def __enter__(self) -> "ApiClient":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    def get(self, path: str, **kw: Any) -> ApiResponse:
        return self.request("GET", path, **kw)

    def post(self, path: str, **kw: Any) -> ApiResponse:
        return self.request("POST", path, **kw)

    def put(self, path: str, **kw: Any) -> ApiResponse:
        return self.request("PUT", path, **kw)

    def patch(self, path: str, **kw: Any) -> ApiResponse:
        return self.request("PATCH", path, **kw)

    def delete(self, path: str, **kw: Any) -> ApiResponse:
        return self.request("DELETE", path, **kw)

    def request(
        self,
        method: str,
        path: str,
        *,
        json: Any = None,
        params: dict[str, Any] | None = None,
        token: str | None = None,
        headers: dict[str, str] | None = None,
    ) -> ApiResponse:
        method = method.upper()
        response = self._send_with_retries(method, path, json, params, token, headers)
        wait = self._rate_limit_wait(response)
        if wait is None:
            return response
        # The rejected attempt stays in the evidence; only one retry is made.
        log.warning("rate limited, waiting", **log_fields(path=path, seconds=wait))
        self._sleep(wait)
        return self._send_with_retries(method, path, json, params, token, headers)

    def _rate_limit_wait(self, response: ApiResponse) -> float | None:
        if response.status != 429 or self._settings.rate_limit_max_wait_s <= 0:
            return None
        try:
            wait = float(response.headers.get("retry-after", ""))
        except ValueError:
            return None
        return wait if 0 <= wait <= self._settings.rate_limit_max_wait_s else None

    def _send_with_retries(self, method, path, json, params, token, headers) -> ApiResponse:
        attempts = 1 + (self._settings.retries if method in IDEMPOTENT else 0)
        for attempt in range(1, attempts + 1):
            try:
                return self._send(method, path, json, params, token, headers)
            except ApiTransportError as error:
                retryable = error.call.transport_error in {"connect_error", "connect_timeout"}
                if attempt == attempts or not retryable:
                    raise
                log.warning("retrying", **log_fields(method=method, path=path, attempt=attempt))
        raise AssertionError("unreachable")

    def _send(self, method, path, json, params, token, headers) -> ApiResponse:
        correlation_id = str(uuid.uuid4())
        sent = {
            "Accept": "application/json",
            "Accept-Language": self._language,
            "X-Correlation-Id": correlation_id,
            **({"Authorization": f"Bearer {token}"} if token else {}),
            **(headers or {}),
        }
        request = self._http.build_request(method, path, json=json, params=params, headers=sent)
        common = {
            "method": method,
            "url": str(request.url),
            "correlation_id": correlation_id,
            "request_headers": sent,
            "request_body": json,
        }
        started = time.monotonic()
        try:
            response = self._http.send(request)
        except httpx.TransportError as error:
            call = self.recorder.record(
                **common,
                elapsed_ms=int((time.monotonic() - started) * 1000),
                transport_error=_classify_transport(error),
                transport_detail=type(error).__name__,
            )
            log.error(f"{method} {path}", **log_fields(error=call.transport_error))
            raise ApiTransportError(call) from error
        body = _body(response)
        call = self.recorder.record(
            **common,
            status=response.status_code,
            response_headers=dict(response.headers),
            response_body=body,
            elapsed_ms=int((time.monotonic() - started) * 1000),
        )
        log.info(f"{method} {path}", **log_fields(status=response.status_code, ms=call.elapsed_ms))
        return ApiResponse(response.status_code, body, dict(response.headers), call)
