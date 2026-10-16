# ADR-001: Single Encrypted Drift Database (replacing three plaintext sqflite DBs)

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter / DB / Security / DevOps architecture review
- **Related**: `docs/blueprint/local-storage-architecture.md`, `docs/blueprint/system-architecture.md` §3, `docs/blueprint/migration-plan.md` Sprint 1
- **Partially superseded by**: ADR-011 — see the note below

> **Note (2026-08-24, ADR-011).** This ADR listed on-device *referential
> integrity* among the wins of a single database. That specific claim no longer
> holds: the foreign keys on tables mirroring backend-owned state were removed in
> schema v18 after they were shown to destroy data rather than protect it — one
> unrecognised depot aborted a whole route write, and the visit cascade
> deleted captured field work on a routine re-sync. See
> `docs/adr/ADR-0011-local-mirror-no-foreign-keys.md`.
>
> **Every other decision in this ADR stands**, and cross-table atomicity — also
> impossible under the three-database split — is precisely what makes the
> replacement write paths safe.

---

## Context

`demo/app01` persists business data across three independent, plaintext `sqflite` databases: `catalog.db`, `depots.db`, `routes.db`. Each self-versions its schema via its own `onUpgrade`, with no shared migration framework and no migration tests. Architecture review found this to be the single most severe finding in the codebase: depot PII and revenue data sit unencrypted on the device, and because the databases are separate files, no operation can be atomic across them — a checkout that touches cart, depot, and sync-queue state cannot be wrapped in one transaction.

The app is offline-first by requirement (see ADR-002), which means the local database is not a cache — it is the primary data store the user interacts with for hours or days between syncs. Its integrity properties matter as much as a server database's would.

## Decision

Consolidate all relational business data into **one Drift database**, encrypted at rest, with:

- One `schemaVersion` and one unified, stepwise migrator (`docs/blueprint/local-storage-architecture.md` §5) replacing the three independent per-DB versioning schemes.
- Encryption via a composite, device-bound key (`docs/blueprint/local-storage-architecture.md` §2) — never a plaintext file on disk.
- Generated DAOs per aggregate (ADR-004) instead of hand-written SQL per feature.
- Cross-entity operations (e.g., quotation → sales order + sync-queue enqueue) wrapped in a single Drift transaction, which was structurally impossible under the three-database split.

The three existing plaintext databases are not deprecated in place; they are imported into the new encrypted database in a one-time migration (`docs/blueprint/migration-plan.md` T1.5), then deleted from disk once the import is verified.

## Consequences

**Positive**

- Encryption is applied once, at the database level, instead of needing to be retrofitted three times.
- Cross-entity transactions become possible, closing a class of partial-write bugs.
- One migration framework to test and reason about instead of three.
- Generated DAOs remove an entire category of hand-written SQL / runtime-mapping bugs.

**Negative**

- A one-time, one-way data migration is required on existing installs (T1.5); this is inherently the highest-risk step in Sprint 1 and needs its own integration test suite (no data loss, no partial import) before it ships.
- A single database file is a bigger blast radius for corruption than three smaller ones — mitigated by the migration-test discipline in `docs/blueprint/local-storage-architecture.md` §5 and a downgrade guard (`docs/blueprint/migration-plan.md` §11) that refuses to open a database from a newer schema version than the running app understands.
- Every feature currently holding a private `sqflite` handle must be ported (Sprint 2, `docs/blueprint/migration-plan.md`); this is a real, non-trivial migration cost, not a drop-in change.

## Alternatives considered

- **Keep three separate DBs, encrypt each independently.** Rejected: solves encryption but not the atomicity or unified-migration problems, and triples the encryption-integration surface area (key management, cipher-open checks, migration tests × 3).
- **Move to a server-driven cache-only model (no meaningful local writes).** Rejected outright: violates the offline-first requirement (ADR-002) that is core to the product — field reps must be able to fully operate with zero connectivity for extended periods.
- **NoSQL/document store (e.g., all-Hive) instead of relational.** Rejected: the data is genuinely relational (depots, orders, routes, line items with real foreign-key relationships) and the app needs joins, indexed queries, and referential integrity that a key-value store doesn't provide well at this schema complexity.
