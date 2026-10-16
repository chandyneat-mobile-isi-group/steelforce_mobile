# Migration Plan — sqflite → Drift Roadmap

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> How the app gets from today's UI-complete demo with a hollow infrastructure core to the target described in `docs/blueprint/system-architecture.md`, `docs/blueprint/local-storage-architecture.md`, `docs/blueprint/sync-architecture.md`, and `docs/skills/security.md`.
> Baseline: blueprint `docs/blueprint/reference/enterprise-crm-architecture-blueprint.pdf` v2026.1.0, reviewed branch `demo/app01`.
> **Status: Planning — no further production code authorized beyond the paused T1.1 work until this plan is approved.**

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

## 0. Locked decisions (gate all downstream work)

1. **Persistence direction**: migrate to **Drift + encrypted-at-rest SQLite** — a single database with generated DAOs and a unified migrator. The three existing per-feature plaintext `sqflite` databases are ported in, not kept alongside.
2. **Sprint 1 starting point**: **encryption and key management first** — before any new feature work, and before continuing the depot/catalog/routes port.
3. **Coding rule in force** (see `docs/skills/engineering-standard.md` §2): implementation proceeds module-by-module, in dependency order, never ahead of a validated plan.

---

## 1. Baseline reconciliation — where started work needs correcting

> **Reconciled 2026-07-15 against `demo/app01` @ `6622bfc`.** The rows below were written against a pre-`6622bfc` baseline and overstated the gap: Envied and the composite-key split are **now implemented to spec** (verified in code, not inferred from filenames). Corrected status:

| Blueprint mandate | Status @ `6622bfc` | Correction needed |
|---|---|---|
| Drift + encrypted single DB (Layer 1) | ✅ **Built** — encrypted `AppDatabase`, 16 tables, 4 DAOs, unified stepwise migrator, §2.3 fail-closed cipher check present (exceeds T1.3 AC: both `cipher_version` and wrong-key open are guarded) | Keep and continue |
| Envied-obfuscated config (`Env.dbSalt`, SAP URL) | ✅ **Built** — `envied ^1.2.0` + `envied_generator`; `env.dart`/`env.g.dart`; `Env.dbSalt` injected via DI | ~~Add Envied first~~ — **done (T1.0)** |
| Composite key `SHA256(Env.dbSalt + DeviceKey)` | ✅ **Built** — `KeyDerivation.deriveDatabaseKey` computes `sha256(salt + deviceKey)`, hex-encoded, with non-empty guards | ~~Rework to composite derivation~~ — **done (T1.2)** |
| `DynamicKeyStore` device key in Keychain/Keystore | ✅ **Built** — device-key vs. derived-key split is in place; the old `DatabaseKeyManager` no longer exists | ~~Split device/derived key~~ — **done (T1.1)** |
| Key rotation / re-key | ✅ **Built** — `DatabaseKeyRotator` + `AppDatabaseRekeyExecutor` (`PRAGMA rekey`), with unit tests | **done (T1.6)** |
| **Legacy plaintext → encrypted import + purge** | 🟢 **T1.5a COMPLETE for `routes.db`** (2026-07-15). Schema v7/v8 (13 tables, §3.1 columns; the `route_stops.depot_id → depots` FK added here was **removed in v18 by ADR-011** after it was shown to abort whole route writes); `RouteDao`/`RouteTelemetryDao`/`VisitDao`; `LegacyRoutesImporter` (one transaction, idempotent, orphan-reconciling); all 3 `my_visits` datasources cut over to Drift behind the unchanged interfaces; import wired into `AppBootstrapService` with **verify-before-purge**. 82 tests cover it. ⚠️ **`routes.db` file remains** — it still holds `workflow_state` (ADR-007, Phase 3); the purge empties every *business* table, so 100% of the PII goes, but the file is deleted only when workflow is generalised. 🔴 **Still plaintext**: the Orders sqflite catalog DB (`sync_queue`, `quotations`, `sales_orders`) — **T1.5b**. | **Next: T1.5b (Orders DB), then delete `routes.db` with ADR-007** |
| Hive = non-sensitive prefs only | ✅ Correct — the dead Hive-backed session store was removed; only prefs/cache remain | Keep. **Note**: unused `LocalCache` invites caching business data in Hive (§3 violation) — delete or scope it |
| Native filesystem media, DB holds only string refs (Layer 4) | ⛔ Stub (`core/database/files/encrypted_file_store.dart`) | Build in Phase 5 (§8, P0) |
| `WorkflowSession` (explicit schema) | ⛔ Partial `ActiveWorkflow`, scoped to `my_visits`, on sqflite | Generalize in Phase 3 (ADR-007) |
| SyncQueue in the **same transaction** as the mutation; isolated background drain | ⛔ Order-only queue, foreground only, on sqflite. `core/sync/*` are 0-byte stubs | Build in Phase 4 (ADR-006) |
| Conflict = server-validation / Action-Required queue | ⛔ None | Build in Phase 4 |
| SAP Core API wrapper | ⛔ `sap_client.dart` 0-byte; all remotes mocked | Build in Phase 4/7 |

