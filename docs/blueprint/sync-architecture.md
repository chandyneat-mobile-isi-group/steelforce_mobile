# Sync Engine

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> Lifecycle of getting locally-captured data to SAP (and pulling reference data back) reliably, without data loss, over unreliable connectivity. Implements `docs/skills/engineering-standard.md`; sits on top of `docs/blueprint/local-storage-architecture.md`; the offline half of this story is `docs/blueprint/offline-architecture.md`.

---

## 1. Current state vs. target

A real seed exists — an order→SAP `sync_queue` table with `attempt_count`/`next_retry_at`/`last_error` and a FIFO backoff query — but it is scoped to one entity, runs in the foreground only, and has no dead-letter queue, no conflict resolver, and no background drain. `core/sync/*` is otherwise a set of 0-byte stub files. Everything in this document is the target the engine is built to; §2–§9 describe what "done" looks like per capability.

| Capability | Today | Target |
|---|---|---|
| Queue lifecycle | Order-only | Unified, entity-typed queue: `queued → inFlight → succeeded / failed → dead` |
| Retry | Field present, no policy | Capped retries → dead-letter queue |
| Priority | FIFO only | `priority`: check-in > order > telemetry |
| Batching | One row at a time | Batched by entity type, with idempotency keys |
| Backoff | Field only, unused | `base · 2^attempt + jitter`, capped |
| Conflict resolution | Empty | Server-authoritative → Action-Required queue (never silent overwrite) |
| Duplicate detection | Replace-by-id | Client-generated UUID + server idempotency key |
| Monitoring | `countsByStatus()` only | Sync Center screen |
| Offline indicators | Connectivity cubit exists | Global status pill + per-item sync state |
| Connectivity | Plugin present, service empty | Real reachability probe, not just "interface up" |
| Background execution | None | Background isolate/worker drain |
| Cleanup | Delete-on-success | TTL purge + bounded DLQ retention |
| Dead-letter queue | None | `dead` status + review UI + manual retry |
| Crash recovery | None | On boot: reset `inFlight → queued`, replay by priority |

---

## 2. Write path: mutation and queue entry are one transaction

Every local write to a syncable table (§3.1 of `docs/blueprint/local-storage-architecture.md`) enqueues its corresponding sync-queue row **inside the same database transaction** as the mutation itself. This is the single most important correctness rule in the sync design: if the app crashes between "row written" and "sync row queued," a same-transaction write means that split state is impossible — either both happened, or neither did.

```
db.transaction(() async {
  await depotDao.upsert(depot);
  await syncQueueDao.enqueue(
    entityType: 'depot',
    entityId: depot.id,
    op: SyncOp.upsert,
    idempotencyKey: uuid(),
    priority: SyncPriority.normal,
  );
});
```

This gives the UI **optimistic, zero-latency updates** — the screen reflects the write immediately from local data — while the actual server round-trip happens later, off the critical path, with the same integrity guarantee.

---

## 3. Queue state machine

```
        enqueue
           │
           ▼
       ┌────────┐   picked up by drain    ┌──────────┐
       │ queued │ ───────────────────────►│ inFlight │
       └────────┘                          └────┬─────┘
           ▲                                     │
           │ retry (backoff)          success    │  failure
           │                              │       │
           │                              ▼       ▼
           │                        ┌───────────┐ ┌────────┐
           └────────────────────────┤ succeeded │ │ failed │
                capped retries           purge   └───┬────┘
                exceeded                              │ retries exhausted
                                                        ▼
                                                    ┌──────┐
                                                    │ dead │
                                                    └──────┘
```

- **`queued`**: written, waiting to be picked up.
- **`inFlight`**: currently being sent. On process kill, every `inFlight` row is reset to `queued` on next boot (§7) — an item is never left "in flight" indefinitely because the app that was sending it no longer exists.
- **`succeeded`**: server accepted it. Purged after a short TTL (kept briefly for observability, not indefinitely — see §8).
- **`failed`**: a send attempt errored; scheduled for retry with backoff (§4) unless the cap is reached.
- **`dead`**: retries exhausted. Never auto-retried again; requires a human decision via the DLQ review UI (§6).

