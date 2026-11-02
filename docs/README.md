# ISI Steel Sales Mobile — Documentation

> Guest-first, offline-first enterprise CRM for a field sales force. Flutter ·
> Android · iOS · Web.
> **Last reorganised:** 2026-10-24 (duplicates removed, backend copies marked,
> order sub-areas consolidated) · branch `feat/auth`.
>
> **Adding or changing a document?** Read [CONTRIBUTING-DOCS.md](CONTRIBUTING-DOCS.md)
> and run `dart run tool/check_docs.dart` before committing.

---

## Start here

| You are… | Read this |
|---|---|
| An engineer making your first change | [skills/engineering-standard.md](skills/engineering-standard.md) → [skills/ai-engineering-playbook.md](skills/ai-engineering-playbook.md) |
| Building or changing **any** UI | [skills/feature-ui-standard.md](skills/feature-ui-standard.md) — this is a merge gate, not advice |
| An AI coding agent orienting in the repo | [blueprint/feature-architecture.md](blueprint/feature-architecture.md), then the feature's own `README.md` |
| Working on one feature | [feature/](feature/) — pick the feature, read its `README.md` first |
| Asking "how is the app protected today, and what is missing?" | [security/README.md](security/README.md) — current security posture and remaining work |
| Touching persistence, sync, or crypto | [blueprint/local-storage-architecture.md](blueprint/local-storage-architecture.md) + [blueprint/sync-architecture.md](blueprint/sync-architecture.md) + [skills/security.md](skills/security.md), in full |
| Asking "why is it built this way?" | [adr/](adr/) |
| Shipping a build | [release/](release/) |
| Adding, moving or deleting a document | [CONTRIBUTING-DOCS.md](CONTRIBUTING-DOCS.md) — where it goes, naming, how to retire one |

---

## The six directories

```
docs/
├── README.md              ← you are here: the map
├── CONTRIBUTING-DOCS.md   ← the rules for keeping this tree clean
├── skills/       HOW to build — reusable engineering knowledge, not app-specific
├── blueprint/    WHAT exists — this app's system architecture and roadmap
├── feature/      HOW ONE FEATURE works — per-feature implementation reference
├── requirement/  WHAT the app must do — business/functional requirements
├── adr/          WHY — architecture decision records
├── release/      HOW IT SHIPS — build, environment, CI/CD, distribution
├── security/     HOW THE APP IS PROTECTED — current posture, plain-language guide
└── style-rule/   The brand guide (PDF)
```

Security: [security/README.md](security/README.md) (current posture and
remaining work) and [security/explained.md](security/explained.md)
(plain-language guide). The engineering rules every change follows are
[skills/security.md](skills/security.md).

Each directory has a `README.md` that indexes and scopes it. One subject has one
home: if two documents seem to cover the same ground, the more specific one is
authoritative and the other must link to it rather than restate it.

---

## Authority precedence

When two documents disagree, the higher row wins:

| # | Source | Scope |
|---|---|---|
| 1 | [skills/engineering-standard.md](skills/engineering-standard.md) | Master engineering rules |
| 2 | [adr/](adr/) | Locked technical decisions |
| 3 | [skills/ai-engineering-playbook.md](skills/ai-engineering-playbook.md) | Operational checklists |
| 4 | `blueprint/*` | Target system architecture |
| 5 | `feature/*` | Per-feature implementation reference |
| 6 | `.claude/CLAUDE.md` + `.claude/rules/` | Agent behaviour — session router and rules |

**The source code overrides all of them for what the app *currently does*.**
These documents describe intent and target state; where they diverge from `lib/`,
the divergence is a finding to report, not a licence to rewrite either side.
Known divergences are listed in [blueprint/README.md](blueprint/README.md#known-documentation--code-divergences).

---

## Conventions

All naming, placement and lifecycle rules are in
[CONTRIBUTING-DOCS.md](CONTRIBUTING-DOCS.md). The two that matter most:

- **One topic, one home.** Edit the existing document; never create a "v2".
- **`⧉ backend repo`** marks a document that lives in the ISI API repository,
  not here. It is plain text on purpose: a copy goes stale, a link would break.

---

## Feature documentation coverage

The one index of features and their docs is [feature/README.md](feature/README.md#index).
Business requirements exist only for promotions so far — see
[requirement/README.md](requirement/README.md).

---

## Related, outside `docs/`

| Path | What it is |
|---|---|
| [../README.md](../README.md) | Repository front page — setup, run, project tour |
| [../.claude/CLAUDE.md](../.claude/CLAUDE.md) | Session router loaded into every AI agent session |
| [../.claude/rules/](../.claude/rules/) | Agent behaviour rules — they point back into `docs/`, never restate it |
| [../.claude/agents/](../.claude/agents/) | Subagents: flutter-developer, ui-ux-reviewer, api-integrator, code-reviewer |
| [../tool/check_docs.dart](../tool/check_docs.dart) | Docs checker: broken links, naming, duplicates, junk files |
| [../.claude/commands/](../.claude/commands/) | Slash commands: `/feature` `/screen` `/api` `/debug` `/test` `/review` |
| `graphify-out/` | Queryable knowledge graph of `lib/` — see [skills/graphify.md](skills/graphify.md) |
| `.env.example` | Config template. `.env` itself is never committed |
