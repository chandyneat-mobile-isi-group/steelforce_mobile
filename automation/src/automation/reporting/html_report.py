"""``report.html`` for one execution: self-contained, opens from the folder.

Every value is HTML-escaped (test output is untrusted text). Links and
screenshots are relative to the execution folder, so the folder can be zipped
and shared as is. Content was masked when the run wrote it.
"""

from html import escape
from pathlib import Path
from typing import Any

from automation.reporting.record import ExecutionRecord

STATUS_CLASS = {"Pass": "pass", "Fail": "fail", "Blocked": "blocked", "Skipped": "skip"}
FACT_LABELS = {
    "http_status": "HTTP status",
    "endpoint": "Endpoint",
    "error_code": "Error code",
    "correlation_id": "Correlation id",
    "server_trace_id": "Server trace id",
    "retry_after": "Retry-After",
    "api_calls": "API calls in test",
}

CSS = """
:root{--bg:#f6f7f9;--card:#fff;--ink:#1c2430;--muted:#5d6b7c;--line:#dde2e8;
--pass:#1f7a4d;--pass-bg:#e3f4ea;--fail:#b42318;--fail-bg:#fde8e7;--blocked:#8a5a00;
--blocked-bg:#fff3d6;--skip:#4b5565;--skip-bg:#eceff3}
@media (prefers-color-scheme:dark){:root{--bg:#11161d;--card:#1a212b;--ink:#e6ebf1;
--muted:#9aa7b6;--line:#2c3644;--pass:#5fd39a;--pass-bg:#173326;--fail:#ff8b80;
--fail-bg:#3a1c1b;--blocked:#ffc657;--blocked-bg:#3a2e12;--skip:#b4bfcc;--skip-bg:#262e39}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--ink);
font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
main{max-width:1100px;margin:0 auto;padding:24px 16px 64px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:16px;margin:32px 0 12px}
.meta{color:var(--muted)}.tiles{display:grid;gap:12px;
grid-template-columns:repeat(auto-fit,minmax(130px,1fr));margin-top:20px}
.tile,.card{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:12px 14px}
.tile b{display:block;font-size:22px}.tile span{color:var(--muted);font-size:12px}
.chip{display:inline-block;padding:1px 8px;border-radius:10px;font-size:12px;font-weight:600}
.pass{color:var(--pass);background:var(--pass-bg)}.fail{color:var(--fail);background:var(--fail-bg)}
.blocked{color:var(--blocked);background:var(--blocked-bg)}.skip{color:var(--skip);background:var(--skip-bg)}
.card{margin-bottom:12px}.card h3{margin:0 0 6px;font-size:15px}
dl{display:grid;grid-template-columns:max-content 1fr;gap:2px 12px;margin:8px 0}
dt{color:var(--muted)}dd{margin:0;word-break:break-word}
pre{background:var(--bg);border:1px solid var(--line);border-radius:6px;padding:8px;
overflow-x:auto;white-space:pre-wrap;font-size:12px;max-height:240px}
table{width:100%;border-collapse:collapse;background:var(--card);border:1px solid var(--line);
border-radius:8px;overflow:hidden}th,td{text-align:left;padding:8px 10px;
border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:600}
.scroll{overflow-x:auto}a{color:inherit}img.shot{max-width:220px;border:1px solid var(--line);
border-radius:6px;margin:6px 6px 0 0}ul{margin:4px 0;padding-left:20px}
"""


def chip(status: str) -> str:
    return f'<span class="chip {STATUS_CLASS.get(status, "skip")}">{escape(status)}</span>'


def _evidence_links(paths: list[str]) -> str:
    links = []
    for path in paths:
        if path.endswith(".png"):
            links.append(f'<a href="{escape(path)}"><img class="shot" src="{escape(path)}" '
                         f'alt="{escape(Path(path).name)}"></a>')  # fmt: skip
        else:
            links.append(f'<a href="{escape(path)}">{escape(path)}</a>')
    return "<br>".join(links)


def _diagnosis(d: dict[str, Any]) -> str:
    facts = d.get("facts") or {}
    rows = [
        ("Issue source", f"{d['source']} ({d['confidence']} confidence)"),
        ("Issue type", d.get("issue_type", "")),
        ("Team", d.get("team", "")),
        *((FACT_LABELS.get(k, k), v) for k, v in facts.items()),
    ]
    html = "<dl>" + "".join(f"<dt>{escape(k)}</dt><dd>{escape(str(v))}</dd>" for k, v in rows)
    html += "</dl>" + f"<p>{escape(d.get('reasoning', ''))}</p>"
    needed = d.get("missing_evidence") or []
    if needed:
        html += (
            "<p><b>To confirm:</b></p><ul>"
            + "".join(f"<li>{escape(m)}</li>" for m in needed)
            + "</ul>"
        )
    return html


