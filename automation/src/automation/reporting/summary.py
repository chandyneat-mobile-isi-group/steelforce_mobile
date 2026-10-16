"""Totals and the console summary for one execution."""

from collections import Counter
from dataclasses import dataclass

from automation.core.constants import IssueSource, ResultStatus
from automation.execution.results import CaseResult


@dataclass(frozen=True)
class Totals:
    total: int
    by_status: dict[str, int]
    by_source: dict[str, int]
    critical_failures: int

    @property
    def executed(self) -> int:
        """Cases that produced a verdict (pass or fail)."""
        return self.by_status.get(ResultStatus.PASS, 0) + self.by_status.get(ResultStatus.FAIL, 0)

    @property
    def pass_rate(self) -> float | None:
        """Pass rate over executed cases; None when nothing executed."""
        if not self.executed:
            return None
        return round(100 * self.by_status.get(ResultStatus.PASS, 0) / self.executed, 1)


def totals(results: list[CaseResult], critical_priority: str = "P1") -> Totals:
    by_status = Counter(r.status.value for r in results)
    failures = [r for r in results if r.status is ResultStatus.FAIL]
    by_source = Counter(
        (r.diagnosis.source if r.diagnosis else IssueSource.UNKNOWN).value for r in failures
    )
    return Totals(
        total=len(results),
        by_status={s.value: by_status.get(s.value, 0) for s in ResultStatus},
        by_source=dict(by_source),
        critical_failures=sum(1 for r in failures if r.priority == critical_priority),
    )


def render(execution_id: str, results: list[CaseResult], seconds: dict[str, float]) -> str:
    t = totals(results)
    rate = "n/a" if t.pass_rate is None else f"{t.pass_rate}% of {t.executed} executed"
    lines = [
        "",
        f"Execution {execution_id}",
        f"  Total {t.total}  |  " + "  ".join(f"{k} {v}" for k, v in t.by_status.items() if v),
        f"  Pass rate {rate}  |  Critical (P1) failures {t.critical_failures}",
    ]
    if seconds:
        lines.append("  Run time " + ", ".join(f"{k} {v}s" for k, v in seconds.items()))
    if t.by_source:
        lines.append(
            "  Failures by source: " + ", ".join(f"{k} {v}" for k, v in t.by_source.items())
        )
    for r in results:
        if r.status is ResultStatus.SKIPPED or (
            r.status is ResultStatus.PASS and "Not run:" in r.notes
        ):
            lines.append(f"\n  {r.status.value.upper()} {r.case_id} — {r.title}\n    {r.notes}")
        if r.status in (ResultStatus.FAIL, ResultStatus.BLOCKED):
            lines.append(f"\n  {r.status.value.upper()} {r.case_id} — {r.title}")
            for o in r.outcomes:
                if o.status is not ResultStatus.PASS:
                    lines.append(f"    {o.ref}: {o.status.value} {o.note}".rstrip())
                    lines += [f"      ✗ {f.test_name}" for f in o.failures[:5]]
            if r.diagnosis:
                d = r.diagnosis
                lines.append(
                    f"    Issue Source: {d.source.value} ({d.confidence.value})  Team: {d.team}"
                )
                lines.append(f"    {d.reasoning}")
                lines += [f"    Needed: {m}" for m in d.missing_evidence]
    return "\n".join(lines)
