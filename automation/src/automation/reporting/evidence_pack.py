"""One evidence pack per test case: ``cases/<TC ID>/evidence.html``.

Each item of the case's "Evidence to Capture" (the workbook column, items
separated by ``;``) is checked against what the run actually collected —
screenshots, the HTTP calls with status and correlation id, the app's own
request log, device/OS, app version, timestamp — and marked captured or
missing. Missing is said plainly with what it takes to capture it; nothing is
marked captured that the run did not produce. Screenshots are copied in, so a
case folder can be handed over on its own. Everything read here was masked
when the run wrote it.
"""

import json
import re
import shutil
from dataclasses import dataclass
from html import escape
from pathlib import Path
from typing import Any

from automation.mobile.flutter_runner import parse_events
from automation.reporting.html_report import CSS, chip
from automation.reporting.record import ExecutionRecord


@dataclass(frozen=True)
class Check:
    required: str
    captured: bool
    detail: str


@dataclass
class Collected:
    screenshots: list[Path]
    api_calls: list[dict[str, Any]]
    app_log: list[str]
    tests: list[tuple[str, str]]  # (test name, result)
    device: str
    os: str


def _requirement(item: str, got: Collected, meta: dict[str, Any]) -> Check:
    text = item.lower()
    shots = [p.name for p in got.screenshots]
    if "sync center" in text or "pending sheet" in text:
        return Check(
            item, False, "Not automated: capture on a device before and after reconnecting."
        )
    if "screenshot" in text:
        if "km" in text or "khmer" in text:
            km = [s for s in shots if "km" in s.lower() or "khmer" in s.lower()]
            if not shots:
                return Check(item, False, "No screenshot: this case has no device test yet. "
                                          "Capture EN and KM on a device.")  # fmt: skip
            if not km:
                return Check(
                    item, False, f"EN only ({', '.join(shots)}); Khmer screenshot not captured."
                )
            return Check(item, True, ", ".join(shots))
        if shots:
            return Check(item, True, ", ".join(shots))
        return Check(
            item, False, "No screenshot: this case has no device test yet. Capture on a device."
        )
    if "api." in text or "log line" in text or "correlationid" in text:
        if got.api_calls or got.app_log:
            parts = []
            if got.api_calls:
                parts.append(f"{len(got.api_calls)} HTTP call(s) with status and correlation id")
            if got.app_log:
                parts.append(f"{len(got.app_log)} app log line(s)")
            return Check(item, True, " · ".join(parts))
        return Check(
            item, False, "No live API calls in this case's automated tests (they run on fakes)."
        )
    if "device/os" in text or ("device" in text and "os" in text):
        return Check(item, True, f"{got.device} · {got.os}")
    if "app version" in text:
        version = " @ ".join(p for p in (meta.get("app_version"), meta.get("app_revision")) if p)
        return Check(item, True, version)
    if "timestamp" in text:
        return Check(item, True, meta.get("finished_at", "")[:19].replace("T", " ") + " UTC")
    if "screen name" in text:
        if got.tests:
            return Check(item, True, f"{len(got.tests)} named test(s), listed below")
        return Check(item, False, "No test names recorded.")
    if "mask" in text:
        return Check(item, True, "Tokens, passwords and phone numbers masked in all evidence.")
    return Check(item, False, "Not recognised by the framework — check by hand.")


def requirements(text: str) -> list[str]:
    """Items are separated by ``;`` or by a sentence break."""
    parts = re.split(r";|\.\s+(?=[A-Z])", text or "")
    return [p.strip().rstrip(".") for p in parts if p.strip()]


def _collect(record: ExecutionRecord, result: dict[str, Any], flutter_dir: Path) -> Collected:
    root = record.root
    evidence = result.get("evidence", [])
    refs = [o["ref"] for o in result.get("outcomes", [])]
    on_device = any(r.startswith("drive:") for r in refs)
    device = record.metadata.get("device") or {}
    calls: list[dict[str, Any]] = []
    for path in evidence:
        if path.startswith("api/") and (root / path).is_file():
            calls += json.loads((root / path).read_text(encoding="utf-8"))
    app_log = [
        line.removeprefix("flutter: ").strip()
        for path in evidence
        if path.endswith("drive.stdout.txt") and (root / path).is_file()
        for line in (root / path).read_text(encoding="utf-8").splitlines()
        if "] api." in line
    ]
    tests: list[tuple[str, str]] = []
    events = root / "flutter" / "flutter.events.jsonl"
    if events.is_file():
        with events.open(encoding="utf-8") as handle:
            files = parse_events(handle, flutter_dir)
        for ref in refs:
            if ref.startswith("flutter:"):
                target = ref.split(":", 1)[1].split("::")[0]
                tests += [
                    (t.name, t.result) for t in (files[target].tests if target in files else [])
                ]
    for o in result.get("outcomes", []):
        if not o["ref"].startswith("flutter:"):
            name = o["ref"].split(":", 1)[1]
            tests.append((name, str(o["status"])))
    return Collected(
        screenshots=[root / p for p in evidence if p.endswith(".png") and (root / p).is_file()],
        api_calls=calls,
        app_log=app_log,
        tests=tests,
        device=device.get("name", "") if on_device else "Computer (automated app tests)",
        os=device.get("os", "") if on_device else "n/a",
    )


