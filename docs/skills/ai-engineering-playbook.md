# AI Engineering Playbook

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> The operational manual every AI coding agent (and every human engineer) follows while working in this repo. `docs/skills/engineering-standard.md` states the *rules*; this document is the *checklist-driven, example-backed* companion you actually run through while writing code. `.claude/CLAUDE.md` is the short pointer read at session start — it tells you this document exists and when to open it.
> Status: Enterprise Standard · Version 1.0 · Last updated: 2026-07-15

---

## 0. How to use this document

Before writing code: read §1–§4 (conventions, naming, folder ownership) once, then keep §5 (feature checklist) open while you work. Before opening a PR: run §6 (Definition of Done) and §7 (PR checklist). If you're reviewing someone else's change (including another agent's): use §8. Read §9–§13 (refactoring, performance, security, offline, anti-patterns) whenever the task touches those areas — they are not all relevant to every change. §14 is the worked example to copy the shape of when in doubt.

If anything here conflicts with `docs/skills/engineering-standard.md` or an ADR in `docs/adr/`, the ADR/standard wins — file a correction to this playbook rather than quietly diverging.

---

## 1. Coding conventions

- **Layering is absolute**: `presentation → domain → data`. A `domain/` file that imports `package:flutter/...`, `package:drift/...`, or `package:dio/...` is a bug, not a style nit — reject it.
- **Immutability by default.** Entities and states are immutable (`final` fields, `copyWith` for updates). Mutable model classes are a defect in a codebase this concurrency-sensitive (local writes, background sync, BLoC state).
- **Null-safety is exploited, not fought.** No `!` (bang) operator on a value that can plausibly be null at runtime — handle it explicitly, especially at storage boundaries (`docs/blueprint/offline-architecture.md` §2.5's "reads are null-safe end to end" principle applies everywhere, not just auth).
- **No business logic in widgets.** A widget's `build()` method renders state; it does not compute derived values that belong in a bloc, usecase, or entity method.
- **Typed failures, not exceptions, cross into presentation.** See `docs/skills/engineering-standard.md` §7. Presentation never displays a raw exception or stack trace to the user.
- **Small, single-purpose functions.** If you need a comment to explain what a block of a function does, that block is usually a named function.
- **`dart format` and `flutter analyze` clean, always** — not "clean enough," zero warnings.

---

## 2. Naming standards

| Element | Convention | Example |
|---|---|---|
| File | `snake_case.dart` | `depot_repository_impl.dart` |
| Class | `UpperCamelCase` | `DepotRepositoryImpl` |
| Bloc event | Imperative / past-tense request | `LoginSubmittedEvent`, `AuthCheckRequested` |
| Bloc state | Outcome noun + `State` | `AuthenticatedState`, `AuthGuestState` |
| Usecase | Verb-first, one action | `GetCurrentUser`, `SubmitStockCount`, `SyncQueueDrain` |
| Repository interface | `<Entity>Repository` in `domain/repositories/` | `DepotRepository` |
| Repository impl | `<Entity>RepositoryImpl` in `data/repositories/` | `DepotRepositoryImpl` |
| DAO | `<Entity>Dao` in `core/database/drift/daos/` | `DepotDao`, `SyncQueueDao` |
| Drift table | `<Entities>` (plural, matches table name) | `Depots`, `SyncQueue` |
| Sync/conflict infra | `conflict_manager.dart`, `dynamic_key_store.dart` | — never `conflict_resolver.dart` or `secure_strorage.dart` (named, historical typos to not repeat — `docs/skills/engineering-standard.md` §9) |
| Standard syncable columns | `id`, `updated_at`, `deleted`, `sync_state`, `server_revision`, `dirty` | See `docs/blueprint/local-storage-architecture.md` §3.1 — do not invent alternate names per table |

---

## 3. Folder ownership

Not every directory is equally safe to change. Treat this as a permission map:

| Path | Owner / change bar | Notes |
|---|---|---|
| `core/database/drift/` | Shared infra — high bar, needs schema-test coverage | Any change here can affect every feature; migrations required for schema changes (`docs/blueprint/local-storage-architecture.md` §5) |
| `core/database/secure/` | Shared infra — highest bar | Key derivation and storage; changes here are reviewed against `docs/skills/security.md` and `docs/blueprint/local-storage-architecture.md` §2 specifically, never merged casually |
| `core/sync/` | Shared infra — high bar | Queue/backoff/conflict logic used by every entity; a bug here is a data-loss bug app-wide |
| `core/network/` | Shared infra — high bar | Connectivity and the SAP gateway; interceptor changes affect every request |
| `core/di/`, `core/error/`, `core/usecase/`, `core/utils/` | Shared infra — moderate bar | Cross-cutting but lower blast radius than the above |
| `features/<domain>/{data,domain,presentation}` | Feature-owned — normal PR bar | A feature team/agent works freely within its own triad; must not reach into another feature's `data/` |
| `shared/widgets/`, `shared/services/` | Shared UI/utility — moderate bar | Cross-feature but not infra-critical; still shouldn't contain business logic |
| `docs/`, `docs/adr/` | Documentation — low bar to propose, requires the same review rigor as code for anything that changes a locked decision | New ADRs are welcome; editing an *Accepted* ADR's Decision section is not — supersede it with a new ADR instead |

**Rule of thumb**: the closer a path is to `core/database` or `core/sync`, the more this playbook's checklists (especially §10, §11, §12) apply in full, not selectively.

---

## 4. Feature checklist — building a new feature end to end

Work through this in order; do not skip ahead per `docs/skills/engineering-standard.md` §2.

1. **Confirm the dependency chain exists.** Check `docs/blueprint/system-architecture.md` §4 — is every infrastructure dependency this feature needs already built? If not, stop and say so.
2. **Domain first.** Define the entity (immutable, plain Dart), the repository interface, and one usecase per action the feature needs.
3. **Schema.** If new tables are needed, add them to `core/database/drift/tables/` with the standard syncable columns (§2 above) unless the table is genuinely local-only (like `carts` — see `docs/blueprint/local-storage-architecture.md` §3.2). Write the migration step and its schema test (`docs/blueprint/local-storage-architecture.md` §5) before writing the DAO.
4. **DAO.** Add the DAO in `core/database/drift/daos/`, generated against the new tables. No SQL hand-written outside Drift's query builder unless there's a documented, reviewed reason.
5. **Repository implementation.** Implement the interface in `data/repositories/`, with a mapper converting Drift rows to domain entities. If the entity syncs, the repository's write method wraps the mutation and the sync-queue enqueue in one transaction (`docs/blueprint/sync-architecture.md` §2, ADR-006).
6. **Remote datasource** (if applicable). Implement against the shared network client/interceptors in `core/network/` — do not instantiate a second `dio` client per feature.
7. **Presentation.** Bloc/Cubit calling usecases only; widgets render bloc state only. Gate any auth-required action with `AuthGuard` (`docs/blueprint/offline-architecture.md` §2.4) — never an inline check.
8. **Offline posture.** Declare it explicitly and add it to the table in `docs/blueprint/offline-architecture.md` §4 — every feature has a documented offline behavior, not an implicit one.
9. **Tests** at every applicable tier (§6 below).
10. **Docs.** If this feature introduces a new architectural decision (not just an application of existing ones), write an ADR (`docs/adr/`) before merging, not after.

---

## 5. Definition of Done

A change is **not done** unless every applicable line below is true. This is the same bar from `docs/skills/engineering-standard.md` §10 and §12, restated as a literal checklist:

- [ ] `flutter analyze` clean, zero warnings
- [ ] `dart format --set-exit-if-changed .` clean
- [ ] Domain layer has unit tests; coverage ≥ 90% for the touched domain code
- [ ] Data layer (repositories, mappers) has unit tests with mocked datasources; coverage ≥ 80%
- [ ] New/changed DAOs have query and constraint tests (in-memory Drift)
- [ ] New/changed schema has a migration step **and** a migration test proving no data loss on upgrade
- [ ] If the feature syncs: mutation + sync-queue enqueue happen in one transaction, verified by a test
- [ ] If the feature can conflict: conflict routing tested (server-reject → Action-Required, never silent overwrite)
- [ ] Widget/golden tests exist for new or materially changed screens (light + dark, en + kh where applicable)
- [ ] No PII, tokens, or secrets appear in any log statement touched by this change
- [ ] No new dependency was added without a maintenance/trust check (`docs/skills/security.md` §14)
- [ ] Offline behavior for this feature is documented in `docs/blueprint/offline-architecture.md` §4
- [ ] No layer-boundary violation introduced (domain importing Flutter/Drift/dio; one feature importing another's `data/`)
- [ ] Any deliberate shortcut is tagged `// TODO(release-gate):` and is not silently left permanent

---

## 6. Pull request checklist

- [ ] PR description states **what** changed and **why** — not just a restatement of the diff
- [ ] PR is scoped to one logical change — a feature PR does not also carry an unrelated refactor (see §9)
- [ ] Linked to the relevant `docs/blueprint/migration-plan.md` sprint/task ID, or explicitly marked as outside the current plan with justification
- [ ] All Definition of Done items (§5) are checked
- [ ] CI is green: analyze, format, unit/widget/integration tests, security scan, dependency audit, build Android + iOS (`docs/blueprint/migration-plan.md` §11)
- [ ] No secrets, API keys, or `.env.*` values committed
- [ ] Screenshots or a short clip attached for any UI change
- [ ] If this PR touches `core/database`, `core/sync`, or `core/database/secure` (§3 high-bar paths): explicitly calls out the blast radius in the description and tags a reviewer with context on those systems

---

## 7. Review checklist (for reviewing any PR — human or AI-authored)

Ask these in order; stop and request changes at the first "no":

1. **Does this respect the dependency graph?** (`docs/blueprint/system-architecture.md` §4) — is anything built ahead of infrastructure it depends on?
2. **Does this respect layering?** Domain free of Flutter/Drift/dio; repository interfaces in domain, implementations in data; no cross-feature `data/` imports.
3. **Is every syncable write transactional with its queue enqueue?** (ADR-006) — this is the single highest-value thing to check on any write path.
4. **Is any conflict path silent?** A server-rejected push must never auto-resolve by overwriting either side outside the documented server-wins cases (`docs/blueprint/sync-architecture.md` §5).
5. **Does anything sensitive end up in the wrong store or a log line?** (`docs/skills/security.md` §3, §10)
6. **Are the tests real?** A test that mocks away the exact thing being tested (e.g., mocking the transaction boundary in a test meant to verify transactional behavior) is worse than no test — it creates false confidence.
7. **Is the offline behavior correct and documented?** Does this feature work with zero connectivity, and is that behavior captured in `docs/blueprint/offline-architecture.md` §4?
8. **Would this survive a process kill mid-operation?** For anything stateful (workflow steps, multi-request flows), ask what happens if the app dies between step N and N+1.
9. **Is this the smallest correct change?** Scope creep in a PR (see §9) is a reviewable defect, not just a preference.

---

## 8. Refactoring rules

- **Never combine a refactor with a feature or bug fix in the same PR.** If a change needs both, the refactor lands first, alone, reviewed on its own, then the feature/fix lands on top of it. This makes both diffs reviewable and makes it possible to bisect a regression to one or the other.
- **A refactor must not change observable behavior.** If it does, it's not a refactor — it's a behavior change wearing a refactor's name; label and test it as such.
- **Refactoring `core/` requires the same schema/migration-test rigor as any other `core/database` change** if it touches persistence — "just a refactor" does not exempt a change from `docs/blueprint/local-storage-architecture.md` §5.
- **The three-plaintext-DB → one-encrypted-DB migration (ADR-001) is not "just a refactor"** — treat it, and anything like it, with the full weight of `docs/blueprint/migration-plan.md`'s sprint process, not as incidental cleanup inside an unrelated PR.
- **Boy-scout cleanups are welcome but bounded**: fixing an obviously wrong local variable name while you're in a file is fine; restructuring the file's public API while you're "in there" is not — that's a refactor and follows the rule above.
- **Delete, don't comment out.** Dead code is removed, not preserved as a commented block "in case." Version control is the history; the working tree is not an archive.

---

## 9. Performance guidelines

- **Every list-backed query is paged and index-backed.** No unbounded `SELECT *` against a table that can grow (catalog, depots, sync_queue). Check `docs/blueprint/local-storage-architecture.md` §3 for the index-audit expectation on any new query.
- **No N+1 query patterns.** A screen showing a route with its stops fetches the route and its stops in a batched/joined query, not one query per stop in a loop.
- **Cold start has a budget.** Boot-time work (`docs/blueprint/offline-architecture.md` §2.1) must resolve the auth/session check without a required network call — any new boot-time work is scrutinized against this budget, not added by default.
- **Media stays off the hot path and off the relational DB.** Attachments are filesystem + reference only (`docs/blueprint/system-architecture.md` §3, Layer 4) — never inline binary data in Drift.
- **Bloc rebuilds are scoped.** Use `BlocBuilder`/`BlocSelector` narrowly; a widget subscribing to a whole feature's state when it only needs one field causes unnecessary rebuild cascades.
- **Background/isolate work stays off the UI isolate** for anything nontrivial (sync drain, large imports, migrations) — but see the encrypted-database isolate hazard in `docs/blueprint/sync-architecture.md` §8 before assuming a naive isolate split "just works" against the encrypted DB.
- **Bounded media and queue growth**, enforced by TTL/purge policy (`docs/blueprint/sync-architecture.md` §11), not by hoping devices have infinite storage.

---

## 10. Security checklist (condensed — full detail in `docs/skills/security.md`)

- [ ] No secret, token, or PII in `SharedPreferences`, Hive, or an unencrypted table
- [ ] No secret, token, or PII in a log line (allowed: endpoint, response/error code, debug-only stack trace)
- [ ] No custom cryptography — only the specified composite-key derivation and established libraries
- [ ] Every network call uses the shared client/interceptors (HTTPS, cert validation, auth header, timeout, retry policy) — no ad hoc `http.get`
- [ ] No hardcoded API keys, URLs, or credentials — Envied config or CI secrets only
- [ ] Any new dependency is checked for maintenance status and known vulnerabilities before being added
- [ ] Any debug-only bypass is tagged `// TODO(release-gate):` and covered by the CI grep gate (`docs/skills/security.md` §11)
- [ ] Auth-gated actions go through `AuthGuard` only, never an inline check (`docs/blueprint/offline-architecture.md` §2.4)

---

## 11. Offline implementation checklist (for any feature that reads or writes data)

- [ ] Reads come from local Drift data — no screen blocks on a network call to render
- [ ] Writes commit locally first, inside a transaction, before any network attempt
- [ ] If the entity syncs: the sync-queue row is enqueued in the **same transaction** as the write (ADR-006)
- [ ] The entity's offline posture (local-only / pull / push / pull+push) is declared in `docs/blueprint/offline-architecture.md` §4
- [ ] Conflict behavior for this entity is decided and documented per `docs/blueprint/sync-architecture.md` §5 (server-wins, client-authoritative, or Action-Required) — "undecided" is not an acceptable state to ship
- [ ] The feature is tested with connectivity toggled mid-operation (blackout test, `docs/blueprint/offline-architecture.md` §6)
- [ ] If the feature has multi-step state a user could be interrupted mid-flow (not just a single atomic write): it uses `WorkflowSession` (ADR-007) rather than inventing its own resume mechanism
- [ ] UI communicates offline/pending-sync state via the shared status pill / per-item indicator (`docs/blueprint/offline-architecture.md` §5) — never a blocking dialog for "you're offline"

---

## 12. Common anti-patterns to avoid

| Anti-pattern | Why it's wrong | Do this instead |
|---|---|---|
| A widget calls a DAO or repository directly | Breaks the presentation→domain→data boundary; untestable without a real database | Widget → Bloc → Usecase → Repository interface |
| A feature holds its own `Database`/`sqflite` handle | Recreates the exact fragmentation ADR-001 eliminated | All access through the shared `AppDatabase` and its DAOs (ADR-004) |
| A mutation is written, then the sync-queue row is enqueued afterward as a separate step | A crash between the two steps silently drops the sync — a real data-loss bug, not a hypothetical | One Drift transaction wraps both (ADR-006, `docs/blueprint/sync-architecture.md` §2) |
| A conflict is resolved by having the client overwrite the server value | Silent data corruption on business-critical fields (pricing, revenue, credit) | Route to Action-Required (`docs/blueprint/sync-architecture.md` §5) unless the entity is on the documented server-wins list |
| `catch (_) {}` swallowing an exception with no rethrow or log | Turns a real failure into invisible silence — the next person to debug this has nothing to go on | Rethrow a typed `Failure` or log via the PII-free structured logger (`docs/skills/engineering-standard.md` §7) |
| Logging a full request/response body "just for debugging" | Very likely leaks PII, tokens, or revenue data into logs | Log endpoint + status/error code only; use a redacting interceptor if body inspection is genuinely needed in debug builds |
| A global auth-state listener redirects the user on every state change | Already tried, already reverted — causes duplicate redirects and yanks guests between screens (`docs/blueprint/offline-architecture.md` §2.2) | Each surface owns its own transition |
| A new table skips the standard syncable columns "because this one's simple" | The table either can't sync correctly later, or gets retrofitted at higher cost | Add `id/updated_at/deleted/sync_state/server_revision/dirty` up front unless the table is genuinely local-only like `carts` |
| Checking `isAuthenticated` inline in a screen instead of via `AuthGuard` | Duplicated gating logic that drifts out of sync across screens | `context.requireAuth(...)` — one gate, everywhere (`docs/blueprint/offline-architecture.md` §2.4) |
| Treating an empty `core/sync/*` or `core/database/files/*` stub as "not needed" | These are tracked, planned infrastructure, not dead code | Check `docs/blueprint/migration-plan.md` for the stub's planned sprint before assuming it's out of scope |
| Refactoring and feature work bundled in one PR | Makes both unreviewable and unbisectable | Split per §8 |
| A background isolate opens the encrypted database without re-establishing the cipher key/pragma for that isolate | Known hazard — silently fails or opens unencrypted depending on platform/cipher | Prototype explicitly against this hazard (`docs/blueprint/sync-architecture.md` §8); keep a main-isolate fallback |

---

## 13. Examples of correct architecture

A minimal, correct vertical slice for a syncable entity — `StockCount` — showing every layer this playbook expects. Trimmed for clarity; error handling and imports are illustrative, not exhaustive.

### 13.1 Domain entity (pure Dart, immutable)

```dart
// features/stock_count/domain/entities/stock_count.dart
class StockCount {
  final String id; // UUID, client-generated
  final String visitId;
  final String productId;
  final int countedQuantity;
  final DateTime updatedAt;
  final bool dirty;

  const StockCount({
    required this.id,
    required this.visitId,
    required this.productId,
    required this.countedQuantity,
    required this.updatedAt,
    required this.dirty,
  });

  StockCount copyWith({int? countedQuantity, bool? dirty}) => StockCount(
        id: id,
        visitId: visitId,
        productId: productId,
        countedQuantity: countedQuantity ?? this.countedQuantity,
        updatedAt: DateTime.now(),
        dirty: dirty ?? this.dirty,
      );
}
```

### 13.2 Repository interface (domain)

```dart
// features/stock_count/domain/repositories/stock_count_repository.dart
abstract class StockCountRepository {
  Future<void> submit(StockCount count); // local write + sync enqueue, one transaction
  Stream<List<StockCount>> watchForVisit(String visitId);
}
```

### 13.3 Usecase (domain)

```dart
// features/stock_count/domain/usecases/submit_stock_count.dart
class SubmitStockCount {
  final StockCountRepository _repository;
  SubmitStockCount(this._repository);

  Future<void> call(StockCount count) => _repository.submit(count);
}
```

### 13.4 Repository implementation — the transactional write + sync enqueue (data)

This is the load-bearing example in this whole document. Every syncable mutation looks like this:

```dart
// features/stock_count/data/repositories/stock_count_repository_impl.dart
class StockCountRepositoryImpl implements StockCountRepository {
  final AppDatabase _db;
  final StockCountDao _dao;
  final SyncQueueDao _syncQueueDao;

  StockCountRepositoryImpl(this._db, this._dao, this._syncQueueDao);

  @override
  Future<void> submit(StockCount count) {
    return _db.transaction(() async {
      // 1. Local write happens first — this is the source of truth immediately.
      await _dao.upsert(count.toDriftCompanion(dirty: true));

      // 2. Sync-queue enqueue happens in the SAME transaction.
      //    If the app crashes here, either both rows exist or neither does —
      //    never a write with no corresponding sync entry (ADR-006).
      await _syncQueueDao.enqueue(
        entityType: 'stock_count',
        entityId: count.id,
        op: SyncOp.upsert,
        idempotencyKey: const Uuid().v4(),
        priority: SyncPriority.telemetry,
      );
    });
  }

  @override
  Stream<List<StockCount>> watchForVisit(String visitId) {
    return _dao
        .watchForVisit(visitId)
        .map((rows) => rows.map((row) => row.toEntity()).toList());
  }
}
```

### 13.5 Mapper (data — kept separate from the DAO and the repository's business logic)

```dart
// features/stock_count/data/mappers/stock_count_mapper.dart
extension StockCountRowMapper on StockCountRow {
  StockCount toEntity() => StockCount(
        id: id,
        visitId: visitId,
        productId: productId,
        countedQuantity: countedQuantity,
        updatedAt: updatedAt,
        dirty: dirty,
      );
}

extension StockCountEntityMapper on StockCount {
  StockCountsCompanion toDriftCompanion({required bool dirty}) =>
      StockCountsCompanion.insert(
        id: id,
        visitId: visitId,
        productId: productId,
        countedQuantity: countedQuantity,
        updatedAt: DateTime.now(),
        deleted: const Value(false),
        syncState: const Value('dirty'),
        dirty: Value(dirty),
      );
}
```

### 13.6 Bloc (presentation — calls the usecase only)

```dart
// features/stock_count/presentation/bloc/stock_count_bloc.dart
class StockCountBloc extends Bloc<StockCountEvent, StockCountState> {
  final SubmitStockCount _submitStockCount;

  StockCountBloc(this._submitStockCount) : super(StockCountInitialState()) {
    on<StockCountSubmitted>((event, emit) async {
      emit(StockCountSubmittingState());
      try {
        await _submitStockCount(event.count); // domain usecase — no DAO/DB import here
        emit(StockCountSubmittedState());
      } on CacheFailure catch (f) {
        emit(StockCountFailureState(f.message)); // typed failure, no raw exception to UI
      }
    });
  }
}
```

### 13.7 What this example demonstrates

- Domain (`13.1`–`13.3`) has zero Flutter/Drift/dio imports.
- The repository (`13.4`) is the **only** place that decides "this write needs to sync" and does so inside one transaction — exactly ADR-006's rule, not a convention left to each feature to remember.
- The mapper (`13.5`) is the only code that knows about Drift row/companion shapes; nothing above it does.
- The bloc (`13.6`) never sees a Drift type or a raw exception — only the domain entity and typed failures.
- This shape is identical whether the feature is `stock_count`, `depot`, or `sales_order` — copy the shape, not the specific fields.

---

## 14. Related documents

- The rules this playbook operationalizes: `docs/skills/engineering-standard.md`
- System overview and dependency graph referenced throughout: `docs/blueprint/system-architecture.md`
- Full detail behind §9–§11's persistence/sync/offline checklists: `docs/blueprint/local-storage-architecture.md`, `docs/blueprint/sync-architecture.md`, `docs/blueprint/offline-architecture.md`
- Full detail behind §10's security checklist: `docs/skills/security.md`
- Sprint sequencing this playbook's "confirm the dependency chain exists" step checks against: `docs/blueprint/migration-plan.md`
- Why each locked decision referenced above (transactional sync-enqueue, single DB, repository pattern, etc.) was made: ADR-0001 through ADR-0011 in `docs/adr/`
- The short pointer file read at session start: `.claude/CLAUDE.md`
