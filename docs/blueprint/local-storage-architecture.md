# Database Guide — Drift + DAO + Encryption

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> Persistence Layer 1 in `docs/blueprint/system-architecture.md` §3: the single encrypted relational database. Implements `docs/skills/engineering-standard.md`; the migration path from today's plaintext `sqflite` DBs is in `docs/blueprint/migration-plan.md`.

---

## 1. Locked decision

**Migrate to a single Drift database, encrypted at rest, with generated DAOs and one unified migrator.** The three existing per-feature plaintext `sqflite` databases (`catalog.db`, `depots.db`, `routes.db`) are ported into it; no plaintext database file ships. This is a Sprint-1, encryption-first priority — see `docs/blueprint/migration-plan.md` §Sprint 1 — because it closes the most severe finding from architecture review: **depot PII and revenue data currently sit in plaintext SQLite.**

Why a single DB instead of the current three: cross-feature transactions and joins are otherwise impossible (a checkout that touches cart, depot, and sync-queue rows can't be atomic across three separate database files), and operating three independently-versioned migrators is itself a reliability risk.

---

## 2. Encryption architecture

### 2.1 Key derivation chain

The database is never opened with a static, hardcoded, or purely-random key. The key is derived at runtime from two independent secrets, neither of which alone is enough to decrypt the database:

```
Env.dbSalt (compile-time, Envied-obfuscated)
        +
DeviceKey (256-bit CSPRNG, generated once per install,
           hardware-sealed in iOS Keychain / Android Keystore
           via DynamicKeyStore)
        │
        ▼
FinalKey = SHA256(Env.dbSalt + DeviceKey)   ← 32-byte key passed to the cipher
```

- **`Env.dbSalt`** comes from `Envied` (compile-time obfuscated config — see `docs/skills/security.md` §5). It is defense-in-depth, **not** a secret on its own: a reverse-engineered binary can recover it. It is safe only *because* it's combined with a device-bound key an attacker can't extract from the binary alone.
- **`DeviceKey`** is generated once via `DynamicKeyStore` and stored in the platform's hardware-backed keystore, never in Drift, Hive, or app files. Losing the device (without the salt) is not enough to derive the key; extracting the binary (without the device) is not enough either.
- **On plain `SHA256(salt + key)` instead of a password-stretching KDF (Argon2/PBKDF2)**: this is an accepted, documented deviation, not an oversight. Key-stretching KDFs exist to slow brute-force against a *low-entropy* human password. Here `DeviceKey` is already a 256-bit CSPRNG value — there is no low-entropy secret to stretch. An HKDF-based derivation is an acceptable future hardening (tracked P1) but is not required to close the current critical gap.
- **Rotation**: the key is never assumed permanent. A re-key routine (`PRAGMA rekey` equivalent) must exist from day one — see §6.

### 2.2 What was built first vs. what's correct — ✅ RESOLVED (2026-07-15)

*Historical:* an earlier pass (`DatabaseKeyManager`) stored one final random key directly in secure storage, with no salt/device-key split, and was flagged as a correction item.

**That correction has landed and was verified in code @ `6622bfc`.** `DatabaseKeyManager` no longer exists. The two-part split described in §2.1 is implemented: `DynamicKeyStore` (256-bit device key, hardware-sealed) + `KeyDerivation.deriveDatabaseKey` computing `sha256(Env.dbSalt + deviceKey)` hex-encoded, composed by `AppDatabaseKeyProvider` and injected at open time. `docs/blueprint/migration-plan.md` T1.1/T1.2 are **done**; this section is retained only as a record of the correction, not as outstanding work.

### 2.3 Implementation path — read before writing `AppDatabase`

> **DECIDED — see ADR-0008 (Accepted, 2026-07-15).** This project uses **`sqlcipher_flutter_libs`**. The comparison below is retained as background; the recommendation column is **superseded by ADR-008**. Do not switch paths without a superseding ADR — the on-disk format is locked as of T1.5.

The org's planning documents refer to this generically as "SQLCipher." Two implementation paths exist in the Drift ecosystem:

| Path | Package | Status |
|---|---|---|
| **Chosen (ADR-008)** | **`sqlcipher_flutter_libs`** | In production. Fail-closed cipher check + wrong-key check + `PRAGMA rekey` rotation all implemented and tested. The `legacy = 4` compatibility pragmas are not needed here: this codebase reads only databases it wrote itself. |
| Viable alternative (not chosen) | SQLite3MultipleCiphers (`sqlite3mc`), via Drift's `user_defines` hook | Drift's current upstream recommendation; simpler setup. Rejected for *sequencing* — adopting it would mean re-proving T1.3/T1.6 before T1.5 could remove plaintext PII. Revisit via a superseding ADR; cost is a one-time re-import. |

Recommended `pubspec.yaml` (workspace root):

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

Passphrase is supplied via the `setup` callback on `NativeDatabase`, **not** hardcoded:

```dart
NativeDatabase.createInBackground(
  databaseFile,
  setup: (rawDb) {
    rawDb.execute("PRAGMA key = '${finalKeyHex}';");
  },
);
```

**Mandatory runtime check**: after opening, query the `cipher` pragma and fail closed (refuse to proceed, surface an error) if it comes back empty — that means the database silently opened *unencrypted* because the cipher library wasn't linked, which is a critical-severity failure mode, not a cosmetic one. This check is the literal implementation of Sprint-1 acceptance criterion T1.3: "wrong key fails; `cipher_version` non-empty."

**Existing (plaintext) databases cannot be encrypted in place.** They must be imported into a *new* encrypted database file (one-time migration, not `PRAGMA rekey` on the old file) — see `docs/blueprint/migration-plan.md` T1.5.

~~Decide and record this choice as an ADR before T1.3 starts~~ — **done: ADR-0008 (Accepted).** Recorded retroactively; T1.3 had shipped on `sqlcipher_flutter_libs` before the ADR was written, a process gap logged in ADR-008's Context. The two paths remain functionally interchangeable at the schema/DAO level, so switching later is possible via a superseding ADR — but after T1.5 it costs a one-time re-import on every device.

---

## 3. Schema conventions

- `PRAGMA foreign_keys = ON` always — enforcement stays on for the constraints
  the schema still declares (see §3.0 for which those are).
- Primary keys are **UUID/text**, matching the rest of the app's ID scheme — do not introduce integer autoincrement IDs on syncable tables (this was a specific gap found in the current `ActiveWorkflow` table; do not repeat it).
- Indexes exist on every foreign key and on every column used in a `WHERE`/`ORDER BY` in a hot-path query. The current per-feature databases have ad hoc indexing; a full index audit against real query plans is due before Phase 2 closes.
- Full-text search (FTS4/FTS5) is used for catalog/product search, as it already is today — keep this pattern.

### 3.0 Mirror tables carry no foreign keys (ADR-011)

A table that mirrors backend-owned state **does not declare foreign keys**. The
backend enforces those relationships before the row is transmitted; re-enforcing
them on the device adds no correctness and turns ordinary conditions into data
loss. The device stores what it was sent and renders it.

Use this test when adding a table or a constraint:

| Situation | Foreign key? |
|---|---|
| Parent and child arrive in the **same payload from one endpoint** | **Yes** — no ordering hazard exists (e.g. `prices → products`) |
| Parent and child arrive from **different endpoints**, paged or scoped separately | **No** — the server never promised an arrival order (e.g. `route_stops → depots`) |
| The child is a **rep-captured row** (check-in, note, photo, collection, fraud flag) | **No** — never let a sync-driven parent delete first-hand field work |
| A cascade could fire during **normal sync** | **No** — sync must never be able to delete data as a side effect |

Two failures motivated this, both reproduced on the v17 schema: one unrecognised
depot aborted a whole route write (`SqliteException(787)`, zero stops
persisted), and the `visit_* → route_stops` cascade deleted unsynced check-ins
and notes whenever route sync refreshed a route. Full evidence and the surviving
constraint list: `docs/adr/ADR-0011-local-mirror-no-foreign-keys.md`.

`test/core/database/drift/foreign_key_schema_test.dart` asserts both directions —
that the six remaining constraints reach SQLite, and that the removed ones do not
creep back. Read the ADR before changing the expected count.

### 3.1 Standard syncable-table columns

Every table that participates in sync (i.e., almost everything except pure local-only tables like `carts`) carries these columns. This is currently **missing** from the schema and is one of the highest-value, easiest wins in the migration:

| Column | Type | Purpose |
|---|---|---|
| `id` | TEXT (UUID) | Primary key, client-generated so offline creates work without a server round-trip |
| `updated_at` | INTEGER (epoch ms) | Last local mutation time; drives delta pulls and LWW comparisons |
| `deleted` | BOOLEAN | Soft delete — rows are never hard-deleted while they might still need to sync a deletion to the server |
| `sync_state` | TEXT enum | `synced` / `dirty` / `syncing` / `conflict` (see `docs/blueprint/sync-architecture.md` §5 for the full state model) |
| `server_revision` | TEXT/INTEGER, nullable | Last known server-side version/ETag, used for conflict detection |
| `dirty` | BOOLEAN | Convenience flag: `true` whenever a local write hasn't yet been confirmed synced |

### 3.2 Table catalog (representative — full DDL is produced per table at build time)

| Group | Tables |
|---|---|
| Master | users, depots, products, categories, territories, warehouses, brands |
| Transactional | carts, cart_items, quotations, quotation_lines, sales_orders, routes, route_stops, visits/check_in/check_out, stock_counts, returns, collections, leads, revenue |
| Reference | off_visit_reasons, fraud_policies, product_grades/sizes, config_lookups |
| Security | device_registrations, auth_sessions, key_metadata |
| Workflow | workflow_session (+ identity/expiry/version fields — see `docs/blueprint/offline-architecture.md` §3), workflow_history |
| Sync | sync_queue, sync_dead_letter, sync_cursor |
| Audit | audit_log |
| Configuration | app_config, feature_flags, remote_thresholds |
| Logging | event_log, error_log |
| Notification | notifications, notification_state |
| Attachment | attachments (`id`, `owner_type`, `owner_id`, `path`, `sha256`, `bytes`, `encrypted`, `upload_state`, `created_at`) |

`carts`/`cart_items` are the deliberate exception to §3.1 — they are local-only and never sync (a cart is converted into a quotation, which *is* syncable, rather than syncing carts themselves).

---

## 4. DAO conventions

- One DAO per aggregate/table group (e.g. `DepotDao`, `RouteDao`, `SyncQueueDao`), generated via Drift codegen against the table definitions in `core/database/drift/tables/`.
- DAOs return typed Drift row classes to the data layer's mappers; mappers (not DAOs, not repositories) are responsible for converting rows to domain entities. This is a formalization of an existing gap — the current hand-written `*LocalDataSource` classes do runtime-only mapping with no compile-time safety, which Drift codegen fixes by construction.
- Any DAO method that writes to a syncable table must be callable **inside the same transaction** as the corresponding `sync_queue` insert — see `docs/blueprint/sync-architecture.md` §2. This typically means the DAO exposes both the entity-write method and is invoked from within a repository-level `db.transaction(...)` block, not that the DAO itself decides sync policy.
- No feature may hold a second, private `sqflite`/`Database` handle. All local reads/writes for any feature go through the shared `AppDatabase` and its DAOs — this is the concrete fix for "operational complexity of many DBs."

---

## 5. Migrations

- One `schemaVersion` on `AppDatabase`, one stepwise `onUpgrade`, registered in a schema-version registry — replacing the current per-DB self-versioning (`catalog.db`, `depots.db`, and `routes.db` each version independently today, with no shared framework and no migration tests, which review flagged as the top maintenance risk).
- Every migration step ships with a Drift schema test that runs the upgrade path against a fixture of the *previous* schema version and asserts data survives intact — migrations are tested before merge, not discovered broken in the field.
- Migrations must be idempotent and safe to re-run (a device that crashes mid-migration and restarts should not corrupt data or double-apply a step).
- Downgrade guard: a build must refuse to open a database with a `schemaVersion` higher than it knows about, rather than attempting to "migrate" backwards — this protects against a rollback deploy corrupting user data (see `docs/blueprint/migration-plan.md` DevOps rollback note).

---

## 6. Key rotation

- Rotation must be possible without data loss: re-key the database (via the cipher's re-key mechanism) to a new `FinalKey` derived from a freshly-rotated `DeviceKey` or updated salt, bump a version in `key_metadata`, and verify a successful re-open before discarding the old key material.
- `key_metadata` is a versioned table (see §3.2) tracking which key generation is currently active, so a partially-completed rotation is detectable and resumable rather than silently leaving the database half-migrated.
- This is a Sprint-1 P1 item (`docs/blueprint/migration-plan.md` T1.6) — not required to unblock the first encrypted release, but required before rotation can ever be exercised in production.

---

## 7. Transactions

- A "logically atomic" operation that touches more than one table (e.g., converting a quotation to a sales order and enqueueing its sync row) must be wrapped in a single Drift transaction. Under the old three-database split this was structurally impossible across DB boundaries; the single-DB migration is what makes it achievable, and every write path that used to be "per-DB only" should be revisited to use real transactions once ported.

---

## 8. Testing

Covered in full in `docs/skills/engineering-standard.md` §10; the database-specific tiers are:

- **DAO tests**: Drift in-memory database on host for fast query/constraint tests, plus on-device tests against the real encrypted file to catch cipher-specific behavior.
- **Migration tests**: run every `onUpgrade` step against a realistic fixture, assert no data loss.
- **Security tests**: opening with a wrong key must fail (not silently return an empty/garbage database); no plaintext database file may exist on disk after the app has run — both are gating checks in `docs/skills/security.md` §10.

---

## 9. Related documents

- Where this fits among the four persistence layers: `docs/blueprint/system-architecture.md` §3
- Encryption's place in the broader security program (Envied, cert pinning, OWASP mapping): `docs/skills/security.md`
- How mutations here connect to the sync queue: `docs/blueprint/sync-architecture.md` §2
- Step-by-step rollout of everything in this document: `docs/blueprint/migration-plan.md`

Sources consulted for the encryption implementation path: [Drift Encryption docs](https://drift.simonbinder.eu/platforms/encryption/), [sqlcipher_flutter_libs](https://pub.dev/packages/sqlcipher_flutter_libs), [Envied package](https://pub.dev/packages/envied).
