"""The one place secrets and personal data are removed before anything is
logged, written as evidence, or shown in a report.

Masks by key name (``password``, ``refreshToken`` …) and by value shape (JWTs,
bearer headers, phone numbers), so a token that arrives under an innocent key
is still caught. Projects add their own key names through ``Masker(extra_keys)``.
"""

import re
from collections.abc import Iterable, Mapping
from typing import Any

MASK = "***"

DEFAULT_SENSITIVE_KEYS: frozenset[str] = frozenset(
    {
        "password",
        "newpassword",
        "currentpassword",
        "confirmpassword",
        "otp",
        "token",
        "accesstoken",
        "refreshtoken",
        "resettoken",
        "idtoken",
        "authorization",
        "cookie",
        "setcookie",
        "secret",
        "clientsecret",
        "apikey",
        "xapikey",
        "privatekey",
    }
)

_JWT = re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}")
_BEARER = re.compile(r"(?i)\b(bearer|basic)\s+[A-Za-z0-9._~+/=-]{8,}")
# International (+855 12 345 678) or local mobile (012 345 678 / 0123456789).
_PHONE = re.compile(r"(?<![\w-])(?:\+\d{1,3}[\s-]?)?0?\d{2}[\s-]?\d{3}[\s-]?\d{3,4}(?![\w-])")


def _normalise(key: str) -> str:
    return re.sub(r"[^a-z0-9]", "", key.lower())


def mask_phone(value: str) -> str:
    """Keep the first 3 and last 3 digits so a tester can still tell numbers apart."""
    digits = re.sub(r"\D", "", value)
    if len(digits) < 8:
        return value
    return f"{digits[:3]}{MASK}{digits[-3:]}"


class Masker:
    def __init__(self, extra_keys: Iterable[str] = ()) -> None:
        self._keys = DEFAULT_SENSITIVE_KEYS | {_normalise(k) for k in extra_keys}

    def is_sensitive_key(self, key: str) -> bool:
        normalised = _normalise(key)
        return normalised in self._keys or normalised.endswith(("token", "password", "secret"))

    def mask_text(self, text: str) -> str:
        text = _JWT.sub(MASK, text)
        text = _BEARER.sub(lambda m: f"{m.group(1)} {MASK}", text)
        return _PHONE.sub(lambda m: mask_phone(m.group(0)), text)

    def mask(self, value: Any) -> Any:
        """Return a masked copy of ``value``; the input is never modified."""
        if isinstance(value, Mapping):
            return {
                k: MASK if self.is_sensitive_key(str(k)) else self.mask(v) for k, v in value.items()
            }
        if isinstance(value, list | tuple):
            return type(value)(self.mask(v) for v in value)
        if isinstance(value, str):
            return self.mask_text(value)
        return value


DEFAULT_MASKER = Masker()
