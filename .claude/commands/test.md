---
description: Choose and run the tests a change actually requires, then report real results
argument-hint: '[feature, path, or "the current diff"]'
---

Test target: **$ARGUMENTS** (default: the current diff)

Follow `.claude/rules/testing.md`.

## 1. Determine what changed

```bash
git status && git diff --stat
```

## 2. Select tests by what changed — not by what is convenient

| Changed | Required |
|---|---|
| Domain logic / usecase | Unit tests |
| Repository | Repository tests with a faked datasource |
| Drift DAO or table | DAO/database tests **+** `build_runner` |
| Sync, queue, conflict | Sync + conflict + offline tests |
| Security, auth, crypto | Security tests **+ negative paths** (100% branches) |
| UI / widget | Widget tests; goldens where a layout is worth locking |
| Cross-layer | Integration tests |

## 3. Run, narrow first then broaden

```bash
flutter test test/features/<feature>/
flutter test
flutter test integration_test/
```

## 4. Cover the paths that actually break

Not just the happy path: loading, empty, error, API failure, offline,
unauthenticated, and — for anything user-facing — Khmer locale.

## 5. Fill real gaps

Where a required tier is missing, write the test. Coverage gates: domain ≥ 90%,
data ≥ 80%, crypto and sync-queue 100% of branches.

## 6. Report

Which suites ran, their **real** results including failures with output, what
you added, and — stated plainly — what you could not run and why.
