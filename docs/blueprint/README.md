# Blueprint — How this application is architected

> **Purpose:** what exists in this system, why it exists, how the parts
> communicate, and where the boundaries are.
> **Not here:** reusable engineering technique ([../skills/](../skills/)),
> per-feature implementation detail ([../feature/](../feature/)), or business
> requirements ([../requirement/](../requirement/)).

---

## The documents

### System

| Document | Scope |
|---|---|
| [system-architecture.md](system-architecture.md) | Layers, dependency graph, folder structure, `core/` inventory, known gaps. **Start here.** |
| [feature-architecture.md](feature-architecture.md) | The feature census — every module, its layer sizes, and what it owns. The fastest orientation map for an agent. |
| [navigation-architecture.md](navigation-architecture.md) | Route table, `MainShell` tabs, deep links, resumable-workflow dispatch. |

### Data & connectivity

| Document | Scope |
|---|---|
| [local-storage-architecture.md](local-storage-architecture.md) | The single encrypted Drift database — schema, DAOs, migrations, composite key derivation, rotation. |
| [offline-architecture.md](offline-architecture.md) | Behaviour with no / intermittent / recovering connectivity; per-domain offline posture. |
| [sync-architecture.md](sync-architecture.md) | Sync-queue lifecycle, retry and backoff, priority, dead-letter queue, conflict resolution. |
| [authentication-architecture.md](authentication-architecture.md) | Session state machine, protected-API gate, interceptors, 401 handling, boot & navigation, guest-first gating. |

### Platform

| Document | Scope |
|---|---|
| [device-integration.md](device-integration.md) | Location, camera, scanner, microphone, notifications, files — permissions, platform support, failure behaviour. |
| [web-architecture.md](web-architecture.md) | The Flutter Web target as **built** — conditional imports, in-memory persistence, deployment. |
| [performance-audit.md](performance-audit.md) | Measured performance findings with root causes and a remediation roadmap. |

### Roadmaps

| Document | Scope |
|---|---|
| [master-plan.md](master-plan.md) | Full architecture analysis against the baseline blueprint; phase and sprint spine. |
| [migration-plan.md](migration-plan.md) | Task-level `sqflite` → Drift roadmap with acceptance criteria and a risk register. |
| [web-migration-plan.md](web-migration-plan.md) | The web plan as written before the work. Historical — [web-architecture.md](web-architecture.md) describes what shipped and wins on any conflict. |

### Assets

- [reference/enterprise-crm-architecture-blueprint.pdf](reference/enterprise-crm-architecture-blueprint.pdf) — the authoritative baseline spec, v2026.1.0.
- [diagrams/](diagrams/) — sync-lifecycle and SAP-integration diagrams.

---

## Architecture in one picture

```
┌─────────────────────── presentation ────────────────────────┐
│  Screens · Widgets · BLoC / Cubit  (flutter_bloc)           │
└───────────────────────────┬─────────────────────────────────┘
                            │ depends on ↓ only
┌───────────────────────────▼─────────────────────────────────┐
│  domain    Entities · UseCases · Repository *interfaces*    │
│            Pure Dart — no Flutter, no Drift, no dio         │
└───────────────────────────┬─────────────────────────────────┘
                            │ implemented by ↓
┌───────────────────────────▼─────────────────────────────────┐
│  data      Repository impls · remote datasources · mappers  │
└───────────────────────────┬─────────────────────────────────┘
                            │ persists / fetches via ↓
┌───────────────────────────▼─────────────────────────────────┐
│  core/     AppDatabase (Drift, SQLCipher) · DAOs · dio +    │
│            interceptors · SessionManager · DI (get_it) ·    │
│            connectivity · notifications · localization      │
└─────────────────────────────────────────────────────────────┘
```

Dependencies point inward only. A feature never imports another feature's
`data/` layer. See [../adr/ADR-0003-repository-pattern.md](../adr/ADR-0003-repository-pattern.md)
and [../adr/ADR-0004-drift-dao-pattern.md](../adr/ADR-0004-drift-dao-pattern.md).

---

## Verified stack

Read off `pubspec.yaml` and `lib/` on 2026-08-27 (Flutter 3.44.9):

| Concern | Actual |
|---|---|
| State management | `flutter_bloc` 8.x — BLoC + Cubit, `bloc_concurrency` for droppable events |
| Navigation | `Navigator` 1.0 + `onGenerateRoute`; 16 named routes in `lib/routes/app_routes.dart` |
| DI | `get_it` — one `injection_container.dart` plus per-feature `*_injection.dart` |
| Relational storage | **Drift** on a single encrypted database, `isi_secure.db` |
| Encryption | `sqlcipher_flutter_libs` 0.6.x, fail-closed (`PRAGMA cipher_version` asserted) |
| Non-sensitive prefs | Hive |
| Secrets | `flutter_secure_storage` — tokens, cached user, DB device key only |
| Networking | `dio` 5.x with auth / header / redacted-logging interceptors |
| Config | `Envied` → `lib/core/config/env.g.dart`, generated from `.env` |
| Push | `firebase_messaging` + `flutter_local_notifications`, no-op'd on web |
| Locales | `en`, `km` — JSON at `assets/lang/`, two complementary font families |

