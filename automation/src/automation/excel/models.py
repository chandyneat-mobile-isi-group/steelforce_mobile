"""Typed test definitions. Raw workbook rows never leave ``excel/``."""

from dataclasses import dataclass, field
from enum import StrEnum


class Runner(StrEnum):
    """Which tool executes an automation reference."""

    FLUTTER = "flutter"  # flutter test (unit / widget)
    DRIVE = "drive"  # flutter drive (device integration, screenshots)
    PYTEST = "pytest"  # Python API tests
    MANUAL = "manual"  # no automation; reported as Not Run


class AutomationRefError(ValueError):
    pass


@dataclass(frozen=True)
class AutomationRef:
    """One explicit link from a test case to an automated test.

    Written in the workbook as ``runner:target[::test name]``, e.g.
    ``flutter:test/features/auth/login_test.dart`` or
    ``pytest:tests/api/test_auth.py::test_login_valid``. ``manual`` alone
    means no automation. There is no fuzzy matching: the reference names
    the file (and optionally the test) exactly.
    """

    runner: Runner
    target: str = ""
    name: str | None = None

    @classmethod
    def parse(cls, text: str) -> "AutomationRef":
        raw = text.strip()
        if raw.lower() == Runner.MANUAL:
            return cls(Runner.MANUAL)
        prefix, sep, rest = raw.partition(":")
        if not sep or not rest.strip():
            raise AutomationRefError(f"{raw!r} is not 'runner:target' or 'manual'")
        try:
            runner = Runner(prefix.strip().lower())
        except ValueError as error:
            allowed = ", ".join(r.value for r in Runner)
            raise AutomationRefError(f"unknown runner {prefix!r} (use {allowed})") from error
        if runner is Runner.MANUAL:
            raise AutomationRefError("'manual' takes no target")
        target, _, name = rest.partition("::")
        return cls(runner, target.strip(), name.strip() or None)

    def __str__(self) -> str:
        if self.runner is Runner.MANUAL:
            return Runner.MANUAL.value
        return f"{self.runner}:{self.target}" + (f"::{self.name}" if self.name else "")


class Severity(StrEnum):
    ERROR = "ERROR"  # the case is not executed
    WARNING = "WARNING"  # reported; the case still runs


@dataclass(frozen=True)
class ValidationIssue:
    severity: Severity
    message: str
    case_id: str = ""
    row: int | None = None
    column: str = ""

    def __str__(self) -> str:
        where = " ".join(
            p for p in (self.case_id, f"row {self.row}" if self.row else "", self.column) if p
        )
        return (
            f"{self.severity:<7} {where}: {self.message}"
            if where
            else f"{self.severity:<7} {self.message}"
        )


@dataclass(frozen=True)
class TestCase:
    __test__ = False  # not a pytest test class

    id: str
    row: int
    module: str
    feature: str
    scenario: str
    priority: str
    test_type: str
    preconditions: str
    steps: str
    expected_result: str
    automation_status: str
    test_data_ids: tuple[str, ...] = ()
    suites: tuple[str, ...] = ()
    environments: tuple[str, ...] = ()
    automation_level: str = ""
    automation_refs: tuple[AutomationRef, ...] = ()
    api_endpoint: str = ""
    triage_hint: str = ""
    extra: dict[str, str] = field(default_factory=dict, compare=False, hash=False)

    @property
    def automated_refs(self) -> tuple[AutomationRef, ...]:
        return tuple(r for r in self.automation_refs if r.runner is not Runner.MANUAL)

    @property
    def is_manual(self) -> bool:
        return not self.automated_refs
