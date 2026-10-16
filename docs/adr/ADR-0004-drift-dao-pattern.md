# ADR-004: Generated Drift DAOs (replacing hand-written `*LocalDataSource` classes)

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter / DB architecture review
- **Related**: `docs/blueprint/local-storage-architecture.md` §4, ADR-001, ADR-003

---

## Context

Local data access today is implemented as hand-written `*LocalDataSource` classes wrapping raw SQL against `sqflite`. Architecture review called this out specifically: the schema/SQL is competent, but mapping between SQL result rows and Dart objects happens at runtime with no compile-time safety — a column rename or type change is a runtime failure discovered by a test (if one exists) or a user, not a compile error.

Moving to a single Drift database (ADR-001) makes it possible to generate this layer instead of hand-writing it, since Drift's code generator produces typed table classes, typed query results, and typed DAOs from the schema definition.

## Decision

All local data access goes through **generated Drift DAOs**, one per aggregate/table group (`DepotDao`, `RouteDao`, `SyncQueueDao`, etc.), defined against table classes in `core/database/drift/tables/`. Rules:

1. No feature holds a second, private database handle — all reads/writes for every feature go through the shared `AppDatabase` and its DAOs (`docs/blueprint/local-storage-architecture.md` §4). This directly closes the "operational complexity of many DBs" finding from review.
2. DAOs return Drift-generated row types; the data-layer mapper (not the DAO) converts these to domain entities, per ADR-003.
3. Any DAO write method that touches a syncable table must be callable from within a repository-level `db.transaction(...)` block alongside the corresponding sync-queue insert (ADR-006) — the DAO itself does not decide sync policy, it just needs to be transaction-composable.
4. Migrations, indexes, and constraints are expressed in the same Drift table definitions the DAOs are generated from, keeping schema and access code from drifting apart the way three independently-versioned `sqflite` databases did.

## Consequences

**Positive**

- Compile-time safety for the entire local-access surface: a schema change that breaks a query is caught by the Dart compiler / codegen, not discovered in production.
- Removes an entire category of hand-written SQL bugs (typos, wrong bind-parameter order, missed column in a mapping function).
- Makes the "one transaction for mutation + sync enqueue" rule (ADR-003 point 3) mechanically enforceable, since DAOs and the transaction API share the same underlying `AppDatabase`.
- In-memory Drift databases make DAO unit tests fast without needing the real encrypted on-device file for every test (`docs/blueprint/local-storage-architecture.md` §8), while on-device tests still cover cipher-specific behavior.

**Negative**

- Requires a genuine migration effort: every feature's existing hand-written `*LocalDataSource` must be rewritten against a generated DAO (Sprint 2, `docs/blueprint/migration-plan.md`), not just recompiled.
- Adds a build-time code generation step (`build_runner`) to the development loop, which is a minor DX cost the team needs to budget for (regenerate after every table change).
- Very dynamic or ad hoc queries (rare in this app's data model) are less ergonomic under Drift's typed query builder than raw SQL would be — acceptable given how relationally regular this schema is, but worth naming as a real trade-off.

## Alternatives considered

- **Keep hand-written SQL, just point it at the single new database.** Rejected: solves ADR-001's atomicity problem but keeps the exact runtime-mapping-safety gap review flagged, and forfeits the compile-time checking that's the main reason to adopt Drift over continuing with `sqflite` directly.
- **A generic raw-query wrapper with typed result parsing added manually.** Rejected: reimplements a worse version of what Drift's codegen already provides, for ongoing hand-maintenance cost with no corresponding benefit.
