"""Workbook → validated test cases, shared by ``validate`` and ``run``."""

from dataclasses import dataclass

from automation.core.config import RunContext, available_environments
from automation.excel.models import Runner, Severity, TestCase, ValidationIssue
from automation.excel.reader import WorkbookReader
from automation.excel.validator import Validator, invalid_case_ids


@dataclass(frozen=True)
class Catalog:
    cases: list[TestCase]
    issues: list[ValidationIssue]

    @property
    def invalid_ids(self) -> set[str]:
        return invalid_case_ids(self.issues)

    @property
    def valid_cases(self) -> list[TestCase]:
        return [c for c in self.cases if c.id not in self.invalid_ids]

    @property
    def errors(self) -> list[ValidationIssue]:
        return [i for i in self.issues if i.severity is Severity.ERROR]


def ref_roots(ctx: RunContext) -> dict[Runner, object]:
    """Where each runner's targets live: Dart tests in the app, Python tests in the profile."""
    return {
        Runner.FLUTTER: ctx.flutter_dir,
        Runner.DRIVE: ctx.flutter_dir,
        Runner.PYTEST: ctx.project_dir,
    }


def load_catalog(ctx: RunContext) -> Catalog:
    data = WorkbookReader(ctx.workbook_path, ctx.project.workbook).read()
    validator = Validator(
        data.allowed_values,
        ctx.project.workbook.id_pattern,
        available_environments(ctx.project_dir),
        ref_roots(ctx),
    )
    return Catalog(data.cases, data.issues + validator.validate(data.cases))
