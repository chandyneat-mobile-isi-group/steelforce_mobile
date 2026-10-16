"""Checks test cases before anything runs.

A case with an ERROR is never executed; a WARNING is reported and the case
still runs. Allowed values come from the workbook's Dropdowns sheet (through
``project.yaml``), so the rules follow the workbook rather than this code.
"""

import re
from collections import Counter
from collections.abc import Iterable, Mapping
from pathlib import Path

from automation.excel.models import Runner, Severity, TestCase, ValidationIssue

AUTOMATED_STATUSES = frozenset({"automated", "partial"})
MANUAL_STATUSES = frozenset({"planned", "manual only"})

_LABELS = {
    "priority": "Priority",
    "test_type": "Test Type",
    "automation_status": "Automation Status",
    "automation_level": "Automation Level",
}


def _error(case: TestCase, message: str, column: str = "") -> ValidationIssue:
    return ValidationIssue(Severity.ERROR, message, case.id, case.row, column)


def _warning(case: TestCase, message: str, column: str = "") -> ValidationIssue:
    return ValidationIssue(Severity.WARNING, message, case.id, case.row, column)


class Validator:
    def __init__(
        self,
        allowed_values: Mapping[str, list[str]],
        id_pattern: str,
        environments: Iterable[str],
        ref_roots: Mapping[Runner, Path],
    ) -> None:
        self._allowed = {k: {v.lower(): v for v in vals} for k, vals in allowed_values.items()}
        self._id_pattern = re.compile(id_pattern)
        self._environments = {e.lower() for e in environments}
        self._ref_roots = ref_roots

    def validate(self, cases: list[TestCase]) -> list[ValidationIssue]:
        issues = self._duplicates(cases)
        for case in cases:
            issues.extend(self._check(case))
        return issues

    def _duplicates(self, cases: list[TestCase]) -> list[ValidationIssue]:
        counts = Counter(c.id for c in cases if c.id)
        return [
            _error(c, f"Duplicate Test Case ID (appears {counts[c.id]} times).", "TC ID")
            for c in cases
            if counts.get(c.id, 0) > 1
        ]

    def _check(self, case: TestCase) -> list[ValidationIssue]:
        issues: list[ValidationIssue] = []
        if not case.id:
            return [_error(case, "Test Case ID is empty.", "TC ID")]
        if not self._id_pattern.match(case.id):
            issues.append(_error(case, f"Test Case ID does not match {self._id_pattern.pattern}."))
        for field_name, label in (("expected_result", "Expected Result"), ("steps", "Steps")):
            if not getattr(case, field_name):
                issues.append(_error(case, f"{label} is empty.", label))
        issues.extend(self._allowed_value_issues(case))
        issues.extend(self._suite_and_environment_issues(case))
        issues.extend(self._automation_issues(case))
        return issues

    def _allowed_value_issues(self, case: TestCase) -> list[ValidationIssue]:
        issues = []
        for field_name, label in _LABELS.items():
            allowed = self._allowed.get(field_name)
            value = getattr(case, field_name)
            if allowed is None or (not value and field_name == "automation_level"):
                continue
            if value.lower() not in allowed:
                issues.append(
                    _error(
                        case,
                        f"Invalid {label}: {value!r} (allowed: {list(allowed.values())}).",
                        label,
                    )
                )
        return issues

    def _suite_and_environment_issues(self, case: TestCase) -> list[ValidationIssue]:
        issues = []
        allowed_suites = self._allowed.get("suites")
        if allowed_suites is not None:
            issues += [
                _error(
                    case,
                    f"Unknown suite {s!r} (allowed: {list(allowed_suites.values())}).",
                    "Suites",
                )
                for s in case.suites
                if s not in allowed_suites
            ]
        issues += [
            _error(
                case,
                f"Unknown environment {e!r} (have: {sorted(self._environments)}).",
                "Environments",
            )
            for e in case.environments
            if e not in self._environments
        ]
        return issues

    def _automation_issues(self, case: TestCase) -> list[ValidationIssue]:
        status = case.automation_status.lower()
        if status in AUTOMATED_STATUSES and not case.automated_refs:
            return [
                _error(
                    case,
                    f"Automation Status is {case.automation_status!r} "
                    "but no Automation ID is mapped.",
                    "Automation ID",
                )
            ]
        issues = []
        if status in MANUAL_STATUSES and case.automated_refs:
            issues.append(
                _warning(
                    case,
                    f"Automation Status is {case.automation_status!r} "
                    "but an automated test is mapped; update the status.",
                    "Automation Status",
                )
            )
        for ref in case.automated_refs:
            root = self._ref_roots.get(ref.runner)
            if root is not None and not (root / ref.target).is_file():
                issues.append(
                    _error(case, f"Automation ID {ref} points at a missing file.", "Automation ID")
                )
        return issues


def invalid_case_ids(issues: Iterable[ValidationIssue]) -> set[str]:
    return {i.case_id for i in issues if i.severity is Severity.ERROR and i.case_id}
