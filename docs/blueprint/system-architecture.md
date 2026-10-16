# Architecture

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> System overview. Implements the rules in `docs/skills/engineering-standard.md`.
> Baseline: blueprint `docs/blueprint/reference/enterprise-crm-architecture-blueprint.pdf` v2026.1.0, reconciled against `demo/app01`.
> Status: Target architecture (Overall score today: 7.6/10 — design is sound, ~60% of infrastructure is unbuilt).

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

## 1. What the app is

ISI Steel Sales Mobile is a **guest-first, offline-first CRM** for a field sales force: browsing a product catalog, managing depots and leads, planning and executing routes/visits, capturing stock counts and returns, and creating quotations and sales orders that eventually sync to SAP. Sales reps regularly work with no connectivity (warehouses, rural routes), so **every write must succeed locally first** and sync opportunistically — this single requirement shapes every layer below.

---

## 2. Layered view

```
┌─────────────────────────────────────────────────────────────┐
│ Presentation (BLoC)                                          │
│   — screens, widgets, blocs/cubits — no persistence calls    │
├─────────────────────────────────────────────────────────────┤
│ Domain                                                        │
│   — entities, repository interfaces, one usecase per action  │
├─────────────────────────────────────────────────────────────┤
│ Data                                                           │
│   — repository impls, local datasource (Drift DAO),          │
│     remote datasource (SAP/API client), mappers               │
├─────────────────────────────────────────────────────────────┤
│ Core (infrastructure, shared by every feature)                │
│   database · network · sync · workflow · security · session   │
│   · di · logging · monitoring                                 │
└─────────────────────────────────────────────────────────────┘
```

Layer discipline (presentation → domain → data, inward dependencies only) is already well-practiced in the codebase — **no layering violations were found in review**. The architectural risk is not misplaced code; it's that `core/` is largely stubbed, so each feature has been reinventing persistence instead of depending on shared infrastructure. Closing that gap is the entire point of `docs/blueprint/migration-plan.md`.

---

## 3. The four persistence layers

Every piece of data in the app is assigned to exactly one of four stores, by sensitivity and shape. This matrix is a hard boundary, not a preference — see `docs/skills/security.md` §3 for the "never store X in Y" rules that back it.

| Layer | Store | Holds | Encrypted |
|---|---|---|---|
| **1. Relational business data** | Drift (single DB, SQLite under the hood) | depots, products, routes, visits, orders, quotations, sync queue, audit log — all structured business/transactional data | ✅ via SQLCipher-equivalent encryption at rest (see `docs/blueprint/local-storage-architecture.md`) |
| **2. Non-sensitive preferences** | Hive | `onboarding_complete`, UI filters, feature flags, cached lookups the user can regenerate | Not required — enforce by review that tokens/PII never land here |
| **3. Secrets** | `flutter_secure_storage` (iOS Keychain / Android Keystore) | access token, refresh token, cached user JSON, the device encryption key | ✅ hardware-backed |
| **4. Media / files** | Native filesystem, app-sandboxed directory | photos, signed documents, attachments — **only a path/reference is stored in Drift**, never the binary | ✅ file-level encryption (Phase 5) |

This separation is deliberate: secrets never touch Drift or Hive; large binaries never touch the relational DB (keeps it small and fast); and the two lightweight stores (Hive, secure storage) stay lightweight because only small, well-scoped values live there. Full detail on Layer 1 is in `docs/blueprint/local-storage-architecture.md`; Layer 4 lifecycle (upload-then-purge, size caps, orphan GC) is a Phase 5 deliverable — see `docs/blueprint/migration-plan.md`.

---

## 4. Domain / feature map and dependency rule

```
Core Infra (Database + Encryption + SecureStorage + Network + Sync + Session)
  └─ Authentication → Session/AuthGuard
       └─ Localization + Shell + Splash + AppCoach
            └─ Organization/User/Territory/Warehouse (RBAC — gap, see §6)
                 ├─ Depot/Contact
                 ├─ Catalog/Product/PriceBook
                 ├─ Lead/Opportunity → Visit/Route
                 └─ Quotation/Sales Order
                      └─ Sync Engine → SAP Client → Revenue/Reporting → Dashboard → Notification
   Attachment/Media, Workflow (resumable state), and Audit sit alongside
   the entity features they serve, depending only on Core Infra.
```

**Rule, no exceptions**: a module may not go to production before every dependency above it in this graph exists in production. Concretely, no feature's `data/local` datasource may be implemented against a Drift table that hasn't shipped; sync-aware UI may not be built ahead of the sync engine states it renders; nothing depends on the encrypted database until Sprint 1 (`docs/blueprint/migration-plan.md`) is complete.

