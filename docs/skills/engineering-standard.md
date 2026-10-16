# Engineering Standard

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> Master engineering rules. Every other document in this set (`docs/blueprint/system-architecture.md`, `docs/blueprint/offline-architecture.md`, `docs/blueprint/local-storage-architecture.md`, `docs/blueprint/sync-architecture.md`, `docs/skills/security.md`, `docs/blueprint/migration-plan.md`) implements the rules defined here.
> Status: Enterprise Standard · Version 1.0 · Last updated: 2026-07-15
> Source of truth precedence: **`docs/blueprint/master-plan.md` (blueprint v2026.1.0) is authoritative** wherever it differs from the earlier `docs/blueprint/master-plan.md`. This document reconciles both.

---

## 1. Purpose and Scope

This standard governs how code is designed, written, reviewed, tested, and shipped for the ISI Steel Sales Mobile app. It applies to every contributor — mobile engineers, reviewers, and anyone generating code with AI assistance. It is written to hold for a **10-year maintenance horizon**: prefer boring, explicit, testable patterns over clever ones.

Out of scope: product requirements and UI/UX specs, which live in their own design docs.

---

## 2. The One Coding Rule That Overrides Everything Else

> **No production code is written for a module until that module's plan and its dependencies are validated and approved.** Implementation proceeds **module-by-module**, in dependency order (see `docs/blueprint/system-architecture.md` §4 Dependency Graph), never ahead of it.

This rule exists because the current codebase (`demo/app01`) is a UI-complete demo (~80%) with a partially-hollow infrastructure core. Building features on top of infrastructure that doesn't exist yet is how the current gap happened, and it is not to be repeated. Concretely:

> **Status reconciliation (verified against `demo/app01` @ `6622bfc`, 2026-07-15).** This paragraph previously read "`core/database/drift/*` is empty, encryption is entirely absent." That is **no longer accurate** and has been corrected here:
> - **Built and verified**: the encrypted Drift database (16 tables, 4 DAOs, unified stepwise migrator), Envied config (`Env.dbSalt`), `DynamicKeyStore` + `KeyDerivation` implementing `SHA256(dbSalt + DeviceKey)` exactly as `docs/blueprint/local-storage-architecture.md` §2.1 specifies, key rotation, and the §2.3 **fail-closed cipher check** (refuses to open if `cipher_version` is empty or the key is wrong). Maps to `docs/blueprint/migration-plan.md` **T1.0–T1.4 and T1.6 — done**.
> - **Still hollow (accurate)**: `core/sync/*` (`sync_engine.dart`, `sync_queue_service.dart`, `conflict_manager.dart`) and `core/network/{sap_client,connectivity_service}.dart` are 0-byte stubs; `core/workflow/`, `core/security/`, `core/logging/`, `core/monitoring/` do not exist yet.
> - **The live P0 gap** is **T1.5** (legacy plaintext → encrypted import + purge): `routes.db` and the Orders sqflite catalog DB still hold business data in plaintext, including a `depots` table (PII) and `location_samples` (GPS traces).

- A feature's `data/local` layer may not be implemented against a table that hasn't landed in the shared Drift schema.
- Sync-dependent UI (badges, conflict banners, Sync Center) may not be built ahead of the sync engine states it displays.
- Security-sensitive infrastructure (encryption, key management) ships **first**, before any new feature work — see `docs/blueprint/migration-plan.md` Sprint 1.

---

## 3. Architecture Baseline

Clean Architecture, three layers per feature, dependencies point inward only:

```
presentation  →  domain  →  data
   (BLoC)      (usecases,    (repositories,
                entities)     local/remote datasources)
```

- **Presentation**: BLoC/Cubit only. No direct calls to datasources, Drift, `dio`, or secure storage from widgets or blocs — always through a domain usecase.
- **Domain**: Pure Dart. Entities, repository *interfaces*, one usecase per business action (`GetCurrentUser`, `SubmitStockCount`, …). No Flutter, no Drift, no `dio` imports here.
- **Data**: Repository *implementations*, local datasource (Drift DAO), remote datasource (API client). Mappers convert between Drift row types / DTOs and domain entities.

