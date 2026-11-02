---
description: Review the current diff for architecture, security, offline correctness, tests, and performance
argument-hint: '[branch, PR number, or path — defaults to the working diff]'
---

Review target: **$ARGUMENTS** (default: the current working diff)

## 1. Read the actual diff

```bash
git status
git diff                    # or: git diff main...HEAD
```

Review what changed **and what the change breaks**.

## 2. Check each dimension

**Architecture** — inward-only layering; domain free of Flutter/Drift/`dio`;
repositories return domain entities; DAOs own local access; no cross-feature
`data/` imports; one usecase per business action; no second DI or state
mechanism. (`.claude/rules/architecture.md`, `docs/adr/`)

**Security** — hardcoded secrets or endpoints; tokens or PII outside
`flutter_secure_storage` / the encrypted database; PII, payloads, GPS, or
revenue in logs; weakened validation; an untagged debug bypass (must be
`// TODO(release-gate):`). (`.claude/rules/security.md`)

**Offline correctness** — local write first; sync-queue row in the **same**
transaction as the mutation (ADR-006); graceful degradation on request failure;
no foreign key added to a local mirror table (ADR-011).

**Blast radius** — for `lib/core/` or shared repository/DAO/service changes:

```bash
graphify affected <changed file>
```

**Tests** — the tiers `.claude/rules/testing.md` requires, covering failure
paths, not only the happy path.

**Performance** — work in `build()`, unbounded lists, unnarrowed rebuilds,
repeated calls, unsized images.

**UI** — if the diff touches UI, apply
`docs/skills/feature-ui-standard.md` §14 and delegate to the **ui-ux-reviewer**
agent.

**Diff hygiene** — debug code, commented-out blocks, unrelated churn,
`.DS_Store`, committed generated files, unnecessary dependencies.

## 3. Report

Findings first, most severe first: severity, the rule violated with its section,
`file.dart:line`, and the concrete fix. Then a one-line verdict — ready / ready
with nits / blocked, and why.

If the diff is clean, say so. Do not manufacture findings to seem thorough.
