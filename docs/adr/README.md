# Architecture Decision Records

> **Purpose:** why a significant technical decision was made, what was rejected,
> and what it costs to change. One record per decision.
> **Not for:** feature documentation, requirements, or how-to guides.

An ADR is **immutable once accepted**. It is never edited to reflect a new
decision — a new ADR supersedes it, and the old one gains a pointer. Numbers are
never reused or renumbered.

---

## Accepted decisions

| # | Decision | Date | Status |
|---|---|---|---|
| [0001](ADR-0001-single-encrypted-database.md) | Single encrypted Drift database, replacing three plaintext `sqflite` DBs | 2026-07-15 | Accepted · referential-integrity claim superseded by 0011 |
| [0002](ADR-0002-offline-first.md) | Offline-first — the local database is the source of truth | 2026-07-15 | Accepted |
| [0003](ADR-0003-repository-pattern.md) | Repository pattern — domain interfaces, data implementations | 2026-07-15 | Accepted |
| [0004](ADR-0004-drift-dao-pattern.md) | Generated Drift DAOs, replacing hand-written `*LocalDataSource` classes | 2026-07-15 | Accepted |
| [0005](ADR-0005-connectivity-service.md) | Connectivity means real reachability, not interface-up | 2026-07-15 | Accepted |
| [0006](ADR-0006-sync-engine.md) | Unified sync engine with server-authoritative conflict resolution | 2026-07-15 | Accepted · **not yet built** |
| [0007](ADR-0007-workflow-session.md) | Generalized, resumable `WorkflowSession` | 2026-07-15 | Accepted |
| [0008](ADR-0008-sqlcipher-path.md) | SQLCipher via `sqlcipher_flutter_libs` | 2026-07-15 | Accepted · **on-disk format locked as of T1.5** |
| [0009](ADR-0009-depot-master-data-filter.md) | Depot filtering is flat and locally applicable; SAP master data is a cached lookup, not a cascade | 2026-07-20 | Accepted |
| [0010](ADR-0010-web-persistence.md) | Web persistence is session-scoped in-memory Drift | 2026-07-29 | Accepted |
| [0011](ADR-0011-local-mirror-no-foreign-keys.md) | Local mirror tables carry no foreign keys; the backend owns referential integrity | 2026-08-24 | Accepted · supersedes 0001's referential-integrity claim |

---

## The two most consequential

**[0008](ADR-0008-sqlcipher-path.md) — read before touching encryption.** The
on-disk format is locked. Switching cipher paths after T1.5 costs a one-time
re-import on every device, which means any unsynced field capture is at risk.
`.claude/CLAUDE.md` §3 currently contradicts this ADR by recommending
`sqlite3mc`; **the ADR wins.** See
[../blueprint/README.md](../blueprint/README.md#known-documentation--code-divergences) item 4.

**[0011](ADR-0011-local-mirror-no-foreign-keys.md) — read before adding any
constraint.** The foreign keys on tables mirroring backend-owned state were
removed in schema v18 after they were shown to destroy data rather than protect
it. `test/core/database/drift/foreign_key_schema_test.dart` asserts both the 6
surviving constraints **and** the deliberate absences. If that test fails with a
higher count, a constraint crept back — read the ADR; do not update the number
to make the build pass.

---

## Status vocabulary

| Status | Meaning |
|---|---|
| **Proposed** | Written, not yet ratified. Not binding. |
| **Accepted** | Binding. Code that contradicts it is a defect or needs a superseding ADR. |
| **Superseded by ADR-000N** | No longer binding. Retained for the reasoning. |
| **Partially superseded** | Some claims stand, some do not. The record says which. |

An **Accepted** ADR that is **not yet built** (0006) is still binding on
*direction*: do not build a competing mechanism, and do not treat the gap as
evidence the decision was reversed.

---

## Writing a new one

1. Take the next free number. Never reuse one.
2. Name it `ADR-000N-short-decision-name.md`, kebab-case.
3. Include: Status, Date, Deciders, Related, then **Context → Decision →
   Consequences → Alternatives considered**.
4. State what the decision *costs* and what would justify reversing it. An ADR
   with no cost section is a preference, not a decision.
5. Add a row to the table above.
6. If it supersedes an earlier ADR, edit **only** the old record's status line
   and add a dated note — never its body.

---

## Related

- [../skills/engineering-standard.md](../skills/engineering-standard.md) — the master rules ADRs sit under
- [../blueprint/README.md](../blueprint/README.md) — the architecture these decisions produced
- [../blueprint/master-plan.md](../blueprint/master-plan.md) — the analysis several of these came out of
