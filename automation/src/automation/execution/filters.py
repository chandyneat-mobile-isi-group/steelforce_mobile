"""Selects test cases by id, module, type, priority, suite, environment, level."""

from dataclasses import dataclass, field

from automation.excel.models import Runner, TestCase

LEVEL_RUNNERS = {
    "api": {Runner.PYTEST},
    "flutter": {Runner.FLUTTER},
    "device": {Runner.DRIVE},
}


@dataclass(frozen=True)
class CaseFilter:
    case_ids: tuple[str, ...] = ()
    module: str | None = None
    test_type: str | None = None
    priority: str | None = None
    suite: str | None = None
    environment: str | None = None
    level: str | None = None
    protected_environment: bool = False
    _ids: frozenset[str] = field(init=False, repr=False)

    def __post_init__(self) -> None:
        object.__setattr__(self, "_ids", frozenset(i.upper() for i in self.case_ids))

    def matches(self, case: TestCase) -> bool:
        return all(
            (
                not self._ids or case.id.upper() in self._ids,
                _same(self.module, case.module),
                _same(self.test_type, case.test_type),
                _same(self.priority, case.priority),
                not self.suite or self.suite.lower() in case.suites,
                self._environment_ok(case),
                self._level_ok(case),
            )
        )

    def _environment_ok(self, case: TestCase) -> bool:
        """Blank Environments means every environment except a protected one."""
        if not self.environment:
            return True
        if case.environments:
            return self.environment.lower() in case.environments
        return not self.protected_environment

    def _level_ok(self, case: TestCase) -> bool:
        if not self.level:
            return True
        runners = LEVEL_RUNNERS[self.level]
        return any(r.runner in runners for r in case.automated_refs)

    def apply(self, cases: list[TestCase]) -> list[TestCase]:
        return [c for c in cases if self.matches(c)]


def _same(wanted: str | None, actual: str) -> bool:
    return not wanted or wanted.strip().lower() == actual.strip().lower()
