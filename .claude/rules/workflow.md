# Workflow — the task lifecycle

Read this on every task.

---

## 1. Lifecycle

```
UNDERSTAND → DISCOVER → GRAPH → PLAN → DEPENDENCY CHECK → IMPLEMENT
          → FORMAT → ANALYZE → TEST → BUILD/VERIFY → DIFF REVIEW → REPORT
```

A task is not complete until the applicable verification stages have actually
run. Skipping a stage is allowed; *claiming* you ran it is not.

---

## 2. Classify the task first

| Type | Examples | Required path |
|---|---|---|
| **A — Small** | Typo, copy change, local bug fix, small UI tweak | Inspect → implement → test → diff review |
| **B — Feature** | New screen, usecase, repository, API integration | + graph analysis, architecture validation, dependency check, plan |
| **C — Infrastructure** | Database, DI, networking, sync, offline persistence, localization core | + read the governing `docs/blueprint/` document, migration-plan validation, risk analysis, full relevant suite, build verification |
| **D — High-risk** | Crypto, auth, authorization, PII, conflict resolution, DB migration, release config | All of C, plus explicit verification of security, data integrity, failure behaviour, offline behaviour, and migration safety. Correctness over speed, always. |

Type C and D changes are the ones that are expensive to retrofit. Slow down.

---

## 3. Discover before editing

Never modify production code immediately after reading the request. First
establish, from the repository — not from assumption:

- which feature/module owns the behaviour, and which layer owns the change;
- which files are involved and what already implements part of it;
- what tests exist; what `docs/` document governs it;
- what the change depends on, and whether that dependency exists yet.

**The repository is the source of truth.** Do not invent structure, APIs,
services, or patterns. If a `docs/` document and the code disagree, report the
discrepancy — do not silently rewrite either side.

---

## 4. Graph analysis (`graphify`)

`graphify-out/` holds a knowledge graph of this codebase, and a PreToolUse hook
requires a `graphify query` before broad searching. Use it to answer:

```bash
graphify query "<what depends on X / where does Y live>"
graphify path <A> <B>          # how two components connect
graphify explain <node>
graphify affected <file>       # blast radius
graphify god-nodes             # shared hubs — change these with care
```

Run it **before** changing anything under `lib/core/`, a repository, a DAO, the
network client, or the sync layer. Run `graphify update` after a significant
architectural change. Details and limitations: `docs/skills/graphify.md`.

> The graph can be stale — it is a snapshot, and its file paths may reflect an
> older docs layout. Use it to orient, then confirm against the real files.

---

## 5. Dependency-first rule

Before implementing, ask: does this depend on a module that does not exist yet?
If so:

1. Stop implementing the dependent module.
2. Name the missing dependency and where it is tracked
   (`docs/blueprint/migration-plan.md`).
3. Explain the chain to the user.
4. Implement the prerequisite only if it is within the authorised scope.

**Never build a temporary architectural workaround to make a task look
complete.** That is how the current infrastructure gap was created.

Stub files under `core/sync/`, `core/database/files/`, and
`core/network/sap_client.dart` are **tracked and expected to be empty** — check
the migration plan before assuming scope.

---

## 6. Verification ladder

Use the smallest useful check first, then broaden:

```
1 dart format --set-exit-if-changed .
2 flutter analyze
3 targeted tests for the changed code
4 feature/module test suite
5 integration tests
6 flutter build (platform)
```

Type C and D changes use the broadest applicable level. Which tests a change
requires: `testing.md`.

**Never claim a task is verified because the app compiles.**

---

## 7. Failure recovery

```
READ THE FAILURE → identify root cause → check related code
   → make one targeted fix → rerun the failed check → rerun broader validation
```

Do not re-run a command hoping for a different result. Do not change several
files until the error disappears. Do not hide or minimise a failure.

---

## 8. Scope control

Distinguish the **required** change from the **nice-to-have** change, and
implement only the required one — unless the extra work is necessary for
correctness, security, testing, or architecture. A feature task is not an
excuse for unrelated refactoring.

---

## 9. Final diff review

Before reporting, run `git status` and `git diff` and check for: unexpected
files, debug code, leftover TODOs, secrets, unrelated changes, accidental
deletions, generated files that should not be committed, wrong imports,
unnecessary dependencies. The diff must tell one coherent story.

---

## 10. Reporting format

```
## Summary          what was implemented
## Files Changed    created / modified
## API              endpoint or contract changes (omit if none)
## UI               visible changes (omit if none)
## Verification     commands actually run + their real results
## Remaining Issues anything not verified — state it plainly
## Next Steps       only if genuinely relevant
```

Honesty rules, non-negotiable:

- Do **not** say "Done" when verification is incomplete. Say
  *"Implemented, but not verified because …"*.
- Do **not** say "tests pass" unless tests ran and passed.
- Do **not** say "build successful" unless the build completed successfully.
