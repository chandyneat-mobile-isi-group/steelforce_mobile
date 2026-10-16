# ADR-006: Unified Sync Engine with Server-Authoritative Conflict Resolution

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter / Sync / Security architecture review
- **Related**: `docs/blueprint/sync-architecture.md` (full), ADR-001, ADR-002, ADR-003, ADR-005

---

## Context

A real but narrow sync implementation exists today: an order→SAP `sync_queue` table with `attempt_count`/`next_retry_at`/`last_error` and a FIFO backoff query. It works for one entity, runs only in the foreground, and has no dead-letter handling, no conflict resolution, and no priority. Every other entity that needs to sync (depots, routes, visits, stock counts, leads) has no queue at all today. `core/sync/*` is otherwise 0-byte stub files.

Given the offline-first requirement (ADR-002), the app will routinely accumulate a backlog of unsynced local writes — sometimes for days. The engine that eventually reconciles that backlog with the server has to be trustworthy on two dimensions simultaneously: it must not lose data, and it must not silently corrupt server state by resolving conflicts in the client's favor without anyone noticing.

## Decision

Build one **unified, entity-typed sync engine**, not per-feature bolt-on queues. Core design commitments:

1. **Queue lifecycle**: `queued → inFlight → succeeded/failed → dead`, with every syncable mutation enqueued in the *same database transaction* as the write that produced it (ADR-003 point 3) — never as a separate, potentially-skipped step.
2. **Priority over FIFO**: check-in > order > telemetry, so business-critical items aren't stuck behind low-priority backlog.
3. **Bounded retry with backoff**: `base · 2^attempt + jitter`, capped, with a fixed retry ceiling after which an item moves to a **dead-letter queue** rather than retrying forever or silently vanishing.
4. **Idempotency**: client-generated UUIDs plus per-request idempotency keys, so a retried send that actually succeeded server-side the first time is recognized as a duplicate, not double-applied.
5. **Conflict resolution is server-authoritative by default, and never silent.** When the server rejects a push because its state has diverged, the client does not auto-resolve by overwriting either side (no blind last-writer-wins on business-critical data). The item routes to an **Action-Required queue** for human review, with documented per-entity nuance (server-wins on pricing/catalog, client-authoritative on first-hand field captures, always-Action-Required on manual order edits) — see `docs/blueprint/sync-architecture.md` §5.
6. **Crash/boot recovery**: every `inFlight` row is reset to `queued` on app boot, since its outcome is unknown after an unclean shutdown; recovery replays by priority.
7. **Background execution** is attempted (platform schedulers) but is explicitly *not* the only path data can sync through — connectivity-regained and foreground-resume triggers are the reliable primary mechanism, because OS background-execution guarantees are weak on both platforms.

## Consequences

**Positive**

- One engine, one mental model, for every entity that syncs — instead of N ad hoc per-feature queues each re-solving the same problems (or not solving them) differently.
- The server-authoritative, Action-Required-on-conflict policy protects business trust in the data: revenue and pricing figures can't be silently overwritten by a stale client, and every conflict is visible and auditable rather than invisibly "resolved."
- Idempotency + same-transaction enqueue together close the two most common causes of sync data loss/duplication: a write that never got queued, and a queued item that got sent twice.
- Dead-letter handling means "sync silently gives up" is not a possible failure mode — it's always visible in a review UI.

**Negative**

- This is a genuinely large build (Sprint 4, marked High risk in `docs/blueprint/migration-plan.md`) — significantly more scope than the existing order-only seed, and it blocks every entity's real (non-mocked) sync behavior until it lands.
- The background-isolate execution path interacts with the encrypted database (ADR-001) in a way that has a known, unresolved integration hazard (re-establishing the cipher key per isolate connection) — flagged explicitly in `docs/blueprint/sync-architecture.md` §8 as needing early prototyping, with a main-isolate fallback kept available.
- Server-authoritative conflict resolution means some user-visible friction is unavoidable by design: a rep can lose a race on a price or credit check and have to see and resolve that explicitly, rather than the app quietly making the "problem" go away. This is treated as an acceptable, and in fact desirable, trade-off for data integrity — not a bug to design away later.

## Alternatives considered

- **Per-feature sync queues (status quo direction, generalized).** Rejected: multiplies the amount of retry/backoff/conflict logic that needs to be built and tested by the number of entities, with no shared guarantees between them — exactly the fragmentation problem ADR-001 solves for storage, applied to sync would recreate it.
- **Client-wins / last-writer-wins conflict resolution.** Rejected for business-critical entities (revenue, pricing, credit): silently overwriting server state with a stale client value is a data-integrity and business-trust risk the review specifically called out as unacceptable. Retained only for entities with no competing server-side version (e.g., first-hand field captures) where there's genuinely nothing to conflict with.
- **CRDTs / automatic merge for conflicting edits.** Rejected as unnecessary complexity for this domain: the entities that can conflict (orders, pricing, credit) have business-rule-driven "correct" resolutions that a generic merge algorithm can't determine — human review via the Action-Required queue is the right tool here, not automatic merging.
