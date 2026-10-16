import 'package:drift/drift.dart';

/// The standard syncable-table columns mandated by `docs/blueprint/local-storage-architecture.md`
/// §3.1, shared via a mixin so they can never drift apart per table ("do not
/// invent alternate names per table" — `docs/skills/ai-engineering-playbook.md` §2).
///
/// Every table that participates in sync carries these. The documented
/// exceptions are pure local-only tables (`carts`/`cart_items`) and cursor
/// tables (`*_sync_meta`), which have nothing to push.
///
/// | Column | Purpose |
/// |---|---|
/// | `id` | TEXT/UUID primary key, **client-generated** so offline creates need no server round-trip (§3) |
/// | `updated_at` | Last local mutation; drives delta pulls and LWW comparison |
/// | `deleted` | Soft delete — a row is never hard-deleted while its deletion still needs to reach SAP |
/// | `sync_state` | `synced` / `dirty` / `syncing` / `conflict` (`docs/blueprint/sync-architecture.md` §5) |
/// | `server_revision` | Last known server version/ETag, for conflict detection |
/// | `dirty` | Convenience flag: a local write not yet confirmed synced |
mixin SyncableTable on Table {
  TextColumn get id => text()();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Defaults to `'dirty'` ([SyncStates.dirty]): a row created locally has, by
  /// definition, not yet reached the server. Pull-sync overwrites it to
  /// `'synced'`.
  ///
  /// The literal is intentional, not sloppiness: Drift's generator copies this
  /// expression verbatim into `app_database.g.dart`, which does not import this
  /// file, so a `Constant(SyncStates.dirty)` reference fails to compile there.
  /// `syncable_table_test.dart` asserts this literal still equals
  /// [SyncStates.dirty], so the two cannot drift apart silently.
  TextColumn get syncState => text().withDefault(const Constant('dirty'))();

  TextColumn get serverRevision => text().nullable()();

  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Canonical `sync_state` values (`docs/blueprint/sync-architecture.md` §5).
///
/// `SYNC_ENGINE.md` §3 warns against two parallel vocabularies — these names are
/// the single set used in code. The legacy sqflite `sync_status` column used
/// `'pending'`, which maps to [dirty] on import (T1.5).
class SyncStates {
  SyncStates._();

  static const String synced = 'synced';
  static const String dirty = 'dirty';
  static const String syncing = 'syncing';
  static const String conflict = 'conflict';

  /// The legacy `sync_status` value written by the sqflite route store.
  static const String legacyPending = 'pending';

  /// Maps a legacy sqflite `sync_status` value onto the canonical vocabulary.
  static String fromLegacy(String? legacy) => switch (legacy) {
        null => dirty,
        legacyPending => dirty,
        synced => synced,
        syncing => syncing,
        conflict => conflict,
        // Unknown value: treat as unsynced rather than assume it reached SAP —
        // re-pushing is safe (idempotency keys, SYNC_ENGINE §4), losing a
        // capture is not.
        _ => dirty,
      };
}
