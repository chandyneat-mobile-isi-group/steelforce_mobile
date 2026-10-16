# Enterprise Offline-First CRM — Master Architecture Analysis & Implementation Plan

> Baseline: **Enterprise Offline-First CRM — Production Architecture & Security Blueprints, v2026.1.0** (`docs/blueprint/reference/enterprise-crm-architecture-blueprint.pdf`)
> App: ISI Steel Sales Mobile (Flutter) · Branch reviewed: `demo/app01` · Status: **Planning — implementation paused pending approval**
> Supersedes the earlier inferred architecture review (`ARCHITECTURE_REVIEW.md`, deleted 2026-08-27 — see git history) where they differ; the blueprint is authoritative.

> ### ⚠ Status note (2026-08-27)
>
> **The "Planning / no production code authorized" status above is stale.** The
> encryption and Drift work this document gates on has shipped: the app runs a
> single encrypted database (`isi_secure.db`, schema v20+) with 11 generated
> DAOs, and the Web target is deployed. The branch it reviews (`demo/app01`) no
> longer exists — current branches are `main` and `web`.
>
> What remains genuinely unbuilt is the **unified sync engine**
> ([ADR-0006](../adr/ADR-0006-sync-engine.md)) — `core/sync/*` is still three
> 1-byte stubs. Read the analysis and task breakdown below as valid; read every
> status stamp as historical. Full register:
> [README.md](README.md#known-documentation--code-divergences).


---

## 0. Baseline Reconciliation (Blueprint ↔ Current Code ↔ Started Work)

The blueprint is a 7-page authoritative spec. The code on `demo/app01` is a UI-complete demo (~80%) with a hollow infrastructure core. A partial **T1.1** was started before this planning pass and must be course-corrected to the blueprint.

| Blueprint mandate | Current code | Started T1.1 | Correction needed |
|---|---|---|---|
| Drift + SQLCipher, **single** DB (Layer 1) | Raw `sqflite`, 3 plaintext DBs | Drift + SQLCipher single DB ✅ | Keep |
| **Envied**-obfuscated config (`Env.dbSalt`, SAP URL) | `env.dart` empty, **no envied dep** | Not addressed | **Add Envied (Phase 1)** |
| Composite key `SHA256(Env.dbSalt + DeviceKey)` | none | Stored a raw random key directly ⚠️ | **Rework to composite derivation** |
| `DynamicKeyStore` device key in Keychain/Keystore | secure stub empty | `DatabaseKeyManager` stores final key ⚠️ | **Split: device key vs derived key** |
| Hive = non-sensitive prefs only (Layer 2) | Hive prefs ✅ | — | Keep |
| Native FS media, only string refs in DB (Layer 4) | file store stub empty | — | Build in Phase 5 |
| `WorkflowSession` table (explicit schema) | partial `ActiveWorkflow` (my_visits only) | — | Generalize in Phase 3 |
| SyncQueue written in **same txn** as mutation; isolate drain | order-only queue, foreground | — | Build in Phase 4 |
| Conflict = **Server Validation / Action-Required queue** | none | — | Build in Phase 4 |
| SAP Core API wrapper (`sap_client.dart`) | empty stub | — | Build in Phase 4/7 |

**Headline:** the blueprint is sound and internally consistent. ~60% of its infrastructure layer is unbuilt. The started T1.1 is directionally correct but must adopt **Envied + composite-key derivation** before it can be considered blueprint-compliant.

---

## Phase 1 — Architecture Review (per-section scorecard)

Scoring: /10, weighted for a 10-year maintenance horizon.

### 1.1 UI-Abstraction / Clean Architecture + BLoC
- **Purpose:** Presentation (BLoC) fully isolated from storage/remote; maps to domain repository abstractions.
- **Business value:** testable, swappable data sources; protects UI from SAP/schema churn.
- **Strengths:** Already well-practised in code (data→domain→presentation, one usecase/action, per-feature DI).
- **Weaknesses:** Shared Core infra hollow → features reinvent persistence; two parallel visit flows.
- **Scalability:** High. **Performance:** Neutral. **Security:** Neutral. **Maintainability:** High.
- **Tech-debt risk:** Medium (until Core infra exists). **Improvements:** Consolidate onto shared Core; add app-orchestration layer for cross-feature flows. **Score: 8/10.**

### 1.2 4-Layer Persistence Matrix
- **Purpose:** Segment business data / prefs / secrets / media across fit-for-purpose stores.
- **Strengths:** Correct separation; secrets never in Drift/Hive; media as references only.
- **Weaknesses:** Not implemented (plaintext sqflite today). Cross-layer lifecycle (media cleanup, key↔DB coupling) unspecified.
- **Scalability:** High. **Performance:** High. **Security:** Very high (as designed). **Maintainability:** High.
- **Tech-debt risk:** Low once built. **Improvements:** Define attachment lifecycle + orphan GC; specify key-rotation impact on DB. **Score: 9/10.**

### 1.3 Envied Config Isolation
- **Purpose:** Compile-time obfuscation of endpoints + `DB_SALT`.
- **Strengths:** Removes plaintext secrets from source; separates static env from dynamic device keys.
- **Weaknesses:** Obfuscation ≠ encryption (recoverable via reverse engineering); `DB_SALT` in binary is a weak secret alone — mitigated only by combining with device key. **Not implemented.**
- **Security:** Medium alone, High combined with device key. **Improvements:** Treat `DB_SALT` as defense-in-depth, never sole protection; keep `.env.*` git-ignored + in CI secrets. **Score: 7/10.**

### 1.4 Dynamic Key Derivation
- **Purpose:** DB key never static; `SHA256(dbSalt + deviceKey)`, device key hardware-sealed.
- **Strengths:** Stolen-binary alone can't derive key (needs device keystore); stolen-device alone lacks salt.
- **Weaknesses:** Plain `SHA256(salt+key)` is not a KDF — acceptable because `deviceKey` is already 256-bit CSPRNG (no low-entropy password to stretch); but document this rationale. No rotation/re-key flow specified.
- **Security:** High. **Improvements:** Add HKDF option + explicit re-key routine (T1.5); consider `PRAGMA cipher_migrate` path. **Score: 8/10.**

### 1.5 WorkflowSession (resumable state)
- **Purpose:** Full recovery after OS purge/battery death; route user back to exact screen/step.
- **Strengths:** Explicit schema; navigationArguments JSON = forward-compatible; status lifecycle.
- **Weaknesses:** No `userId`/`deviceId`/`expiresAt`/`version`; single-user assumption; integer IDs clash with app's String IDs; abandoned-session GC unspecified.
- **Maintainability:** High. **Improvements:** Add identity/expiry/version fields; resume-validation; TTL. **Score: 7/10.**

### 1.6 Sync Engine + Conflict Policy
- **Purpose:** Optimistic UI; mutation+SyncQueue in one txn; isolate drain; server-authoritative conflict → Action-Required queue.
- **Strengths:** Zero-latency UX; transactional integrity; no silent overwrite.
- **Weaknesses:** No DLQ, priority, backoff, dedup/idempotency, or recovery specified; isolate+SQLCipher open-override is a known integration hazard. **Not implemented** (order-only foreground seed exists).
- **Scalability:** High. **Tech-debt risk:** High until built. **Improvements:** Add idempotency keys, priority, exponential backoff, DLQ, crash-recovery replay. **Score: 7/10.**

### 1.7 SAP Integration
- **Purpose:** Authenticated HTTP wrapper; background isolation & sync routing.
- **Weaknesses:** All SAP mocked today; auth model (service acct/token exchange), retry, and contract undefined; external dependency risk.
- **Improvements:** Contract-first spec with SAP team; swappable mock adapter retained for offline dev/testing. **Score: 6/10 (unknowns).**

### 1.8 Project Layout
- Matches the repo's existing `core/{config,database/{drift,hive,secure},network,sync}` + feature triads. Minor naming drift (`conflict_resolver.dart` vs blueprint `conflict_manager.dart`; `secure_strorage.dart` typo vs `dynamic_key_store.dart`). **Score: 8/10.**

**Overall architecture score: 7.6/10** — excellent design, execution gap is the risk.

---

## Phase 2 — Missing Enterprise Components

Priority: P0 (blocks prod) · P1 (needed pre-GA) · P2 (fast-follow).

| Component | Why needed | Priority | Business impact |
|---|---|---|---|
| Dependency Injection (formal) | get_it exists but ad-hoc per feature | P1 | Testability, onboarding speed |
| Structured logging (no PII) | Blueprint security doc forbids PII logs; none today | P0 | Incident triage, compliance |
| Crash reporting (Crashlytics/Sentry) | Field crashes invisible now | P0 | Retention, MTTR |
| Monitoring/Observability | No metrics on sync/DB/queue | P1 | SLA, capacity planning |
| Analytics (opt-in) | No usage insight | P2 | Product decisions |
| Audit trail table | Blueprint lists Audit Logs in Layer 1; not built | P0 | Fraud, compliance |
| CI/CD pipeline | Doc exists, not wired | P0 | Release reliability |
| Feature flags | Blueprint lists in Hive; not built | P1 | Safe rollout, kill-switch |
| Repository contracts (complete) | Partial per feature | P1 | Layer purity |
| API versioning | SAP `/api/v2`; no client versioning policy | P1 | Backward compat |
| Health checks | No SAP/DB readiness probe | P2 | Ops confidence |
| Caching strategy (formal TTL) | Informal | P2 | Perf, staleness control |
| Localization | en/kh present ✅ | Done | Market fit |
| Accessibility | Partial | P1 | Compliance, reach |
| Testing strategy | Sparse tests | P0 | Regression safety |
| Device registration/binding | Blueprint Device IDs; not built | P1 | Zero-trust, revocation |
| Rate limiting (client) | None | P2 | SAP protection |
| Error recovery (sync) | None | P0 | Data durability |
| Performance metrics | None | P1 | Regression detection |
| DB monitoring | None | P2 | Corruption/size alerts |
| Background-worker monitoring | None | P1 | Silent-failure detection |
| Security monitoring (root/tamper) | None | P1 | Threat response |
| Storage cleanup (media/queue TTL) | None | P0 | Device-full failures |
| Migration strategy | None (per-DB versions) | P0 | Field-device corruption |
| Data retention policy | None | P1 | Legal/PII |
| Backup strategy | None | P2 | Loss recovery |
| Disaster recovery | None | P2 | Continuity |

---

## Phase 3 — Domain Modeling

Per domain: Purpose · Deps · Entities · Repos · Use Cases · APIs · Screens · Offline · Sync · Test. (Condensed; expanded per module at build time.)

| Domain | Key entities | Offline | Sync | Notes |
|---|---|---|---|---|
| Authentication | User, AuthToken, Session | Cached user boots offline ✅ | token refresh | Guest-first (built) |
| Organization/Role/Permission | Org, Role, Permission | read-mostly cache | pull | **Missing** — needed for RBAC |
| User | User, profile | cache | pull | partial |
| Depot/Contact | Depot, Contact | full offline ✅ | pull + delta | built (sqflite→migrate) |
| Lead/Opportunity | Lead, Opportunity | offline draft | push queue | partial |
| Quotation | Quotation, Line | local-only ✅ | push→SAP | built |
| Sales Order | SalesOrder | local + queue | push→SAP (Action-Required on conflict) | built (mock SAP) |
| Product/PriceBook | Product, Category, Price | full offline catalog ✅ | pull (paged) + delta | built |
| Territory/Route/Visit | Route, Stop, Visit, CheckIn | full offline ✅ | pull + push telemetry | built (my_visits) |
| Inventory/StockCount | StockCount | offline capture ✅ | push queue | built |
| Cart | Cart, CartItem | local ✅ | none (local) | built |
| Attachment/Media | Attachment(ref) | FS + DB ref | push binary | **Layer 4 unbuilt** |
| Workflow | WorkflowSession | local ✅ | status only | generalize (Phase 3) |
| Sync | SyncQueue, DeadLetter, Cursor | local ✅ | engine | **core unbuilt** |
| Notification | Notification | local | pull/push | scaffold |
| Dashboard/Reporting | derived views | from local ✅ | derived | UI built |
| Audit | AuditLog | local ✅ | push | **unbuilt** |
| Settings/Profile | prefs | Hive ✅ | none | built |

**Gaps to add:** Organization/Role/Permission (RBAC), Audit, Attachment/Media, Sync core, Device registration.

---

## Phase 4 — Database Design (single encrypted Drift DB)

**Global rules:** every syncable table carries `id` (prefer UUID/text to match app), `updatedAt`, `deleted` (soft-delete), `syncState`, `serverRevision`, `dirty`. `PRAGMA foreign_keys=ON`. Indices on FKs + query predicates. All at-rest data AES-256 via SQLCipher composite key.

Representative core tables (full DDL produced per-table at build time):

| Table | PK | Key FKs | Indexes | Offline | Sync |
|---|---|---|---|---|---|
| depots | id | — | name, territory | full | pull+delta |
| contacts | id | depot_id | depot_id | full | pull |
| leads | id | depot_id? | status | draft | push |
| products | id | category_id | code, sku, barcode, category_id; FTS | full | pull(paged)+delta |
| categories | id | parent_id | parent_id | full | pull |
| price_books | id | product_id | product_id | full | pull |
| carts / cart_items | id | cart_id, product_id | cart_id | local | none |
| quotations / quotation_lines | id | depot_id/lead_id | status, depot_id | local | push |
| sales_orders | id | quotation_id | status | local+queue | push |
| routes / route_stops | id | route_id, depot_id | route_id, status | full | pull+push |
| visits / check_in / check_out | id | stop_id | stop_id | full | push |
| stock_counts / returns / collections | id | visit_id | visit_id | full | push |
| workflow_session | id | depot_id?, cart_id? | status, user_id | local | status |
| sync_queue | id | entity refs | status, priority, next_retry_at | local | engine |
| sync_dead_letter | id | source_queue_id | created_at | local | manual |
| sync_cursor | entity | — | — | local | bookkeeping |
| audit_log | id | user_id | entity, created_at | local | push |
| attachments | id | owner_type/owner_id | owner, upload_state | FS ref | push binary |
| device_registration | id | user_id | — | local | push |
| app_metadata | key | — | — | local | none (built) |

**Migration strategy:** single Drift `schemaVersion` + stepwise `onUpgrade`; drift schema tests; one-time importer from legacy plaintext sqflite DBs (T1.3). **Retention:** succeeded sync rows purged (TTL); audit retained N days; media purged post-upload.

---

## Phase 5 — Security Review

| Control | Blueprint | Status | Action / Priority |
|---|---|---|---|
| SQLCipher AES-256 | mandated | absent | **P0** build (Phase 1) |
| Envied obfuscation | mandated | absent | **P0** |
| Composite key derivation | `SHA256(salt+deviceKey)` | absent (T1.1 raw) | **P0 correct** |
| Secure storage (Layer 3) | Keychain/Keystore | present (tokens) | add device key + DB key |
| JWT / Refresh | required | designed | verify single-flight refresh |
| Biometric login | future | absent | P1 (`local_auth`) |
| SAP auth | required | mocked | P1 design |
| Certificate pinning | implied (HTTPS) | absent | **P1** (Dio SPKI) |
| Key rotation | "never static" | absent | P1 (re-key routine) |
| Runtime obfuscation | mandated | build-time only | P1 (R8/ProGuard + Dart obfuscate) |
| File encryption (Layer 4) | sandbox paths | absent | **P0** with media |
| Session management | required | present (SessionManager) | add idle/expiry |
| Device binding | Device IDs | absent | P1 |
| Root/Jailbreak/Tamper detection | future | absent | P1 |
| Data-leakage prevention | required | plaintext today | fixed by encryption |
| Memory security | implied | none | P2 (`cipher_memory_security=ON`) |
| Clipboard protection | — | none | P2 (sensitive fields) |
| Screenshot policy | — | none | P2 (FLAG_SECURE) |

**Note on Envied:** obfuscation is defense-in-depth, not a secret store. `DB_SALT` is safe only because it is combined with a hardware-sealed device key; never rely on the salt alone.

---

## Phase 6 — Offline Architecture

| Element | Blueprint intent | Design to implement |
|---|---|---|
| WorkflowSession | resume exact screen/step | generalize entity (+identity/expiry/version); router checks on boot |
| SyncQueue | mutation+queue in one txn | enforce single transaction at repository layer |
| Conflict resolution | server-validate → Action-Required | `conflict_manager`: server-authoritative; route flagged items to dashboard queue; no auto-overwrite |
| Connectivity | reactive, non-blocking banner | `connectivity_service` stream + global StatusPill; treat offline as normal |
| Background isolates | deferred drain offline | `sync_engine` isolate; **resolve SQLCipher open-override across isolates** (known hazard) |
| Retry policy | robust | capped exponential backoff + jitter |
| Batch sync | efficient | batch by entity type; idempotency keys |
| Queue priorities | — | check-in > order > telemetry |
| Dead-letter queue | — | `dead` status + review UI + manual retry |
| Transaction rollback | transactional safety | atomic apply; rollback on partial failure |
| Recovery logic | after purge | on boot reset `inFlight→queued`, replay by priority |
| Sync states | ACTIVE/SUSPENDED/SYNCED (+PENDING/FAILED/DEAD) | model explicitly |
| Queue monitoring | — | counts by status (seed exists) → Sync Center |
| Network recovery | auto-resume | drain on connectivity regained |
| Conflict dashboard | "Action Required" | dedicated screen listing flagged transactions |

---

## Phase 7 — Clean Architecture Validation

| Layer | Present | Verdict |
|---|---|---|
| Presentation (BLoC) | yes | ✅ disciplined |
| Domain (entities/usecases) | yes | ✅ one usecase/action |
| Repository (contracts) | partial | ⚠️ complete contracts |
| Datasource (local/remote) | yes | ✅ (migrate local to Drift DAOs) |
| Remote API / SAP | stub | ❌ build gateway |
| Local DB / Storage | fragmented | ❌ consolidate to single Drift DB |
| Background services | stub | ❌ build sync isolate |
| Dependency flow | inward | ✅ no violations found |

**Verdict:** no layering violations; the failure mode is **absent shared infrastructure**, not misplaced code. Enforce with an import-boundary lint (e.g. `custom_lint`/`import_lint`) so features cannot import each other's `data/`.

---

## Phase 8 — Production Folder Structure (target, aligned to blueprint §6)

```
lib/
├── core/
│   ├── config/            env.dart + env.g.dart (Envied)
│   ├── database/
│   │   ├── drift/         app_database.dart · tables/ · daos/ · migrations/
│   │   ├── hive/          preferences boxes (non-sensitive)
│   │   ├── secure/        dynamic_key_store.dart · key_derivation.dart
│   │   └── files/         encrypted_file_store.dart (Layer 4)
│   ├── network/           connectivity_service.dart · sap_client.dart · interceptors
│   ├── sync/              sync_engine.dart · conflict_manager.dart · sync_queue
│   ├── workflow/          workflow_session_service.dart · resume_router
│   ├── security/          root/tamper/biometric (Phase 8)
│   ├── di/ error/ usecase/ utils/ session/ theme/
│   └── logging/ monitoring/
├── features/<domain>/{presentation,domain,data}
├── shared/ widgets/ services/
└── main.dart
test/ · integration_test/ · scripts/ · ci/
```

Retain existing feature triads; migrate `data/local` off per-feature sqflite onto shared Drift DAOs.

---

## Phase 9 — Development Roadmap (blueprint's 5 phases as authoritative spine)

| Phase | Objective | Deliverables | Deps | Risks | Definition of Done |
|---|---|---|---|---|---|
| **P1 Cryptographic Foundation** | Envied + hardware key + SQLCipher Drift container | Envied config, DynamicKeyStore, composite key, encrypted `AppDatabase`, migrator | — | migration from plaintext | All data encrypted at rest; wrong key fails; migration proven on upgrade |
| **P2 Relational Schema + DAOs** | Port entities to Drift; high-perf DAOs | tables/, daos/, schema tests | P1 | feature regression | Feature parity; no plaintext DB remains |
| **P3 Resumable Workflow** | Router ↔ WorkflowSession | generalized entity, resume router, expiry/GC | P2 | multi-user, upgrade drift | Resume across crash+upgrade+relogin |
| **P4 Sync Pipeline** | Isolate drain, txn safety, SAP errors, conflict queue | sync_engine, conflict_manager, DLQ, Action-Required dashboard | P2 | isolate+cipher, data loss | Durable, observable, recoverable sync; conflicts surfaced |
| **P5 Performance Optimization** | Media off-DB, task scheduling, E2E blackout tests | encrypted file store, scheduler, integration tests | P4 | device storage limits | Bounded media; passes offline-blackout E2E |

**Pre-GA hardening (adds to blueprint):** Security (Phase 8 controls), CI/CD, Testing coverage, Observability, Production release.

---

## Phase 10 — Sprint Plan

| Sprint | Goal | Key tasks | Testing | Story pts | Risk |
|---|---|---|---|---|---|
| S0 | Setup/CI/ADRs | envied scaffold, CI wire, decisions | pipeline smoke | 13 | Low |
| S1 | **Crypto foundation** | T1.1–T1.6 (Envied, DynamicKeyStore, composite key, Drift+SQLCipher, migrator) | migration + encryption tests | 34 | High |
| S2 | Schema + DAOs | port depots/catalog/routes/orders | DAO + repo tests | 34 | High |
| S3 | Workflow resume | session entity, router, expiry | crash/resume sim | 21 | Med |
| S4 | Sync engine | queue, backoff, priority, isolate, conflict, DLQ | offline-chaos | 34 | High |
| S5 | Media/Layer 4 | encrypted file store, lifecycle | storage tests | 21 | Med |
| S6 | Dashboard/Reporting + Action-Required | on real data | widget/golden | 21 | Med |
| S7 | SAP integration | replace mocks, auth, retry | contract tests | 34 | High |
| S8 | Security hardening | pinning, biometric, root/tamper, obfuscation | security tests | 21 | Med |
| S9 | Testing/Perf | coverage, load, perf | full matrix | 21 | Med |
| S10 | Production release | store, monitoring, crash reporting | acceptance | 13 | Med |

---

## Phase 11 — Engineering Task Breakdown (Sprint 1, blueprint-corrected)

| ID | Title | Priority | Deps | Effort | Acceptance | Testing |
|---|---|---|---|---|---|---|
| T1.0 | Add Envied + `.env.dev/.env.prod` (git-ignored), `Env.dbSalt`/`Env.sapApiUrl` | P0 | — | 3 | `Env.dbSalt` resolves from obfuscated class; secrets not in VCS | build + secret-scan |
| T1.1 | `DynamicKeyStore`: 256-bit device key in Keychain/Keystore | P0 | T1.0 | 5 | key generated once, hardware-sealed, idempotent | unit + secure-storage mock |
| T1.2 | `KeyDerivation`: `FinalKey = SHA256(Env.dbSalt + deviceKey)` | P0 | T1.0,T1.1 | 3 | deterministic 32-byte key; documented KDF rationale | unit (known-vector) |
| T1.3 | Encrypted `AppDatabase` (Drift + SQLCipher), inject composite key via `PRAGMA key` | P0 | T1.2 | 8 | opens encrypted; wrong key fails; cipher_version non-empty | on-device open + wrong-key |
| T1.4 | Unified migrator + schema-version registry | P0 | T1.3 | 5 | migrations run once, idempotent, tested | drift schema tests |
| T1.5 | Legacy plaintext → encrypted import (one-time) | P0 | T1.3,T1.4 | 8 | catalog/depots/routes imported; old files purged; no loss | migration integration |
| T1.6 | Key-rotation / re-key routine | P1 | T1.3 | 5 | re-key without data loss; version bumped | integration |

> **Correction vs started work:** the current `DatabaseKeyManager` (stores a final random key directly) is replaced by the T1.1+T1.2 split (device key + salted derivation) to match the blueprint. The Drift/SQLCipher scaffolding already written is reused for T1.3.

Subsequent sprints' backlogs are produced when reached (avoids stale planning).

---

## Phase 12 — Dependency Graph

```
Envied Config ─► DynamicKeyStore ─► KeyDerivation ─► SQLCipher AppDatabase ─► Migrator
        │
        ▼
   DAOs / Repositories
        │
   Authentication ─► RBAC(Org/Role/Perm)
        │
   Depot ─► Product/PriceBook ─► Route/Visit ─► Quotation/Order
        │
   WorkflowSession (resume)
        │
   Sync Engine ─► Conflict Manager ─► Action-Required Dashboard ─► SAP Client
        │
   Media/Attachments ─► Reporting/Dashboard ─► Notification
        │
   Security Hardening ─► CI/CD ─► Release
```
**Rule:** no module before its dependency; nothing above SQLCipher DB ships until Phase 1 is done.

---

## Phase 13 — Risk Register

| Risk | Likelihood | Impact | Severity | Mitigation | Owner |
|---|---|---|---|---|---|
| Plaintext PII/revenue at rest | High | High | Critical | SQLCipher Phase 1 (blocking) | Security |
| Fragmented multi-DB, no atomic txns | High | High | High | Single Drift DB | DB |
| Uncoordinated migrations corrupt devices | Med | High | High | Unified migrator + tests | DB |
| SQLCipher open-override in background isolate | Med | High | High | Prototype early; main-isolate fallback | Sync |
| Sync conflict → loss/dup | Med | High | High | Server-authoritative + idempotency + DLQ | Sync |
| Envied salt over-trusted as secret | Med | Med | Med | Combine with device key; document | Security |
| SAP contract unknown | High | High | High | Contract-first; swappable mock | SAP |
| Media storage exhaustion | Med | Med | Med | Caps + upload-then-purge | Mobile |
| Dev shims shipped (geofence force, permissive fraud) | Med | High | High | Release-gate CI grep | QA |
| No crash reporting/observability | High | Med | High | Add Phase 8/S0 | DevOps |

---

## Phase 14 — Testing Strategy

| Layer | Scope | Tooling |
|---|---|---|
| Unit | usecases, key derivation, backoff | `flutter_test`, `mocktail` |
| Repository | contract behavior, mapping | mock data sources |
| DAO | Drift queries, constraints | Drift in-memory (host) + on-device cipher |
| Integration | boot→encrypt→migrate→resume | `integration_test` |
| Offline/Sync | queue drain, recovery, network toggle | fake connectivity, chaos harness |
| Conflict | server-reject → Action-Required routing | mock SAP conflicts |
| Performance | catalog paging, cold start, DB size | benchmarks |
| Load | large queue/media | stress fixtures |
| Security | wrong-key fail, no PII logs, no plaintext DB | custom + MobSF/gitleaks |
| UI/Widget | screens, states | `flutter_test` |
| Golden | key screens light/dark, en/kh | golden_toolkit |
| Acceptance | blueprint scenarios (battery-death resume, blackout sync) | manual + integration |

**Coverage gates:** domain ≥90%, data ≥80%, critical crypto/sync 100% of branches.

---

## Phase 15 — DevOps

- **Git:** trunk `main`, `develop`, `feature/*`, `release/*`, `hotfix/*` (per `docs/release/ci-cd.md`).
- **Environments:** `.env.dev/.env.staging/.env.prod` (Envied, git-ignored; values in CI secrets).
- **Secrets:** GitHub Secrets + Fastlane Match; never in VCS; secret-scan gate.
- **CI:** analyze, format, unit/widget/integration, security scan, dependency audit, build Android/iOS.
- **Release pipeline:** develop→Firebase; release/*→Internal/TestFlight; main→Play/App Store (Fastlane).
- **Signing:** keystore/certs in CI; obfuscation + `--split-debug-info`.
- **Rollback:** staged rollout + prior-build revert; DB migration downgrade guard.
- **Monitoring/Crash:** Crashlytics/Sentry; sync-queue + DLQ alerts.
- **Deployment checklist:** debug flags stripped (`kDebugForceInsideGeofence`, permissive `FraudPolicy`), mocks removed, encryption verified, migration tested, obfuscation on.

---

## Phase 16 — Final Deliverables Index

1. **Executive Architecture Review** — §Phase 1 (score 7.6/10; strong design, execution gap).
2. **Gap Analysis** — §0 + §Phase 2.
3. **Technical Improvement Report** — corrections: Envied, composite key, single DB, isolate cipher, DLQ.
4. **Domain Breakdown** — §Phase 3.
5. **Database Blueprint** — §Phase 4.
6. **Security Blueprint** — §Phase 5.
7. **Offline Strategy** — §Phase 6.
8. **Sync Engine Design** — §Phase 6 + §Phase 11 (S4).
9. **Folder Structure** — §Phase 8.
10. **Development Roadmap** — §Phase 9.
11. **Sprint Plan** — §Phase 10.
12. **Engineering Task List** — §Phase 11.
13. **Dependency Graph** — §Phase 12.
14. **Risk Register** — §Phase 13.
15. **Testing Strategy** — §Phase 14.
16. **Production Readiness Checklist** — §Phase 15 + §Quality (below).
17. **Implementation Order** — Envied → DynamicKeyStore → KeyDerivation → SQLCipher DB → Migrator → DAOs → Workflow → Sync/Conflict → SAP → Media → Hardening → Release.

### Production Readiness Checklist (condensed)
Architecture ✓ single encrypted DB · Security ✓ SQLCipher+composite key+pinning+biometric · DB ✓ UUID/updatedAt/deleted/syncState + tested migrations · Performance ✓ paged, bounded media, cold-start budget · Offline ✓ durable queue + recovery + conflict dashboard · Testing ✓ coverage gates + blackout E2E · Accessibility ✓ semantics + contrast + scalable text · Logging ✓ no PII · Monitoring ✓ crash + queue/DLQ alerts · Deployment ✓ obfuscation, signing, shims stripped.

---

## Coding Rule (in force)

No production code beyond the paused T1.1 until this plan is approved. Then implement **module-by-module**, preserving Clean Architecture + SOLID, starting at the corrected **Sprint 1 / T1.0 (Envied) → T1.3 (SQLCipher DB)**.
