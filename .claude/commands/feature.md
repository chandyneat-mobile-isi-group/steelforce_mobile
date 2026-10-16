---
description: Build a feature end to end — discover, plan, implement, test, verify, report
argument-hint: '<what the feature should do>'
---

Build this feature: **$ARGUMENTS**

Follow `.claude/rules/workflow.md`. Do not skip to implementation.

## Phase 1 — Understand

State, from the repository rather than assumption:
- the user requirement and which feature module owns it;
- what already exists that implements part of it;
- the API, state, navigation, and offline requirements;
- which `docs/` document governs it (feature doc, blueprint, ADR).

## Phase 2 — Discover

```bash
graphify query "<where does this behaviour live / what depends on it>"
```

Read the owning feature's `data/`, `domain/`, `presentation/`, its
`<feature>_injection.dart`, its doc in `docs/feature/`, and its existing tests.

## Phase 3 — Dependency gate

Does this depend on infrastructure that does not exist yet (sync engine, SAP
client, encrypted file store, a Drift table not in the schema)? If so, **stop**.
Name the blocker, point at `docs/blueprint/migration-plan.md`, explain the
chain, and ask before proceeding. Do not build a workaround.

## Phase 4 — Plan

List concretely: files to create, files to modify, new models, API calls,
state changes, UI changes, localization keys (EN **and** KM), and tests.
Show the plan before writing code.

## Phase 5 — Implement

Layer by layer, inward-dependencies-only: domain → data → presentation. Reuse
the feature's existing patterns. Keep scope to what was asked.

## Phase 6 — Verify

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/features/<feature>/
dart run build_runner build --delete-conflicting-outputs   # if Drift changed
git diff
```

## Phase 7 — Report

Summary · Files Changed · API · UI · Verification (real results) · Remaining
Issues · Next Steps. Include the `docs/skills/feature-ui-standard.md` §14
checklist if this touched UI.
