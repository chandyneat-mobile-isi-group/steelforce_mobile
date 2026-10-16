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
| [code-quality-standard.md](code-quality-standard.md) | Writing or reviewing any code: file/class/function size, one responsibility, comments, magic values, dead code, refactoring process and priority. Its §10 checklist extends the PR review. |
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

## Vendored agent skills (not project standards)

These carry Claude skill frontmatter and were copied in from elsewhere. They are
**reference material, not rules for this repo**, and they do not participate in
the authority precedence above.

| File | What it is | Note |
|---|---|---|
| `SKILL (3).md` | `mobile-app-ui-design` skill | Generic mobile UI guidance. Where it conflicts with [feature-ui-standard.md](feature-ui-standard.md), that document wins. Filename does not follow the `kebab-case.md` convention in [../README.md](../README.md#conventions). |
| `QA-tester/Code-quality-skill.md` | `code-quality` skill | Generic 25-point review checklist. This repo's rules are [code-quality-standard.md](code-quality-standard.md) and the review checklist in [ai-engineering-playbook.md](ai-engineering-playbook.md) §7. |
| `motion-framer.md` | `motion-framer` skill | **Documents a React/JavaScript animation library.** It does not apply to this Flutter codebase; for motion rules see [feature-ui-standard.md](feature-ui-standard.md) §6. |

---

## Conventions

- Lowercase `kebab-case.md`. Never `final.md`, `new.md`, `v2.md`.
- One subject, one home. If two documents cover the same ground, the more
  specific one is authoritative and the other links to it.
- No secrets, tokens, keys, or certificates anywhere in `docs/`.