`ACTIVE / SUSPENDED / SYNCED` plus `PENDING / FAILED / DEAD` from the blueprint map onto this same state machine; use the `queued/inFlight/succeeded/failed/dead` names consistently in code to avoid two parallel vocabularies.

---

## 4. Retry, backoff, and priority

- **Backoff**: `delay = base · 2^attempt_count + jitter`, capped at a maximum interval — never an unbounded exponential climb, and jitter prevents every queued item from retrying in lockstep the instant connectivity returns.
- **Retry cap**: a fixed maximum `attempt_count` per row; exceeding it moves the row to `dead`, not an infinite retry loop that silently burns battery and data.
- **Priority**: `check-in > order > telemetry`. The drain always processes the highest-priority ready item first — a rep's check-in (which gates business rules like geofencing/fraud checks) must not be stuck behind a large batch of low-priority telemetry.
- **Batching**: rows of the same entity type are sent together where the API supports it, rather than one request per row — this matters at field-device scale where a rep can accumulate dozens of captures during a connectivity blackout.
- **Idempotency**: every queue row carries a client-generated idempotency key sent with the request; combined with the client UUID primary key (§3.1 of `docs/blueprint/local-storage-architecture.md`), a retried request that actually succeeded server-side the first time is recognized as a duplicate and not double-applied. This replaces the current "replace-by-id" approach, which does not protect against true duplicate submission.

---

## 5. Conflict resolution — server-authoritative, never silent

**Default policy: the server is authoritative.** When a push is rejected because the server's state has diverged from what the client assumed (stale price, order already fulfilled, quota exceeded, etc.), the client does **not** auto-resolve by overwriting either side. The item is routed to a **conflict/Action-Required queue** and surfaced on a dedicated dashboard screen for a human to review and resolve. Silent last-writer-wins on business-critical data (revenue, pricing, credit) is explicitly rejected as a policy — that is how the app would lose data trust with the business, not just technically.

Per-entity nuance (documented per entity as each is built, per `docs/skills/engineering-standard.md` §11 ADR practice):

| Entity class | Policy |
|---|---|
| Catalog/pricing (server-owned reference data) | Server always wins; client pull overwrites local cache |
| Credit/pricing on an order | Server wins; client sees the correction, not a merge |
| Field captures (check-ins, stock counts) | Client-authoritative for the capture itself, since the server has no competing version of a first-hand observation |
| Manual order edits | Route to Action-Required on conflict — never auto-merge, never auto-discard |

`conflict_manager.dart` (standardize on this name; do not use the earlier `conflict_resolver.dart` naming — see `docs/skills/engineering-standard.md` §9) implements this: on a rejected push, it classifies the entity, applies the table above, and for anything that isn't clearly server-wins, writes a row to the Action-Required queue instead of retrying blindly.

---

## 6. Dead-letter queue

- A row that exhausts its retry cap moves to `dead` and is written to `sync_dead_letter` with the last error, attempt history, and a reference back to the source queue row — never silently dropped.
- A **DLQ review UI** lists dead items grouped by entity type and error, with a manual "retry" action that re-queues the item (resetting `attempt_count`) and a "discard" action for genuinely unrecoverable rows (with an audit-log entry recording who discarded what and why — see `docs/skills/security.md` §"Secure Logging" for what may/may not be logged).
- DLQ rows are retained for a bounded period (retention policy set alongside the rest of §8 cleanup), not forever.

---

## 7. Crash and boot recovery

On every app boot, before any new sync activity starts:

1. Every row still in `inFlight` state is reset to `queued` — it was mid-send when the process died, and its actual outcome server-side is unknown, so it must be retried (idempotency keys from §4 make this safe even if the original request did land).
2. The drain resumes by priority (§4), not FIFO by insertion order, so a check-in captured just before a crash isn't stuck behind a backlog of lower-priority items.
3. `WorkflowSession` recovery (`docs/blueprint/offline-architecture.md` §3) and sync-queue recovery happen together as part of the same boot sequence — a resumed workflow screen and a resumed sync drain are two views of the same "the app was killed mid-task" event.

