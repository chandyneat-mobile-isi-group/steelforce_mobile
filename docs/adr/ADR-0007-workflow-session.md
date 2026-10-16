# ADR-007: Generalized, Resumable `WorkflowSession`

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter architecture review
- **Related**: `docs/blueprint/offline-architecture.md` §3, ADR-001, ADR-002

---

## Context

Field work is routinely interrupted mid-task: battery death, an OS process kill under memory pressure, an incoming call. A single-feature resume mechanism already exists — `ActiveWorkflow`, scoped to the `my_visits` feature — storing a single-row resume pointer (`currentScreen` plus a JSON `navigationArguments` blob) with the database as source of truth. Architecture review found the design sound for its scope (the JSON-blob argument approach is forward-compatible across schema changes) but flagged it as missing fields an enterprise-wide version needs: `sessionId`, `userId`, `deviceId`, `startedAt`, `expiresAt`, `version`, `state`. It also assumes a single user and has no resume validation, so a resume could route back to a stop or route that's since been reassigned, completed, or deleted.

Every other multi-step flow in the app (quotation building, stock-count sessions, route execution) has the same interruption risk and no equivalent recovery mechanism today.

## Decision

Generalize `WorkflowSession` into a **shared `core/workflow/` entity** any feature can use, not a `my_visits`-specific table. Design commitments:

1. Explicit identity and lifecycle fields: `sessionId`, `userId`, `deviceId`, `startedAt`, `expiresAt`, `version`, `state` — closing the gap flagged in review.
2. `id` (and the entity references inside `navigationArguments`) use the app's string/UUID ID scheme, not integer autoincrement — the current `ActiveWorkflow` table's integer IDs are a specific, named inconsistency to fix, not carry forward.
3. **Resume validation**: on resume, the referenced entity (route, stop, quotation, etc.) is re-checked to confirm it still exists and still belongs to the current user before navigating back to it — never a blind jump.
4. **Defensive recovery**: a malformed or schema-drifted `navigationArguments` blob, a renamed/removed route name, or a stale/deleted/now-completed referenced entity all fall back to the dashboard rather than crashing.
5. **Expiry**: sessions carry a TTL / end-of-day auto-close, with a resume *prompt* rather than a silent auto-jump back into a stale multi-step flow the user may not remember starting.
6. **Multi-user safety**: every session row is scoped by `userId` and cleared on logout, so a shared or re-logged-in device never resumes into another user's in-progress workflow.
7. A `resume_router` runs on boot, after the auth check (ADR-002 §2.1 boot sequence), and offers to resume a valid session before falling through to the normal shell.

## Consequences

**Positive**

- One resumable-workflow mechanism serves every multi-step flow in the app, instead of each feature needing to invent its own (or, more likely, not bothering to, and losing in-progress work on interruption).
- Resume validation and defensive fallback close a real crash/edge-case risk: without them, a resume could route a user into a broken or unauthorized state instead of failing safely to the dashboard.
- Directly enables the "battery-death resume" acceptance scenario (`docs/blueprint/offline-architecture.md` §6) — recovering a mid-visit workflow *and* a partially-drained sync queue (ADR-006) together after an unclean shutdown, which is a named, tested requirement, not an aspiration.

**Negative**

- Generalizing from a single-feature table to a shared entity is itself a migration: `my_visits`' existing `ActiveWorkflow` usage needs porting to the new schema (Sprint 3, `docs/blueprint/migration-plan.md`), including the integer-to-string ID fix.
- There is an open product question the ADR does not resolve on its own: whether the legacy `ActiveRouteScreen` is deprecated in favor of a guided 4-step flow once this generalization lands. That decision should be made and recorded (as its own ADR or a documented product decision) before Phase 3 implementation starts, not discovered mid-build.
- Expiry/TTL logic adds a background-cleanup responsibility (closing/GC'ing abandoned sessions) that didn't exist before and needs to be scheduled alongside other maintenance jobs (sync-queue TTL purge, media cleanup) rather than built as a one-off.

## Alternatives considered

- **Leave `ActiveWorkflow` scoped to `my_visits`; let other features build their own resume mechanisms as needed.** Rejected: guarantees the same gaps (no identity fields, no resume validation, no expiry) get rediscovered and re-fixed per feature instead of once, and risks some features simply not building resume support at all, which directly undermines the offline-first crash-resilience goal (ADR-002).
- **Rely on Flutter's/OS's built-in state restoration instead of an app-level session table.** Rejected: OS-level state restoration is not reliably available across both platforms, does not survive a full process kill under memory pressure in all cases, and provides no place to encode the validation/expiry/multi-user rules this app specifically needs — an explicit, database-backed session (consistent with ADR-002's "local DB as source of truth" principle) is the more dependable mechanism.