This layering is already well-practised in the current codebase and should be preserved, not rewritten. The gap is not layer violations — it's that `core/` infrastructure (database, sync, security) is hollow, so features improvise their own persistence instead of depending on shared Core. See `docs/blueprint/system-architecture.md` for the full layer definitions and target folder structure.

**Enforcement**: an import-boundary lint (`custom_lint` or `import_lint`) must prevent one feature from importing another feature's `data/` layer directly. Cross-feature communication goes through domain interfaces or an application/orchestration layer, never feature-to-feature data imports.

---

## 4. State Management

- **BLoC** (`flutter_bloc`) is the standard for feature state. Cubits are acceptable for simple, event-free state.
- One `Bloc`/`Cubit` per feature-slice of state, not one giant app-wide bloc.
- Events are named as imperative requests (`LoginSubmittedEvent`, `AuthCheckRequested`); states are named as outcomes (`AuthenticatedState`, `AuthGuestState`).
- Side effects that must be visible app-wide (e.g., "is the user authenticated") are mirrored into a DI singleton service (e.g. `SessionManager`) that other blocs and guards can read **synchronously**, rather than every consumer subscribing to `AuthBloc`. See `docs/blueprint/offline-architecture.md` §2 for the reference implementation.
- Global, ambient auth-redirect listeners are **prohibited** — they previously caused guests to be yanked between screens with duplicate redirects. Each surface owns its own transition (see `docs/blueprint/offline-architecture.md` §2 table).

---

## 5. Dependency Injection

- `get_it` is the DI container. Registration must be **formalized**, not ad hoc per feature — this is an explicit Phase 2 gap (`docs/blueprint/master-plan.md` Phase 2).
- Each feature exposes one `feature_injection.dart` (or equivalent) that registers its own blocs/usecases/repositories/datasources, called from a single app-level `configureDependencies()`.
- Core infrastructure (`AppDatabase`, `DynamicKeyStore`, `SyncEngine`, `ConnectivityService`, `SapClient`) is registered once in `core/di/` and injected into features — features must not construct their own instances.

---

## 6. Repository & Usecase Conventions

- One usecase class per business action, callable as `call(...)` (or a single public method). No "god" usecases that branch on a mode parameter.
- Repository interfaces live in `domain/repositories/`; implementations in `data/repositories/`. A repository method returns domain entities or a typed `Result`/`Either`-style wrapper — never a raw Drift row or DTO.
- For any table with the standard syncable columns (see `docs/blueprint/local-storage-architecture.md` §4), the repository is responsible for setting `dirty = true` and enqueuing the corresponding sync-queue row **in the same database transaction** as the local write (see `docs/blueprint/sync-architecture.md` §2). This is a hard rule, not a convention: an un-queued mutation is a data-loss bug.

---

## 7. Error Handling

- Domain/usecase layer returns typed failures (e.g. a sealed `Failure` hierarchy: `NetworkFailure`, `CacheFailure`, `ValidationFailure`, `ConflictFailure`) — no bare exceptions crossing into presentation.
- Presentation maps failures to user-facing copy via localization keys; it never displays a raw exception message or stack trace to the user.
- Every `catch` block that swallows an exception must either rethrow a typed failure or log via the structured, PII-free logger (`core/logging/app_logger.dart`; rules in `docs/skills/security.md` §10 "Secure logging") — silent `catch (_) {}` blocks are not acceptable in reviewed code.

---

## 8. Folder Structure (summary)

Full target structure is in `docs/blueprint/system-architecture.md` §3. Governing rules:

- `core/` holds infrastructure shared by every feature: `config`, `database/{drift,hive,secure,files}`, `network`, `sync`, `workflow`, `security`, `di`, `error`, `usecase`, `utils`, `session`, `theme`, `logging`, `monitoring`.
- `features/<domain>/{data,domain,presentation}` holds one business domain each (depot, catalog, route/visit, quotation, order, …).
- `shared/` holds cross-feature widgets and services that are not infrastructure (e.g. reusable UI components).
- Nothing above `core/database` may be implemented before `core/database` exists for the entity it depends on (see `docs/blueprint/system-architecture.md` §4 dependency rule).

---

## 9. Naming & Style