This recovery path is exactly what the blueprint's "battery-death resume" acceptance scenario exercises end-to-end (see `docs/blueprint/offline-architecture.md` §6).

---

## 8. Background execution and the SQLCipher-isolate hazard

- The drain must run in a background isolate/worker so sync continues (within OS limits) even when the app isn't in the foreground, rather than today's foreground-only `SyncCubit` approach which stops the moment the user backgrounds the app.
- **Known integration hazard, flagged explicitly and not yet resolved**: opening the encrypted Drift database from a background isolate can hit a "cipher open-override" problem depending on the chosen encryption path (`docs/blueprint/local-storage-architecture.md` §2.3) — the encryption pragma/key setup needs to be re-applied per isolate connection, and some cipher integrations have had issues with concurrent connections across isolates. **Prototype this early**, before committing the background-drain architecture, and keep a main-isolate fallback path available if the background-isolate approach proves unreliable with the chosen cipher library. This is called out as a High-severity risk in `docs/blueprint/migration-plan.md`'s risk register for exactly this reason.
- Platform scheduling: Android via `workmanager` (periodic + one-off tasks, subject to Doze/battery-optimization constraints), iOS via `BGTaskScheduler`-backed scheduling. Neither platform guarantees a background task runs promptly or at all under aggressive power management — the foreground drain-on-resume and drain-on-connectivity-regained paths (§9) are the reliable primary mechanism; background execution is a best-effort supplement, not the only path data can sync through.

---

## 9. Connectivity-triggered drain

- Regaining connectivity (per the real reachability probe in `docs/blueprint/offline-architecture.md` §5, not just "interface up") automatically triggers a drain — the user never has to manually pull-to-retry.
- Foreground resume (app coming back to the foreground) also triggers a drain check, independent of any background-worker outcome, so sync doesn't silently stall if the background path underperforms.

---

## 10. Monitoring — Sync Center

- A dedicated **Sync Center** screen shows queue counts by status (`queued`/`inFlight`/`failed`/`dead`), replacing the current `countsByStatus()`-only visibility.
- The Action-Required dashboard (§5) is either part of Sync Center or a linked screen — either way it must be reachable without hunting, since these are items actively blocking business outcomes (an order that can't be fulfilled as entered, a check-in with a flagged conflict).
- DLQ alerts (a growing dead-letter count, or any conflict older than a threshold) are a monitoring/observability concern — see the crash-reporting and monitoring gaps tracked in `docs/blueprint/system-architecture.md` §6 and `docs/blueprint/migration-plan.md`'s Phase 2 component list.

---

## 11. Cleanup and retention

- `succeeded` rows: purged after a short TTL — kept briefly for support/debugging visibility, not retained indefinitely.
- `dead` rows: retained per a defined retention window, then purged, unless referenced by an open Action-Required item.
- Media/attachment sync: upload-then-purge — a captured photo is deleted from local storage once confirmed uploaded, subject to size caps (`docs/blueprint/system-architecture.md` §3, Layer 4), to prevent unbounded on-device growth.

---

## 12. Testing

Covered in `docs/skills/engineering-standard.md` §10; the sync-specific scenarios that must be exercised before this engine ships:

- Queue drain under normal conditions (batching, priority ordering, backoff timing).
- Crash mid-drain → recovery on restart (`inFlight → queued`, no duplicate sends, thanks to idempotency keys).
- Network toggling mid-drain (offline→online→offline repeatedly).
- Conflict injection (mocked SAP rejection) → correct routing to Action-Required, never silent overwrite.
- DLQ population after exhausting retries, and manual retry/discard from the review UI.
- Background-isolate cipher-open hazard (§8) specifically, on both Android and iOS.

---

## 13. Related documents

- Where queue rows physically live and the transaction guarantee behind §2: `docs/blueprint/local-storage-architecture.md`
- Per-domain sync direction (pull/push/none) for every entity: `docs/blueprint/offline-architecture.md` §4
- Encryption details relevant to the isolate hazard in §8: `docs/blueprint/local-storage-architecture.md` §2
- Sprint sequencing for building this engine (Sprint 4 in the current plan): `docs/blueprint/migration-plan.md`
