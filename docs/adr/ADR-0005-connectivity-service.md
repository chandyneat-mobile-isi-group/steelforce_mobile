# ADR-005: Connectivity Service — Real Reachability, Not Interface-Up

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter / Sync architecture review
- **Related**: `docs/blueprint/offline-architecture.md` §5, `docs/blueprint/sync-architecture.md` §9, ADR-002, ADR-006

---

## Context

A connectivity plugin is already present in the codebase, but `core/network/connectivity/connectivity_service.dart` is an empty stub, and the connectivity cubit that does exist reports whether a network *interface* is up (Wi-Fi/cellular radio connected to something), not whether that connection actually reaches the internet. This distinction matters a great deal for this app's user base: a phone connected to a captive-portal Wi-Fi network (common in warehouses, retail sites, and hotels) or a cellular connection with no data plan will report "connected" by interface-up logic while every real request fails.

Because sync-queue drain (ADR-006) is meant to trigger automatically on connectivity regained (`docs/blueprint/sync-architecture.md` §9), a false-positive "online" signal causes repeated failed sync attempts, burns battery and retry budget, and — worse — can cause the UI to imply data has synced when it hasn't.

## Decision

`connectivity_service` performs a **real reachability check** — an actual lightweight request that must succeed (e.g., a HEAD/GET against a known-reachable endpoint, or the first real API call succeeding) — not just an OS-reported interface state. Concretely:

1. Interface-up (via the connectivity plugin) is used only as a *cheap first filter* to avoid needless network attempts when the radio is plainly off (airplane mode, no SIM).
2. Whenever interface-up is true, a genuine reachability probe confirms actual internet access before the app is considered "online" for sync-triggering purposes.
3. The service exposes a single reactive stream of connectivity state that both the UI status pill (`docs/blueprint/offline-architecture.md` §5) and the sync engine's drain trigger (`docs/blueprint/sync-architecture.md` §9) subscribe to — one source of truth, not separately-reasoned checks in each consumer.
4. Connectivity is treated as a normal, expected state by every consumer (ADR-002) — this service reports state, it never blocks or throws to signal offline.

## Consequences

**Positive**

- Sync-queue drains are only attempted when they can plausibly succeed, avoiding wasted retry cycles and misleading "syncing…" UI states on a dead captive-portal connection.
- One shared connectivity signal means the status pill and the sync trigger can never disagree with each other, which would otherwise be confusing (pill says online, sync says nothing is happening).

**Negative**

- A real reachability probe costs a small amount of battery/data compared to a pure interface check — mitigated by using it only as a confirmation step after interface-up, and by debouncing/throttling probes rather than polling continuously.
- The reachability endpoint itself becomes a dependency: if it's unreachable for reasons unrelated to the user's actual connectivity (e.g., that specific endpoint is down but the SAP API is fine), the service could misreport offline. Mitigate by probing against the app's own API infrastructure rather than a third-party endpoint, so "reachable" specifically means "reachable enough to sync."

## Alternatives considered

- **Interface-up only (status quo direction).** Rejected: this is the exact gap review flagged; it produces false-positive "online" states on captive portals and no-data-plan connections, which is a real and common field condition for this user base, not an edge case.
- **Rely on request failures alone (no dedicated connectivity service; just retry on every failure).** Rejected: works eventually via the sync engine's own backoff (`docs/blueprint/sync-architecture.md` §4) but gives the UI no honest signal to show the user *why* nothing is syncing, and can't proactively avoid doomed attempts the way a reachability check can.