---

## Known documentation ↔ code divergences

Verified 2026-08-27 against branch `web` @ `142de9b`. Listed rather than
silently corrected, per [../skills/engineering-standard.md](../skills/engineering-standard.md) §11.

| # | Document claims | Code actually shows | Verdict |
|---|---|---|---|
| 1 | `.claude/CLAUDE.md` §1: *"Status (2026-07-15): Planning — no production code authorized"*; the same stamp is on `master-plan.md`, `migration-plan.md`, `system-architecture.md` | 855 Dart files, 107 test files, encrypted Drift DB at schema v20+, Web target shipped | **Status stamps are stale.** T1.3/T1.5 shipped; the plans were executed, not paused. |
| 2 | `.claude/CLAUDE.md` §2: *"persistence is three plaintext `sqflite` databases, there is no encryption"* | One encrypted DB (`isi_secure.db`); `sqflite` survives only in `migrations/legacy_*` importers, which is by design | **Stale.** The migration completed. |
| 3 | `.claude/CLAUDE.md` §2: *"`core/sync/*` is mostly 0-byte stub files"* | `sync_engine.dart`, `sync_queue_service.dart`, `conflict_manager.dart` are **1 byte each** | **Accurate.** Per-feature sync exists (depots, routes, visits, catalog); the unified engine of [../adr/ADR-0006-sync-engine.md](../adr/ADR-0006-sync-engine.md) does not. |
| 4 | `.claude/CLAUDE.md` §3: *"target `sqlite3mc` … not the legacy `sqlcipher_flutter_libs`"* | `sqlcipher_flutter_libs` ^0.6.0, imported in `encrypted_database.dart` | **CLAUDE.md contradicts [../adr/ADR-0008-sqlcipher-path.md](../adr/ADR-0008-sqlcipher-path.md) (Accepted).** The ADR wins; the on-disk format is locked as of T1.5. |
| 5 | `.claude/CLAUDE.md` §3: *"CI/CD: GitHub Actions + Fastlane, branches `main`/`develop`/`feature/*`/…"*; [../release/ci-cd.md](../release/ci-cd.md) describes the same pipeline | One workflow (`.github/workflows/deploy-web.yml`), no `fastlane/` directory, active branch `web` | **Aspirational, not built.** See [../release/README.md](../release/README.md). |
| 6 | `.claude/CLAUDE.md` §2 reviews branch `demo/app01` | Branches are `main` and `web` | **Stale branch reference.** |
| 7 | `pubspec.yaml` cites `docs/feature/geo-location/README.md` for the bundled gazetteer | The document did not exist | **Resolved 2026-08-27** — [../feature/geo-location/README.md](../feature/geo-location/README.md) written. |
| 8 | [performance-audit.md](performance-audit.md) cited `depot_stock_count_screen.dart` and `route_check_in_screen.dart` | Neither exists. The depot-stock audit UI is `inventory_visible/inventory_visible_screen.dart`; check-in is `stops_check_in_screen.dart` | **Paths corrected 2026-08-27.** |
| 9 | — | `DepotStockCountCubit` + `DepotStockCountState` are registered in `my_visits_injection.dart` but consumed by **no** screen; `inventory_visible_screen.dart` renders mock data instead | **Dead wiring.** Not a doc bug — a code finding, unresolved. |
| 10 | [web-architecture.md](web-architecture.md) claimed *"22/22 foreign keys"* | 6, asserted by `test/core/database/drift/foreign_key_schema_test.dart` | **Corrected 2026-08-27** — [../adr/ADR-0011-local-mirror-no-foreign-keys.md](../adr/ADR-0011-local-mirror-no-foreign-keys.md) removed the rest. |
| 11 | [../skills/graphify.md](../skills/graphify.md) §2 and `.claude/CLAUDE.md` assume the `graphify` CLI is available | Not installed on this machine (`command not found`); `graphify-out/` is present but was last built 2026-08-17 | **Tooling gap.** The graph is stale relative to the notification and BP-creation work. |

Items 1–6 are all in `.claude/CLAUDE.md`, which no ordinary doc change can fix —
it is the file every AI session reads first, so its stale "Planning / no code
authorized" framing actively misleads. Correcting it is the single
highest-value follow-up from this pass.