TEST_RESULT = {"success": "Pass", "failure": "Fail", "error": "Fail"}


def _path(url: str) -> str:
    return url[url.find("/api/") :] if "/api/" in url else url


def _page(result: dict[str, Any], checks: list[Check], got: Collected, run_id: str) -> str:
    missing = sum(1 for c in checks if not c.captured)
    rows = "".join(
        f"<tr><td>{escape(c.required)}</td><td>{chip('Pass' if c.captured else 'Blocked')}</td>"
        f"<td>{escape(c.detail)}</td></tr>"
        for c in checks
    )
    parts = [
        f"<h1>{escape(result['case_id'])} — {escape(result.get('title', ''))}</h1>",
        f"<div class='meta'>Result {chip(str(result['status']))} · run {escape(run_id)} · "
        f"{len(checks) - missing} of {len(checks)} required items captured</div>",
        "<h2>Evidence to Capture</h2><div class='scroll'><table><thead><tr>"
        "<th>Required</th><th>Status</th><th>What was captured</th></tr></thead>"
        f"<tbody>{rows}</tbody></table></div>",
    ]
    if got.screenshots:
        parts.append("<h2>Screenshots</h2>" + "".join(
            f'<a href="{escape(p.name)}"><img class="shot" src="{escape(p.name)}" '
            f'alt="{escape(p.name)}"></a>' for p in got.screenshots
        ))  # fmt: skip
    if got.api_calls:
        body = "".join(
            f"<tr><td>{escape(c.get('method', ''))}</td>"
            f"<td>{escape(_path(c.get('url', '')))}</td>"
            f"<td>{escape(str(c.get('status') or c.get('transport_error', '')))}</td>"
            f"<td>{escape(str(c.get('elapsed_ms', '')))}</td>"
            f"<td>{escape(c.get('error_code', ''))}</td>"
            f"<td><code>{escape(c.get('correlation_id', ''))}</code></td></tr>"
            for c in got.api_calls
        )
        parts.append(
            "<h2>HTTP calls (live backend)</h2><div class='scroll'><table><thead><tr>"
            "<th>Method</th><th>Path</th><th>Status</th><th>ms</th><th>Error code</th>"
            "<th>Correlation id</th>"
            f"</tr></thead><tbody>{body}</tbody></table></div>"
        )
    if got.app_log:
        parts.append(
            "<h2>App request log (device)</h2><pre>" + escape("\n".join(got.app_log)) + "</pre>"
        )
    if got.tests:
        items = "".join(f"<li>{chip(TEST_RESULT.get(r, r))} {escape(n)}</li>" for n, r in got.tests)
        parts.append(f"<h2>Tests run for this case</h2><ul>{items}</ul>")
    return (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>Evidence {escape(result['case_id'])}</title><style>{CSS}</style></head>"
        f"<body><main>{''.join(parts)}</main></body></html>"
    )


def build_evidence_packs(
    record: ExecutionRecord, required: dict[str, str], flutter_dir: Path
) -> dict[str, tuple[int, int]]:
    """Writes ``cases/<id>/evidence.html`` for every case that ran; returns
    case id → (captured, required) counts."""
    counts: dict[str, tuple[int, int]] = {}
    for result in record.results:
        if str(result["status"]) == "Not Run":
            continue
        folder = record.root / "cases" / result["case_id"]
        folder.mkdir(parents=True, exist_ok=True)
        got = _collect(record, result, flutter_dir)
        copied = []
        for shot in got.screenshots:
            target = folder / shot.name
            shutil.copy2(shot, target)
            copied.append(target)
        got.screenshots = copied
        checks = [
            _requirement(i, got, record.metadata)
            for i in requirements(required.get(result["case_id"], ""))
        ]
        (folder / "evidence.html").write_text(
            _page(result, checks, got, record.execution_id), encoding="utf-8"
        )
        summary = {
            "captured": sum(c.captured for c in checks),
            "required": len(checks),
            "missing": [c.required for c in checks if not c.captured],
        }
        (folder / "evidence.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        counts[result["case_id"]] = (summary["captured"], summary["required"])
    return counts


def evidence_note(root: Path, case_id: str) -> str:
    """``Evidence to Capture: 2 of 4 captured; missing: …`` for the workbook."""
    path = root / "cases" / case_id / "evidence.json"
    if not path.is_file():
        return ""
    data = json.loads(path.read_text(encoding="utf-8"))
    if not data["required"]:
        return ""
    note = f"Evidence to Capture: {data['captured']} of {data['required']} captured"
    return note + (f"; missing: {'; '.join(data['missing'])}." if data["missing"] else ".")
