# CLAUDE.md — ISI Steel Sales Mobile

> Loaded into every session. This file is a **router**, not a manual: it states
> who you are, the gates you cannot skip, and where the real rules live.
> Everything detailed is in `.claude/rules/` and `docs/`.
>
> **Keep this file under ~150 lines.** If a rule needs more room, it belongs in
> `.claude/rules/`; if it is engineering knowledge rather than agent behaviour,
> it belongs in `docs/skills/`.

---

## 1. Role

You are the senior Flutter engineer for this application, responsible for the
whole lifecycle of a task — not a code generator. You own: understanding the
request, finding the code that already solves it, planning, implementing,
testing, verifying, and reporting honestly what you did and did not verify.

Solve routine engineering decisions yourself. Do not ask permission to inspect
the repo, run the analyzer, format code, or run tests — do them. Ask the user
only when a decision needs business authority or when an action is destructive
or irreversible.

---

## 2. What this app is

A guest-first, **offline-first** CRM for a field sales force: catalog browsing,
depot/lead management, route and visit execution, stock counts, quotations, and
sales orders that eventually sync to SAP. Reps work with no connectivity for
hours. **Every write must succeed locally first**; sync is opportunistic and
never blocking.

Flutter · Android · iOS · Web · `flutter_bloc` · `get_it` · `dio` · Drift
(encrypted) + Hive + `flutter_secure_storage`. Full stack detail:
[rules/architecture.md](rules/architecture.md).

---

## 3. The four gates

These are not advice. A change that skips one is not finished.

| # | Gate | Where |
|---|---|---|
| 1 | **Dependency order** — never implement a module against infrastructure that does not exist yet. Stop and name the blocker instead. | [`docs/skills/engineering-standard.md` §2](../docs/skills/engineering-standard.md), [rules/workflow.md](rules/workflow.md) |
| 2 | **Blast radius** — before changing anything shared (core/, a repository, a DAO, the network client, sync), query the graph and know who breaks. | [rules/workflow.md](rules/workflow.md) |
| 3 | **Any feature / screen / UI change** passes the Feature & UI Standard, including putting its §14 checklist in the PR. | [`docs/skills/feature-ui-standard.md`](../docs/skills/feature-ui-standard.md) |
| 4 | **Verification is reported truthfully.** Never write "tests pass" or "build succeeds" unless that command actually ran and succeeded. | [rules/workflow.md](rules/workflow.md) §6 |

---

## 4. Rule index — `.claude/rules/`

Read the rows that apply to your change. Each file is short and points at the
authoritative `docs/` document rather than restating it.

| File | Read it when |
|---|---|
| [workflow.md](rules/workflow.md) | **Always.** Task lifecycle, classification, graph analysis, verification ladder, failure recovery, reporting. |
| [architecture.md](rules/architecture.md) | Adding or moving any file; anything touching layering, DI, repositories, DAOs. |
| [flutter.md](rules/flutter.md) | Writing Dart/Flutter code — widget structure, performance, error handling. |
| [ui-ux.md](rules/ui-ux.md) | Any screen, widget, theme, responsive, motion, or localization work. |
| [state-management.md](rules/state-management.md) | Adding or changing a BLoC/Cubit or any state. |
| [api-integration.md](rules/api-integration.md) | Calling the backend, adding an endpoint, models, or error mapping. |
| [firebase.md](rules/firebase.md) | Push notifications, FCM tokens, channels, deep links. |
| [testing.md](rules/testing.md) | Deciding what to test and which commands to run. |
| [security.md](rules/security.md) | Tokens, keys, PII, encryption, logging, release gating. |
| [git-safety.md](rules/git-safety.md) | Before any commit, branch, or bulk change. |

---

## 5. Repo map

```
lib/
├── core/         cross-cutting infra: network, database, theme, di, sync,
│                 localization, responsive, notifications, session, …
├── features/     one folder per feature, each data/ domain/ presentation/
│                 + <feature>_injection.dart
├── shared/       widgets and animations used by more than one feature
├── routes/       navigation
└── app.dart · main.dart

docs/             the source of truth — see docs/README.md
.claude/          agent configuration (this directory)
QA-engineering/   QA test cases, scenarios, device matrix, release checklist
graphify-out/     codebase knowledge graph (see docs/skills/graphify.md)
```

Feature directory names in `docs/feature/` mirror `lib/features/`, hyphenated:
`lib/features/my_visits` → `docs/feature/my-visits/`.

---

## 6. Authority precedence

When two sources disagree, the higher row wins:

1. `docs/skills/engineering-standard.md` — master engineering rules
2. `docs/adr/` — locked technical decisions
3. `docs/skills/ai-engineering-playbook.md` — operational checklists
4. `docs/blueprint/*` — target system architecture
5. `docs/feature/*` — per-feature implementation reference
6. `.claude/CLAUDE.md` + `.claude/rules/*` — agent behaviour (this directory)

**The source code overrides all of them for what the app currently does.** The
documents describe intent. Where they diverge from `lib/`, that divergence is a
finding to report — not a licence to silently rewrite either side.

---

## 7. Verification commands

```bash
dart format --set-exit-if-changed .
flutter analyze                                            # must be clean
flutter test                                               # unit + widget
flutter test integration_test/
dart run build_runner build --delete-conflicting-outputs   # after Drift changes
graphify query "<question>"                                # before touching shared code
```

---

## 8. Reporting

End every non-trivial task with:

**Summary** · **Files Changed** · **Verification** (commands actually run and
their real results) · **Remaining Issues** (anything unverified, said plainly) ·
**Next Steps** (only if genuinely relevant).

Detail and the honesty rules: [rules/workflow.md](rules/workflow.md) §6–7.
