"""Every HTTP call an API test makes, kept as triage evidence.

Bodies and headers are masked when the record is made, so nothing downstream
(evidence files, reports, the classifier) ever holds a secret.
"""

from dataclasses import asdict, dataclass, field
from typing import Any

from automation.core.masking import DEFAULT_MASKER, Masker


@dataclass(frozen=True)
class ApiCall:
    method: str
    url: str
    correlation_id: str
    request_headers: dict[str, Any]
    request_body: Any
    status: int | None = None
    response_headers: dict[str, Any] = field(default_factory=dict)
    response_body: Any = None
    elapsed_ms: int | None = None
    # Set when no response arrived: connect_error, connect_timeout,
    # read_timeout, write_timeout, pool_timeout, protocol_error.
    transport_error: str = ""
    transport_detail: str = ""

    def _error_field(self, *keys: str) -> str:
        """First non-empty string under ``keys``, at the top level or inside an
        ``error`` object (``{"error": {"code": …, "traceId": …}}``)."""
        body = self.response_body
        if not isinstance(body, dict):
            return ""
        nested = body.get("error") if isinstance(body.get("error"), dict) else {}
        for source in (body, nested):
            for key in keys:
                value = source.get(key)
                if isinstance(value, str) and value:
                    return value
        return ""

    @property
    def error_code(self) -> str:
        """The platform's stable error code, wherever the body carries it."""
        return self._error_field("errorCode", "code", "error")

    @property
    def server_trace_id(self) -> str:
        """The id the server logged this request under, when it returns one."""
        return self._error_field("traceId", "correlationId")

    def to_dict(self) -> dict[str, Any]:
        return {
            **asdict(self),
            "error_code": self.error_code,
            "server_trace_id": self.server_trace_id,
        }


class ApiRecorder:
    def __init__(self, masker: Masker = DEFAULT_MASKER) -> None:
        self._masker = masker
        self.calls: list[ApiCall] = []

    def record(self, **fields: Any) -> ApiCall:
        for key in ("request_headers", "request_body", "response_headers", "response_body"):
            if key in fields:
                fields[key] = self._masker.mask(fields[key])
        fields["url"] = self._masker.mask_text(fields["url"])
        call = ApiCall(**fields)
        self.calls.append(call)
        return call