def _case_card(r: dict[str, Any]) -> str:
    status = str(r["status"])
    parts = [f"<h3>{chip(status)} {escape(r['case_id'])} — {escape(r.get('title', ''))}</h3>"]
    if r.get("diagnosis"):
        parts.append(_diagnosis(r["diagnosis"]))
    for o in r.get("outcomes", []):
        if str(o["status"]) == "Pass":
            continue
        parts.append(f"<p>{chip(str(o['status']))} <code>{escape(o['ref'])}</code> "
                     f"{escape(o.get('note', ''))}</p>")  # fmt: skip
        for f in o.get("failures", [])[:5]:
            parts.append(f"<p>✗ {escape(f['test_name'])}</p><pre>{escape(f['message'])}</pre>")
    if r.get("notes"):
        parts.append(f"<p class='meta'>{escape(r['notes'])}</p>")
    if r.get("evidence"):
        parts.append(f"<p><b>Evidence</b><br>{_evidence_links(r['evidence'])}</p>")
    return f'<div class="card">{"".join(parts)}</div>'


def _tiles(meta: dict[str, Any]) -> str:
    totals = meta.get("totals", {})
    rate = totals.get("pass_rate")
    tiles = [("Pass rate", "n/a" if rate is None else f"{rate}%")]
    tiles += [(k, v) for k, v in totals.get("by_status", {}).items() if v]
    tiles.append(("Critical failures", totals.get("critical_failures", 0)))
    return (
        '<div class="tiles">'
        + "".join(
            f"<div class='tile'><b>{escape(str(v))}</b><span>{escape(k)}</span></div>"
            for k, v in tiles
        )
        + "</div>"
    )


def _changes(changes: list[dict[str, Any]]) -> str:
    if not changes:
        return ""
    items = "".join(
        f"<li>{chip('Fail' if c['kind'] == 'regression' else 'Pass')} "
        f"<b>{escape(c['case_id'])}</b> {escape(c['kind'])}: {escape(c['previous_status'])} in "
        f"{escape(c['previous_execution'])} → {escape(c['status'])}</li>"
        for c in changes
    )
    return f"<h2>Changes since the last run</h2><div class='card'><ul>{items}</ul></div>"


def _case_link(root: Path, case_id: str) -> str:
    pack = root / "cases" / case_id / "evidence.html"
    if not pack.is_file():
        return escape(case_id)
    return f'<a href="cases/{escape(case_id)}/evidence.html">{escape(case_id)}</a>'


def _table(results: list[dict[str, Any]], root: Path) -> str:
    rows = "".join(
        f"<tr><td>{_case_link(root, r['case_id'])}</td><td>{escape(r.get('title', ''))}</td>"
        f"<td>{escape(r.get('priority', ''))}</td><td>{chip(str(r['status']))}</td>"
        f"<td>{escape((r.get('diagnosis') or {}).get('source', ''))}</td>"
        f"<td>{escape(r.get('notes', ''))}</td></tr>"
        for r in results
    )
    return ("<div class='scroll'><table><thead><tr><th>Case</th><th>Title</th><th>Priority</th>"
            f"<th>Result</th><th>Issue source</th><th>Notes</th></tr></thead><tbody>{rows}"
            "</tbody></table></div>")  # fmt: skip


def build_html_report(record: ExecutionRecord) -> Path:
    meta = record.metadata
    attention = [r for r in record.results if str(r["status"]) in ("Fail", "Blocked")]
    app = " @ ".join(p for p in (meta.get("app_version"), meta.get("app_revision")) if p)
    device = (meta.get("device") or {}).get("name", "")
    subtitle = " · ".join(
        p for p in (meta.get("project", ""), meta.get("environment", ""), app, device,
                    meta.get("finished_at", "")[:19].replace("T", " ")) if p
    )  # fmt: skip
    body = [
        f"<h1>Execution {escape(record.execution_id)}</h1>",
        f"<div class='meta'>{escape(subtitle)}</div>",
        _tiles(meta),
        _changes(meta.get("changes", [])),
    ]
    if attention:
        body.append("<h2>Needs attention</h2>" + "".join(_case_card(r) for r in attention))
    body.append(
        "<h2>All cases</h2><p class='meta'>A case id opens its evidence pack.</p>"
        + _table(record.results, record.root)
    )
    html = (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>Test Execution {escape(record.execution_id)}</title><style>{CSS}</style>"
        f"</head><body><main>{''.join(body)}</main></body></html>"
    )
    target = record.root / "report.html"
    target.write_text(html, encoding="utf-8")
    return target
