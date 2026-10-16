# ADR-003: Repository Pattern (Domain Interfaces, Data Implementations)

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter architecture review
- **Related**: `docs/skills/engineering-standard.md` §3, §6; `docs/blueprint/system-architecture.md` §2

---

## Context

The codebase already follows Clean Architecture (`presentation → domain → data`) with good layer discipline — architecture review found no layering violations. Repository *contracts* (interfaces) are partially defined per feature today, but not consistently, and the failure mode observed is not misuse of the pattern but incomplete application of it, combined with a hollow shared `core/` that leaves each feature to improvise persistence details the repository is supposed to hide.

Given ADR-001 (single database) and ADR-004 (DAOs), features need a stable seam between "how business logic asks for data" and "where that data physically lives" — especially because the physical answer is changing (three plaintext `sqflite` DBs → one encrypted Drift DB) without business logic needing to change at all.

## Decision

Every feature exposes its data access exclusively through a **repository interface defined in `domain/repositories/`**, implemented in `data/repositories/`. Rules:

1. The domain layer depends only on the interface — never on Drift, `dio`, or `flutter_secure_storage` types directly. This is enforced by prohibiting Flutter/Drift/network imports in `domain/` (`docs/skills/engineering-standard.md` §3).
2. Repository methods return domain entities (or a typed failure/result wrapper), never raw Drift row classes or DTOs — the mapping from row/DTO to entity happens inside the data layer (`docs/skills/engineering-standard.md` §6, `docs/blueprint/local-storage-architecture.md` §4).
3. For any table with the standard syncable columns, the repository — not the DAO, not the usecase — is responsible for marking the row `dirty` and enqueueing the corresponding sync-queue entry, in the same database transaction as the write (ADR-006). This makes the repository the single place "a mutation happened and needs to sync" is decided.
4. One usecase per business action calls exactly one (or a small, explicit set of) repository method(s) — no usecase reaches past the repository into a DAO directly.

## Consequences

**Positive**

- Swapping the underlying store (as is happening right now, per ADR-001) requires touching only the repository implementation, not domain or presentation code.
- Testing the domain layer needs only a mocked repository interface, not a real database — this is what keeps unit tests in `docs/skills/engineering-standard.md` §10 fast and independent of Drift.
- The transactional-write-plus-sync-enqueue rule (point 3) has exactly one home, closing the class of bug where a feature writes data but forgets to queue it for sync.

**Negative**

- Adds a layer of interface + implementation + mapper boilerplate for every entity, compared to calling a DAO directly from a usecase — accepted as the cost of the swappability and testability above.
- Requires discipline to keep repository methods free of UI-specific shaping (pagination display logic, formatting) — that belongs in presentation or a dedicated view-model, not the repository.

## Alternatives considered

- **Usecases call DAOs directly, skip the repository layer.** Rejected: this is closer to what the current per-feature `*LocalDataSource` classes already do informally, and it's exactly the pattern that makes swapping to Drift (ADR-001) and enforcing the transactional sync-enqueue rule (ADR-006) harder — there would be no single seam to change.
- **A single generic repository (`Repository<T>`) for all entities.** Rejected: collapses meaningfully different query needs (e.g., paged catalog search vs. single-depot lookup vs. route-with-stops joins) into a lowest-common-denominator interface that ends up leaking Drift-specific query objects back into the domain layer to stay expressive — defeats the purpose of the seam.