**Headline (revised)**: the design is sound and internally consistent. **Sprint 1's crypto foundation (T1.0–T1.4, T1.6) is built and verified**; the remaining Sprint 1 P0 is **T1.5**, the one-way legacy import that actually removes plaintext PII from disk. Beyond Sprint 1, the sync/workflow/SAP/observability layers remain largely unbuilt — so the "~60% unbuilt" framing still holds for the infrastructure layer *as a whole*, but no longer for encryption.

---

## 2. Architecture scorecard (why this order)

Scored /10 for a 10-year maintenance horizon; full detail and reasoning per area lives in `docs/blueprint/system-architecture.md` and the topic-specific guides. Summary:

| Area | Score | Why |
|---|---|---|
| Clean Architecture / BLoC | 8/10 | Already well-practiced; weak only because shared Core is hollow |
| 4-layer persistence design | 9/10 | Correct separation on paper; 0% implemented today |
| Envied config isolation | 7/10 | Sound as defense-in-depth; not implemented |
| Dynamic key derivation | 8/10 | Sound design; needs rotation flow and documented KDF rationale |
| WorkflowSession | 7/10 | Good scoped design; needs identity/expiry/version fields |
| Sync engine + conflict policy | 7/10 | Sound design (optimistic UI, transactional queue writes); needs DLQ, priority, backoff, dedup, recovery |
| SAP integration | 6/10 | Entirely mocked; contract unknown |
| Project layout | 8/10 | Matches target; minor naming drift to fix (`docs/skills/engineering-standard.md` §9) |

**Overall: 7.6/10** — excellent design, the execution gap is the risk being managed by this plan.

---

## 3. Missing enterprise components (beyond the four core systems)

Priority: **P0** blocks production · **P1** needed pre-GA · **P2** fast-follow.

| Component | Priority | Why |
|---|---|---|
| Structured, PII-free logging | P0 | Required by `docs/skills/security.md`; none exists today |
| Crash reporting (Crashlytics/Sentry) | P0 | Field crashes are currently invisible |
| Audit trail table | P0 | Compliance and fraud investigation; not built |
| CI/CD pipeline wired to gates | P0 | Pipeline is documented, not enforced |
| Testing strategy execution | P0 | Tests are sparse relative to the coverage gates in `docs/skills/engineering-standard.md` §10 |
| Storage cleanup (media/queue TTL) | P0 | Device-full failures are a real field risk |
| Migration strategy (unified) | P0 | Field-device corruption risk under the current per-DB versioning |
| Error recovery (sync) | P0 | Data durability depends on it |
| Formal dependency injection | P1 | `get_it` exists but is ad hoc per feature |
| Monitoring/observability | P1 | No metrics on sync/DB/queue health today |
| Feature flags | P1 | Needed for safe rollout / kill-switch |
| API versioning policy | P1 | SAP is versioned (`/api/v2`); client has no policy |
| Device registration/binding | P1 | Needed for remote revocation |
| Accessibility completion | P1 | Partially done |
| Background-worker monitoring | P1 | Silent-failure detection for the sync drain |
| Security monitoring (root/tamper) | P1 | See `docs/skills/security.md` §8 |
| Performance metrics | P1 | Regression detection |
| Analytics (opt-in) | P2 | Product-decision support, not a blocker |
| Rate limiting (client-side) | P2 | Protects the SAP backend |
| Health checks | P2 | Ops confidence |
| Formal caching TTLs | P2 | Currently informal but functional |
| DB monitoring | P2 | Corruption/size alerts |
| Data retention policy | P1 | Legal/PII implications |
| Backup / disaster recovery | P2 | Loss-recovery posture |
| Organization/Role/Permission (RBAC) | P1 | No domain model yet; blocks any permission-gated feature |
| Repository contracts (complete) | P1 | Partial today |

