# Skills — reusable engineering knowledge

> **Purpose:** *how* to build, independent of any one feature. Cross-cutting
> rules, standards, and checklists that apply everywhere in this repo.
> **Not here:** this app's architecture ([../blueprint/](../blueprint/)),
> per-feature reference ([../feature/](../feature/)), or decisions
> ([../adr/](../adr/)).

Agent behaviour rules live in [`.claude/rules/`](../../.claude/rules/) and point
back here. Where a rule there and a document here disagree, **this directory
wins** — see [`.claude/CLAUDE.md`](../../.claude/CLAUDE.md) §6.

---

## Start here

| Document | Read it when |
|---|---|
| [engineering-standard.md](engineering-standard.md) | **First.** The master rules: the one coding rule that overrides everything (§2), architecture baseline, state management, DI, testing gates, release discipline. |
| [ai-engineering-playbook.md](ai-engineering-playbook.md) | Day-to-day operational manual: conventions, naming, folder ownership, feature/PR/review checklists, anti-patterns, and a full worked example of correct layering (§13). |
| [feature-ui-standard.md](feature-ui-standard.md) | **Merge gate** for any feature, screen, or UI upgrade. Security, stability, performance, responsive, motion, visual language, calm UX, localization, accessibility, longevity. Its §14 checklist goes in the PR. |

---

## By subject

| Document | Scope |
|---|---|
| [security.md](security.md) | Security standards, OWASP/MASVS mapping, storage and logging rules, release checklist. Read §2 and §4 in full before touching crypto or key management. |
| [api-integration.md](api-integration.md) | Implementation notes verified against the running API — blockers, compromises, debug logging, running against mocks. |
| [localization.md](localization.md) | English + Khmer: architecture, key naming, adding a string, adding a language, bilingual master data. |
| [responsive-and-adaptive-ui.md](responsive-and-adaptive-ui.md) | Breakpoint strategy, layout modes, navigation adaptation, grids, typography, forms, tables, dialogs. Long; read the sections you need. |
| [graphify.md](graphify.md) | The codebase knowledge graph: setup, queries, blast-radius analysis, known limitations. |
| [feature-documentation-template.md](feature-documentation-template.md) | Fill-in template for producing a feature documentation package under [../feature/](../feature/). |

---

## Removed vendored skills

Generic Claude skills that had been copied in (`mobile-app-ui-design`,
`code-quality`, `motion-framer`) and a generic real-time research report were
removed on 2026-10-24. They are installed as agent skills where needed, and they
did not describe this Flutter codebase. They are in git history.

---

## Conventions

See [../CONTRIBUTING-DOCS.md](../CONTRIBUTING-DOCS.md) for naming, placement
and how to retire a document.
