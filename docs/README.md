# ISI Steel Sales Mobile — Documentation

> Guest-first, offline-first enterprise CRM for a field sales force. Flutter ·
> Android · iOS · Web.
> **Last reorganised:** 2026-08-27 · **Verified against:** Flutter 3.44.9,
> branch `web`, commit `142de9b`.

---

## Start here

| You are… | Read this |
|---|---|
| An engineer making your first change | [skills/engineering-standard.md](skills/engineering-standard.md) → [skills/ai-engineering-playbook.md](skills/ai-engineering-playbook.md) |
| Building or changing **any** UI | [skills/feature-ui-standard.md](skills/feature-ui-standard.md) — this is a merge gate, not advice |
| An AI coding agent orienting in the repo | [blueprint/feature-architecture.md](blueprint/feature-architecture.md), then the feature's own `README.md` |
| Working on one feature | [feature/](feature/) — pick the feature, read its `README.md` first |
| Touching persistence, sync, or crypto | [blueprint/local-storage-architecture.md](blueprint/local-storage-architecture.md) + [blueprint/sync-architecture.md](blueprint/sync-architecture.md) + [skills/security.md](skills/security.md), in full |
| Asking "why is it built this way?" | [adr/](adr/) |
| Shipping a build | [release/](release/) |

---

## The six directories

```
docs/
├── skills/       HOW to build — reusable engineering knowledge, not app-specific
├── blueprint/    WHAT exists — this app's system architecture and roadmaps
├── feature/      HOW ONE FEATURE works — per-feature implementation reference
├── requirement/  WHAT the app must do — business/functional requirements
├── adr/          WHY — architecture decision records
└── release/      HOW IT SHIPS — build, environment, CI/CD, distribution
```

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

- **File names**: lowercase `kebab-case.md`. Never `final.md`, `new.md`, `v2.md`.
- **ADRs**: `ADR-000N-short-decision-name.md`, never renumbered once accepted.
- **Feature directory names** match the `lib/features/` folder they document,
  hyphenated: `lib/features/my_visits` → `docs/feature/my-visits/`.
- **Every feature directory has a `README.md`** as its entry point.
- **Cross-references** are relative markdown links. Backticked paths are
  repo-relative (`docs/skills/security.md`), so they stay valid when quoted.
- **`⧉ backend repo`** marks a document that lives in the ISI API repository,
  not here. Those are not broken links; they are deliberately not vendored.
- **No secrets, tokens, keys, or certificates** appear anywhere in `docs/`.

---

## Feature documentation coverage

| Feature | `lib/features/` | Docs | Requirements |
|---|---|---|---|
| Authentication | `authentication` | [full package](feature/authentication/) (15 docs) | ✗ |
| Depot | `depots` | [api, ui-ux, registration](feature/depot/) | ✗ |
| My Visits (routes) | `my_visits` | [architecture, workflow, api](feature/my-visits/) | ✗ |
| Order / Quotation | `order` | [workflow, product-selection](feature/order/) | ✗ |
| Notification | `notification` | [integration guide](feature/notification/) | ✗ |
| App Coach | `app_coach` | [README](feature/app-coach/) | ✗ |
| Shell | `shell` | [ui-upgrade-plan](feature/shell/) | ✗ |
| Localization | `localization` | [skills/localization.md](skills/localization.md) + [analysis](feature/localization/) | ✗ |
| Geo location | `geo_location` | **none** | ✗ |
| Home / KPI | `home`, `shell` | **none** | ✗ |
| Profile | `profile` | **none** | ✗ |
| Onboarding / Splash | `onboarding`, `splash` | in [blueprint/authentication-architecture.md](blueprint/authentication-architecture.md#boot--navigation-flow) | ✗ |
| Settings / Theme | `settings` | **none** | ✗ |
| About | `about` | **none** | ✗ |

No `requirement/` documents exist yet for any feature — see
[requirement/README.md](requirement/README.md) for what that costs and where
business rules currently live instead.

---

## Related, outside `docs/`

| Path | What it is |
|---|---|
| [../README.md](../README.md) | Repository front page — setup, run, project tour |
| [../.claude/CLAUDE.md](../.claude/CLAUDE.md) | Session router loaded into every AI agent session |
| [../.claude/rules/](../.claude/rules/) | Agent behaviour rules — they point back into `docs/`, never restate it |
| [../.claude/agents/](../.claude/agents/) | Subagents: flutter-developer, ui-ux-reviewer, api-integrator, code-reviewer |
| [../.claude/commands/](../.claude/commands/) | Slash commands: `/feature` `/screen` `/api` `/debug` `/test` `/review` |
| `graphify-out/` | Queryable knowledge graph of `lib/` — see [skills/graphify.md](skills/graphify.md) |
| `.env.example` | Config template. `.env` itself is never committed |