---

## 4. Phased roadmap

```
P0  Stabilize & Decide         — ADRs, resolve legacy-vs-guided visit flow, migration approach. Low risk.
P1  Secure Data Foundation     — Envied + DynamicKeyStore + composite key + encrypted Drift DB + migrator.
                                  DoD: all data encrypted at rest; migration proven on upgrade.
P2  Core Entities               — Port every feature to shared Drift DAOs.
                                  DoD: feature parity; no plaintext DB remains.
P3  Resumable Workflow          — Generalize WorkflowSession; resume router; expiry/GC; multi-user.
                                  DoD: resume survives crash + upgrade + relogin.
P4  Sync Engine                 — Unified queue, backoff, priority, conflict manager, DLQ, background drain,
                                  connectivity-triggered resume. DoD: durable, observable, recoverable sync;
                                  conflicts surfaced, never silently resolved.
P5  Media / Attachments         — Encrypted file store, lifecycle, upload-then-purge, size caps.
                                  DoD: bounded media; passes offline-blackout E2E.
P6  Dashboard / Reporting       — Real synced data replaces demo data.
P7  SAP Integration             — Replace mocks; real auth, retry, contract. External dependency risk.
P8  Security Hardening          — Cert pinning, biometric, root/jailbreak/tamper detection, obfuscation.
P9  Optimization + Testing      — Performance, coverage, integration, security test suites.
P10 Production Release          — Store submission, monitoring, crash reporting live.
```

`P1` and `P4` are marked **High** effort/risk; everything downstream of them is blocked by them per the dependency graph in §6.

---

## 5. Sprint plan

| Sprint | Theme | Contents | Testing focus | Risk |
|---|---|---|---|---|
| S0 | Architecture / CI-CD / Setup | ADRs, Envied scaffold, CI wiring, decisions locked | Pipeline smoke | Low |
| S1 | **Crypto foundation** | T1.0–T1.6 (Envied, DynamicKeyStore, composite key, encrypted Drift DB, migrator) | Migration + encryption tests | **High** |
| S2 | Core entities / schema + DAOs | Port depots, catalog, routes, orders | DAO + repository tests | **High** |
| S3 | Workflow resume | Generalized session entity, resume router, expiry | Crash/resume simulation | Medium |
| S4 | Sync engine | Queue, backoff, priority, background isolate, conflict manager, DLQ | Offline-chaos suite | **High** |
| S5 | Media / Layer 4 | Encrypted file store, lifecycle | Storage tests | Medium |
| S6 | Dashboard / Action-Required | On real synced data | Widget/golden tests | Medium |
| S7 | SAP integration | Replace mocks, real auth, retry | Contract tests | **High** |
| S8 | Security hardening | Pinning, biometric, root/tamper, obfuscation | Security test suite | Medium |
| S9 | Testing / performance | Coverage, load, perf | Full test matrix | Medium |
| S10 | Production release | Store submission, monitoring, crash reporting | Acceptance testing | Medium |

---

## 6. Dependency graph

