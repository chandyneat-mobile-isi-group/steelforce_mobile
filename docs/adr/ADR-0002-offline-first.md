# ADR-002: Offline-First — Local Database as Source of Truth

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter architecture review
- **Related**: `docs/blueprint/offline-architecture.md`, `docs/blueprint/system-architecture.md` §1–2, `docs/blueprint/sync-architecture.md`

---

## Context

The primary users of this app are field sales reps who routinely work in warehouses, rural routes, and other locations with no or intermittent connectivity, for hours at a time. A CRM that requires a network round-trip to show a depot record, load the catalog, or record a visit is not usable for this workforce. The app's core value proposition — capture data anywhere, sync when possible — depends on every screen behaving identically whether the device is online, offline, or transitioning between the two.

The existing guest-first authentication flow (`docs/blueprint/offline-architecture.md` §2) already demonstrates this pattern working end to end and is the reference implementation the rest of the app follows.

## Decision

The local encrypted database (ADR-001) is the **single source of truth** for every screen. Concretely:

1. **Reads never wait on the network.** Every screen renders from local data. Data that hasn't synced yet is still shown; a "last synced" or pending-sync indicator communicates staleness rather than blocking the UI.
2. **Writes land locally first**, inside a transaction that also enqueues the corresponding sync-queue entry (ADR-006), giving the user an immediate, optimistic UI update. The network send happens later, off the interaction's critical path.
3. **Boot never blocks on the network.** A signed-in user with a cached session (`flutter_secure_storage`) boots straight into an authenticated, usable app with zero required network calls (`docs/blueprint/offline-architecture.md` §2.5). A guest boots straight into browsing.
4. **Connectivity is a normal state, not an error state.** Offline is surfaced as a non-blocking status pill and per-item sync indicators (`docs/blueprint/offline-architecture.md` §5) — never a blocking dialog or an error screen that stops the user from working.
5. **Navigation is not centrally gated on auth/connectivity.** Each surface owns its own transition (`docs/blueprint/offline-architecture.md` §2.2); a single global listener previously caused redirect loops for guest users and is explicitly disallowed.

## Consequences

**Positive**

- The app is fully functional (browse, capture, draft) with zero connectivity, which is a hard product requirement, not a nice-to-have.
- UI code doesn't need per-screen "is this data fresh" branching logic beyond a shared staleness indicator — it always reads local data.
- Crash/kill resilience falls out naturally: because writes are durable locally the moment they happen, a killed process loses at most in-memory UI state, never captured data (paired with `WorkflowSession` resume, ADR-007).

**Negative**

- Every mutation must be designed around eventual consistency: the UI shows an optimistic state that could later be rejected by the server (handled via the Action-Required conflict flow, ADR-006/`docs/blueprint/sync-architecture.md` §5) — this requires discipline from every feature author, not just the sync engine itself.
- Local-first reads mean a stale local cache is a real failure mode if pull-sync silently stops working; this makes sync-health monitoring (`docs/blueprint/sync-architecture.md` §10) a correctness concern, not just an ops nicety.
- Testing must cover offline/online transitions explicitly (blackout tests, `docs/blueprint/offline-architecture.md` §6) — a feature that "works" only when tested against a live network connection is not considered done.

## Alternatives considered

- **Online-first with an offline fallback cache.** Rejected: inverts the risk profile the product needs — an "offline fallback" is typically read-only or degraded, whereas this app needs full write capability offline as the common case, not the exception.
- **Sync-on-demand (manual "sync now" button, no automatic background behavior).** Rejected as the *only* mechanism (a manual trigger remains available for user reassurance), because relying on reps to remember to sync before losing connectivity is a data-loss risk; automatic connectivity-triggered and background sync (`docs/blueprint/sync-architecture.md` §8–9) removes that dependency on user behavior.
- **Global auth/connectivity-driven navigation listener.** Rejected — already tried and reverted in this codebase; it caused duplicate redirects and yanked guest users between screens. Superseded by the "each surface owns its transition" model in `docs/blueprint/offline-architecture.md` §2.2.