- Files: `snake_case.dart`. Classes: `UpperCamelCase`. Bloc events end in verbs/`Requested`/`Submitted`; states end in `State`.
- Resolve known naming drift before it spreads: standardize on `conflict_manager.dart` (not `conflict_resolver.dart`) and `dynamic_key_store.dart` (not the misspelled `secure_strorage.dart`) per the blueprint's canonical names.
- `dart format` and `flutter analyze` must pass with zero warnings before a PR is opened — both are enforced in CI (see `docs/blueprint/migration-plan.md` / `docs/release/ci-cd.md` reference for pipeline detail).

---

## 10. Testing Requirements (Definition of Done)

No feature or infrastructure component is "done" without tests at the layers that apply to it:

| Layer | Required tests | Tooling |
|---|---|---|
| Domain (usecases, key derivation, backoff math) | Unit | `flutter_test`, `mocktail` |
| Data (repository behavior, entity↔row mapping) | Unit, mocked datasources | `flutter_test`, `mocktail` |
| Drift DAOs (queries, constraints, migrations) | In-memory + on-device encrypted | Drift testing utilities |
| Cross-layer boot flows (encrypt → migrate → resume) | Integration | `integration_test` |
| Offline/sync (queue drain, recovery, connectivity toggling) | Integration + chaos | fake connectivity, chaos harness |
| Conflict handling (server-reject → Action-Required routing) | Integration | mocked SAP responses |
| UI/state | Widget | `flutter_test` |
| Visual regression (light/dark, en/kh) | Golden | `golden_toolkit` |
| Security (wrong DB key fails, no PII in logs, no plaintext DB file) | Custom + scanners | `MobSF`, `gitleaks` |

**Coverage gates** (enforced in CI, build fails below threshold): domain ≥ 90%, data ≥ 80%, cryptography and sync-queue code paths 100% of branches. These are non-negotiable because they are also security controls (see `docs/skills/security.md` §10).

A pull request is not mergeable unless: `flutter analyze` is clean, `dart format --set-exit-if-changed` is clean, all required test tiers for the touched code pass, and no secret-scan or dependency-scan finding is introduced.

---

## 11. Documentation & Decision Records

- Architecturally significant decisions (e.g. "single Drift DB over per-feature sqflite DBs", "server-authoritative conflict resolution over client-merge") are recorded as ADRs before implementation starts, per the P0 "Stabilize & Decide" phase in `docs/blueprint/migration-plan.md`.
- When a document in this set (`docs/blueprint/system-architecture.md`, `docs/blueprint/local-storage-architecture.md`, etc.) and the running code disagree, the code is wrong until an ADR says otherwise — these documents are the target, not a description of whatever currently exists. Where a gap exists, say so explicitly rather than silently documenting the shortcut.
- Any deliberate, temporary shortcut (mock SAP client, debug-only geofence bypass, permissive fraud policy) must be tagged in code with a `// TODO(release-gate):` comment and listed in the release checklist (`docs/skills/security.md` §11) so it cannot ship silently. CI should `grep` for these tags on release branches and fail if any remain.

---

## 12. Release Discipline

Every module ships only after:

1. Its dependency chain (per `docs/blueprint/system-architecture.md` §4) is already in production or in the same release.
2. Tests at the required tiers (§10) pass.
3. The relevant sections of `docs/skills/security.md`'s release checklist are satisfied for anything the module touches (storage, network, logging).
4. A reviewer independent of the author has approved the PR against this standard.

---

## 13. Document Map

| Document | Covers |
|---|---|
| `docs/skills/engineering-standard.md` (this file) | Rules that apply across the whole codebase |
| `docs/blueprint/system-architecture.md` | System overview, layers, folder structure, dependency graph |
| `docs/blueprint/offline-architecture.md` | Offline engine design, resumable workflow, connectivity |
| `docs/blueprint/local-storage-architecture.md` | Drift, DAOs, SQLCipher/encryption, schema |
| `docs/blueprint/sync-architecture.md` | Sync queue lifecycle, conflict resolution, DLQ |
| `docs/skills/security.md` | OWASP-aligned security standards, checklists |
| `docs/blueprint/migration-plan.md` | sqflite → Drift roadmap, sprints, tasks, risks |

Maintained by: Mobile Engineering Team.