Per-domain offline/sync posture (what's local-only vs. pulled vs. pushed) is cataloged in `docs/blueprint/offline-architecture.md` §4.

---

## 5. Target folder structure

```
lib/
├── core/
│   ├── config/            env.dart + env.g.dart (Envied — see DATABASE_GUIDE.md, SECURITY.md)
│   ├── database/
│   │   ├── drift/         app_database.dart · tables/ · daos/ · migrations/
│   │   ├── hive/          preference boxes (non-sensitive only)
│   │   ├── secure/        dynamic_key_store.dart · key_derivation.dart
│   │   └── files/         encrypted_file_store.dart (Layer 4)
│   ├── network/           connectivity_service.dart · sap_client.dart · interceptors
│   ├── sync/               sync_engine.dart · conflict_manager.dart · sync_queue/
│   ├── workflow/           workflow_session_service.dart · resume_router
│   ├── security/           root/tamper/biometric detectors (Phase 8)
│   ├── di/  error/  usecase/  utils/  session/  theme/
│   └── logging/  monitoring/
├── features/<domain>/{presentation,domain,data}
├── shared/  widgets/  services/
└── main.dart
test/ · integration_test/ · scripts/ · ci/
```

Existing feature triads (`data/domain/presentation` per feature) are retained as-is. The migration work is entirely about replacing each feature's private `sqflite` local datasource with a shared Drift DAO from `core/database/drift/daos/` — feature code above the datasource boundary should not need to change. See `docs/blueprint/migration-plan.md` §Phase 8 / Phase 2 (Schema + DAOs).

---

## 6. Known architectural gaps (tracked, not yet built)

These are missing pieces the current UI-complete demo does not have, ranked by why they matter architecturally (business-impact prioritization and effort estimates live in `docs/blueprint/migration-plan.md`):

- **Application/orchestration layer** — cross-feature flows (e.g. "convert lead → quotation → order") currently have no dedicated home above individual feature usecases.
- **RBAC (Organization/Role/Permission)** — no domain model yet; needed before any permission-gated feature ships.
- **Unified remote/SAP gateway** — `core/network/sap_client.dart` is an empty stub; all SAP calls are mocked today.
- ~~**Formalized DI**~~ — ✅ **resolved (2026-07-15)**. `get_it` now follows `docs/skills/engineering-standard.md` §5: each feature exposes one `<feature>_injection.dart` at its root declaring `register<Feature>Feature(GetIt sl)`, all called from a single app-level entrypoint in `core/di/`. Remaining nit: that entrypoint is named `initDependencies()`, not `configureDependencies()` as §5's prose implies — harmonize the name or the doc.
- **Structured, PII-free logging and crash reporting** — effectively absent; see `docs/skills/security.md` §7.
- **Import-boundary enforcement** — no lint currently stops one feature from importing another's `data/` layer.

---

## 7. Clean Architecture validation (current scorecard)

| Layer | Present in code | Verdict |
|---|---|---|
| Presentation (BLoC) | Yes | ✅ Disciplined |
| Domain (entities/usecases) | Yes | ✅ One usecase per action |
| Repository (contracts) | Partial | ⚠️ Complete the missing contracts |
| Datasource (local/remote) | Yes | ✅ Migrate local side to Drift DAOs |
| Remote API / SAP | Stub (`sap_client.dart` 0-byte) | ❌ Build the gateway |
| Local DB / storage | ⚠️ **Mid-migration** — encrypted Drift DB exists and owns depots/catalog/cart; **2 plaintext sqflite DBs remain** (`routes.db`, Orders catalog DB). `depots.db` retired. | ❌ Finish the port — **T1.5** |
| Encryption at rest | ✅ Built — composite key + fail-closed cipher check + rotation | ✅ Done (T1.0–T1.4, T1.6) |
| Background services | Stub (`core/sync/*` 0-byte) | ❌ Build the sync isolate |
| Dependency direction | Inward | ✅ No violations found |

> **Scorecard reconciled 2026-07-15 @ `6622bfc`.** The "Local DB / storage — Fragmented (3 plaintext DBs)" row predated the encrypted-Drift landing and has been corrected above. The severity has *not* gone away: plaintext PII (a `depots` table and `location_samples` GPS traces in `routes.db`) is still on disk until **T1.5** purges it.

**Verdict**: the failure mode is absent shared infrastructure, not misplaced code. Enforce the good parts (layer discipline) with tooling (§6) so it can't erode as the team grows.

---

## 8. Related documents

- Persistence internals (schema, DAOs, encryption): `docs/blueprint/local-storage-architecture.md`
- Offline behavior and resumable state: `docs/blueprint/offline-architecture.md`
- Sync engine internals: `docs/blueprint/sync-architecture.md`
- Security controls behind every layer above: `docs/skills/security.md`
- How the gap between this target and current code gets closed, in order: `docs/blueprint/migration-plan.md`
