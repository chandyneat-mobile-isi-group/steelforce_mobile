import json
import logging
from pathlib import Path

import pytest

from automation.core.logger import PASS, configure_logging, get_logger, log_fields
from automation.core.masking import MASK


def test_console_line_has_time_level_message_and_fields(capsys: pytest.CaptureFixture[str]) -> None:
    configure_logging()
    get_logger("t").info("POST /login", **log_fields(status=200, ms=412))
    line = capsys.readouterr().err.strip()
    assert line.endswith("INFO  POST /login status=200 ms=412")


def test_pass_level_is_printed_as_pass(capsys: pytest.CaptureFixture[str]) -> None:
    configure_logging()
    get_logger("t").log(PASS, "TC-AUTH-002")
    assert "PASS  TC-AUTH-002" in capsys.readouterr().err


def test_secrets_never_reach_console_or_file(
    tmp_path: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    log_file = tmp_path / "run.log"
    configure_logging(log_file=log_file)
    get_logger("t").info(
        "login for 012345678 with Bearer abcdefghijklmn",
        **log_fields(body={"password": "hunter2", "phoneNumber": "012345678"}),
    )
    logging.getLogger("automation").handlers[1].flush()
    console = capsys.readouterr().err
    record = json.loads(log_file.read_text().splitlines()[0])
    for output in (console, json.dumps(record)):
        assert "hunter2" not in output
        assert "012345678" not in output
        assert "abcdefghijklmn" not in output
    assert record["body"]["password"] == MASK


def test_reconfiguring_does_not_duplicate_handlers() -> None:
    configure_logging()
    configure_logging()
    assert len(logging.getLogger("automation").handlers) == 1