```
Envied Config ─► DynamicKeyStore ─► KeyDerivation ─► Encrypted AppDatabase ─► Migrator
        │
        ▼
   DAOs / Repositories
        │
   Authentication ─► RBAC (Organization/Role/Permission)
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

**Rule**: no module ships before its dependency does; nothing above the encrypted database ships until Sprint 1 is complete (`docs/skills/engineering-standard.md` §2, `docs/blueprint/system-architecture.md` §4).

---

## 7. Sprint 1 task backlog — crypto foundation (blueprint-corrected)

| ID | Title | Priority | Deps | Effort (pts) | Acceptance criteria | Testing |
|---|---|---|---|---|---|---|
| T1.0 | Add Envied + `.env.dev`/`.env.prod` (git-ignored); expose `Env.dbSalt`, `Env.sapApiUrl` | P0 | — | 3 | `Env.dbSalt` resolves from the obfuscated generated class; no secret values in VCS | Build + secret-scan |
| T1.1 | `DynamicKeyStore`: generate a 256-bit device key, store in Keychain/Keystore | P0 | T1.0 | 5 | Key generated once, hardware-sealed, idempotent on repeat calls | Unit + secure-storage mock |
| T1.2 | `KeyDerivation`: `FinalKey = SHA256(Env.dbSalt + DeviceKey)` | P0 | T1.0, T1.1 | 3 | Deterministic 32-byte key; KDF rationale documented (see `docs/blueprint/local-storage-architecture.md` §2.1) | Unit, known-vector |
| T1.3 | Encrypted `AppDatabase` (Drift), inject composite key at open time | P0 | T1.2 | 8 | Opens with correct key; wrong key fails to open; `cipher` pragma confirms encryption is active | On-device open + wrong-key test |
| T1.4 | Unified migrator + schema-version registry | P0 | T1.3 | 5 | Migrations run once, idempotent, covered by schema tests | Drift schema tests |
| T1.5 | Legacy plaintext → encrypted one-time import | P0 | T1.3, T1.4 | 8 | `catalog.db`/`depots.db`/`routes.db` imported; old plaintext files purged after verified import; zero data loss | Migration integration test |
| T1.6 | Key-rotation / re-key routine | P1 | T1.3 | 5 | Re-key completes without data loss; `key_metadata` version bumped | Integration |

> **Correction vs. started work**: the current `DatabaseKeyManager` (stores one final random key directly) is replaced by the T1.1 + T1.2 split (device key + salted derivation). The Drift scaffolding already written for the encrypted database is reused for T1.3, not discarded.

Subsequent sprints' task backlogs are produced when reached, to avoid stale planning — this is deliberate, not an omission.

---

## 8. Additional Sprint-1-adjacent backlog (encrypted file store, secure-storage wrapper)

Carried from the earlier architecture review as still-relevant Sprint 1/2 items not superseded by the blueprint correction above:

- **Encrypted file/attachment store** — P0, 5 pts. AC: photos encrypted at rest; orphan cleanup on failed/abandoned uploads.
- **Secure-storage wrapper** (`core/database/secure`) — P1, 3 pts. AC: one API surface for tokens *and* the device key; no feature calls `flutter_secure_storage` directly.

---

## 9. Risk register

| Risk | Type | Likelihood | Severity | Mitigation | Owner |
|---|---|---|---|---|---|
| Plaintext PII/revenue at rest | Security | High | Critical | Encrypted Drift DB, Sprint 1 (blocking) | Security |
| Fragmented multi-DB, no atomic transactions | Technical | High | High | Single Drift DB (Sprint 1–2) | DB |
| Uncoordinated migrations corrupt devices | Migration | Medium | High | Unified migrator + schema tests before any schema change | DB |
| Encrypted-DB open across background isolate | Technical | Medium | High | Prototype early (`docs/blueprint/sync-architecture.md` §8); main-isolate fallback available | Sync |
| Sync conflict → data loss or duplication | Sync | Medium | High | Server-authoritative policy + idempotency keys + DLQ (`docs/blueprint/sync-architecture.md` §5–6) | Sync |
| Envied salt over-trusted as a standalone secret | Security | Medium | Medium | Always combine with device key; document rationale (`docs/skills/security.md` §4) | Security |
| SAP contract unknown | Business | High | High | Contract-first engagement with SAP team; swappable mock adapter retained for offline dev | SAP |
| Unbounded encrypted media growth | Performance | Medium | Medium | Size caps + upload-then-purge (`docs/blueprint/sync-architecture.md` §11) | Mobile |
| Dev shims shipped to production (geofence bypass, permissive fraud policy) | Security/Business | Medium | High | Release-gate checklist + CI grep for tagged shortcuts (`docs/skills/security.md` §11) | QA |
| No background sync → lost captures if app is killed | Offline | Medium | High | `workmanager`/`BGTaskScheduler` + crash-recovery replay (`docs/blueprint/sync-architecture.md` §7–8) | Mobile |
| Empty core stubs mistaken for "done" | Maintenance | High | Medium | This document + explicit infra backlog; no module marked complete without tests | Eng lead |
| No crash reporting/observability | Operational | High | High | Add in S0/Phase 8 | DevOps |

---

## 10. Testing strategy for the migration

| Layer | Scope | Tooling |
|---|---|---|
| Unit | Usecases, key derivation, backoff math | `flutter_test`, `mocktail` |
| Repository | Contract behavior, entity mapping | Mocked datasources |
| DAO | Drift queries, constraints | In-memory (host) + on-device encrypted |
| Integration | Boot → encrypt → migrate → resume | `integration_test` |
| Offline/Sync | Queue drain, recovery, network toggling | Fake connectivity, chaos harness |
| Conflict | Server-reject → Action-Required routing | Mocked SAP conflict responses |
| Performance | Catalog paging, cold start, DB size | Benchmarks |
| Load | Large queue / large media backlog | Stress fixtures |
| Security | Wrong-key-fails, no-PII-in-logs, no-plaintext-DB | Custom checks + MobSF/Gitleaks |
| UI/Widget | Screens, states | `flutter_test` |
| Golden | Key screens, light/dark, en/kh | `golden_toolkit` |
| Acceptance | Battery-death resume, blackout sync | Manual + integration |

**Coverage gates** (same as `docs/skills/engineering-standard.md` §10): domain ≥ 90%, data ≥ 80%, crypto/sync 100% of branches.

---

## 11. DevOps and release sequencing

- **Branching**: `main` (production), `develop` (integration), `feature/*`, `release/*`, `hotfix/*`, `bugfix/*`.
- **Environments**: `.env.development` / `.env.staging` / `.env.production`, Envied-wrapped, never committed.
- **Secrets**: GitHub Secrets + Fastlane Match; never in VCS; secret-scan is a required CI gate.
- **CI** (every push): `flutter analyze`, `dart format` check, unit/widget/integration tests, security scan, dependency audit, build Android + iOS.
- **CD**: `develop` → Firebase App Distribution (dev/QA); `release/*` → Google Play Internal Testing + TestFlight; `main` → Google Play Production + App Store, via Fastlane.
- **Signing**: keystore/certificates managed in CI; obfuscation and `--split-debug-info` enabled on release builds.
- **Rollback**: staged rollout with the ability to revert to the prior build; a **DB migration downgrade guard** (`docs/blueprint/local-storage-architecture.md` §5) is mandatory before this is safe — a rollback that opens a database with a newer schema than the reverted app understands must fail closed, not corrupt data.
- **Monitoring/crash reporting**: Crashlytics or Sentry, plus sync-queue and DLQ alerting (`docs/blueprint/sync-architecture.md` §10).
- **Deployment checklist**: full detail in `docs/skills/security.md` §11 — debug flags stripped, mocks removed, encryption verified, migration tested, obfuscation on.

---

## 12. Production readiness checklist (condensed)

- **Architecture**: single encrypted DB; Core infra implemented (not stubbed); no layer violations; legacy-vs-guided visit flow resolved.
- **Security**: encryption on; keys in secure storage with rotation; cert pinning; biometric; no VCS secrets; debug flags stripped; media encrypted.
- **Database**: UUID + `updated_at`/`deleted`/`sync_state` on every syncable table; indexes audited; migrations tested; soft-deletes only.
- **Performance**: paged, index-backed queries; bounded media; a defined cold-start budget.
- **Offline**: every write durable and queued in the same transaction; crash-recovery replay; per-entity conflict policy; offline banner.
- **Testing**: unit/repository/migration/widget/integration/offline-chaos/security tests all passing at their coverage gates.
- **Accessibility**: localized (en/kh); semantic labels; light/dark contrast; scalable text.
- **Logging**: no PII/tokens; structured, PII-free offline error log; `audit_log` populated for sensitive actions.
- **Monitoring**: crash reporting live; sync-queue dashboard; DLQ alerts configured.
- **Deployment**: CI gates enforced; obfuscation on; signing verified; store checklist complete.

---

## 13. Implementation order (single line, for quick reference)

Envied → DynamicKeyStore → KeyDerivation → Encrypted AppDatabase → Migrator → DAOs → Authentication/RBAC → Core entities (Depot/Product/Route/Order) → WorkflowSession → Sync Engine/Conflict Manager → SAP Client → Media → Security Hardening → CI/CD → Release.

---

## 14. Coding rule (in force)

No production code beyond the already-paused T1.1 work until this plan is approved. After approval, implementation proceeds **module-by-module**, preserving Clean Architecture and SOLID (`docs/skills/engineering-standard.md`), starting at the corrected **Sprint 1 / T1.0 (Envied) → T1.3 (encrypted database)**.

---

## 15. Related documents

- What "done" looks like for each system this plan builds: `docs/blueprint/system-architecture.md`, `docs/blueprint/local-storage-architecture.md`, `docs/blueprint/sync-architecture.md`, `docs/skills/security.md`, `docs/blueprint/offline-architecture.md`
- The engineering rules every task in this backlog is executed under: `docs/skills/engineering-standard.md`
