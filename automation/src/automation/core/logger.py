"""Structured, masked logging.

Console lines read ``2026-10-08 14:20:31 INFO  Starting TC-AUTH-002 env=uat``.
The run log file gets one JSON object per line for machines. Both pass through
the masker, so a secret handed to the logger by mistake is still not written.
"""

import json
import logging
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from automation.core.masking import DEFAULT_MASKER, Masker

PASS = 25
FAIL = 35
logging.addLevelName(PASS, "PASS")
logging.addLevelName(FAIL, "FAIL")

ROOT_LOGGER = "automation"
_FIELDS = "fields"


class _MaskingFilter(logging.Filter):
    def __init__(self, masker: Masker) -> None:
        super().__init__()
        self._masker = masker

    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = self._masker.mask_text(record.getMessage())
        record.args = None
        setattr(record, _FIELDS, self._masker.mask(getattr(record, _FIELDS, {}) or {}))
        return True


class _ConsoleFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        stamp = datetime.fromtimestamp(record.created).strftime("%Y-%m-%d %H:%M:%S")
        fields = getattr(record, _FIELDS, {})
        suffix = "".join(f" {k}={v}" for k, v in fields.items())
        line = f"{stamp} {record.levelname:<5} {record.getMessage()}{suffix}"
        if record.exc_info:
            line += "\n" + self.formatException(record.exc_info)
        return line


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "time": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            **getattr(record, _FIELDS, {}),
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str, ensure_ascii=False)


def configure_logging(
    level: int = logging.INFO,
    log_file: Path | None = None,
    masker: Masker = DEFAULT_MASKER,
) -> logging.Logger:
    """Configure the framework logger. Safe to call again (handlers are replaced)."""
    logger = logging.getLogger(ROOT_LOGGER)
    logger.setLevel(level)
    logger.propagate = False
    for handler in list(logger.handlers):
        logger.removeHandler(handler)
        handler.close()

    console = logging.StreamHandler()
    console.setFormatter(_ConsoleFormatter())
    console.addFilter(_MaskingFilter(masker))
    logger.addHandler(console)

    if log_file is not None:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setFormatter(_JsonFormatter())
        file_handler.addFilter(_MaskingFilter(masker))
        logger.addHandler(file_handler)
    return logger


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(f"{ROOT_LOGGER}.{name}")


def log_fields(**fields: Any) -> dict[str, dict[str, Any]]:
    """``logger.info("POST /login", **log_fields(status=200, ms=412))``"""
    return {"extra": {_FIELDS: fields}}
