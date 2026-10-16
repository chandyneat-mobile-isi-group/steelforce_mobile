// ignore_for_file: experimental_member_use
part of '../schema_migrations.dart';

/// Schema steps v19–v24: visit capture, the depot rename, and Admin sync.
/// Keyed by the version each upgrades *to*; see [_stepwiseMigrations].
final Map<int, SchemaMigrationStep> _stepsV19toV24 = <int, SchemaMigrationStep>{
  // v19: the notification inbox becomes a first-class local mirror.
  //
  // Purely additive — three new tables, nothing existing is touched, so an
  // upgrade cannot lose or rewrite a row. `IF NOT EXISTS` on the indexes keeps
  // the step re-runnable after a crash mid-upgrade
  // (`docs/blueprint/local-storage-architecture.md` §5); `createTable` is already idempotent-safe
  // here because these tables cannot exist below v19.
  //
  // ## Why the inbox needs storage at all
  //
  // `docs/feature/notification/README.md` §1: the inbox *is* the notification
  // and push is only an accelerator, because a push routinely never arrives —
  // a flat battery, a coverage hole, an OEM battery optimiser, a rotated FCM
  // token, or a P4 that is never pushed by design. A client whose only render
  // path is the FCM callback shows a rep less than half their work.
  //
  // ## Why it is in the encrypted database rather than Hive
  //
  // A notification title and body name a depot and a route, which is PII and
  // therefore belongs in the encrypted store, not a key-value cache
  // (`docs/skills/security.md` §3, `docs/blueprint/system-architecture.md` §3). The FCM payload is
  // deliberately thinner for the same reason (§9.2): a push renders on a locked
  // screen in front of whoever is holding the phone.
  //
  // ## Why three tables and not one
  //
  //  * `notifications` is a **pull-only mirror** and carries no `SyncableTable`
  //    bookkeeping: nothing here originates on the device, and the id is the
  //    server's own so a catch-up overlapping a push cannot duplicate a row.
  //  * `notification_action_queue` is the **outbox** — the discrete acts the rep
  //    performed. ADR-006 requires a state change and its queued call to commit
  //    in one transaction, which is what `NotificationDao` enforces; a visible
  //    acknowledgement with no queued call is a route the supervisor still
  //    believes was never acknowledged.
  //  * `notification_sync_meta` holds the cursor and the reconciled counts, in
  //    the same database as the rows so sign-out drops all three together. A
  //    cursor that outlives its rows asks for "changes since" a point whose rows
  //    are gone, receives an empty delta, and leaves a permanently blank inbox
  //    with no error anywhere.
  //
  // No foreign keys, per ADR-011 — and here the reason is concrete rather than
  // precautionary: a push can land before the catch-up page that carries its
  // notification, so a queue row can legitimately reference a row this device
  // has not stored yet. Enforcing the constraint would abort that write and
  // lose the rep's acknowledgement instead of harmlessly orphaning a row.
  19: (m, db) async {
    // Guarded, not a bare `createTable`. [SchemaMigrationStep] requires every
    // step to be idempotent-safe, and `CREATE TABLE` is not: SQLite fails the
    // whole upgrade with "table already exists", which on a real device leaves
    // the user on a database that will not open.
    //
    // That is not hypothetical — it is how the migration fixtures work. They
    // build the *current* schema with Drift's own DDL and then rewind
    // `user_version`, deliberately, so a fixture cannot drift from reality. Every
    // replayed step therefore meets objects that already exist. Steps 10, 11 and
    // 15 guard the same hazard the same way.
    await _createTableIfMissing(m, db, db.notifications);
    await _createTableIfMissing(m, db, db.notificationActionQueue);
    await _createTableIfMissing(m, db, db.notificationSyncMeta);
  },
  // v20: the bundled Cambodian administrative gazetteer.
  //
  // The tables are created empty. Populating them is the seed importer's job
  // (`GeoSeedAssetLoader`), not the migrator's, for two reasons: reading a
  // 1.3 MB asset and inserting 16,000 rows inside `onUpgrade` would block the
  // first frame on the launch that happens to upgrade, and a migration that
  // depends on an asset bundle cannot be replayed by the schema fixtures,
  // which have no Flutter binding. The importer runs after startup and is
  // idempotent, so an interrupted seed simply re-runs.
  20: (m, db) async {
    await _createTableIfMissing(m, db, db.geoProvinces);
    await _createTableIfMissing(m, db, db.geoDistricts);
    await _createTableIfMissing(m, db, db.geoCommunes);
    await _createTableIfMissing(m, db, db.geoVillages);
  },
  // v21: record which language the depot book was synced under.
  //
  // Additive and nullable, so this is a pure `addColumn` with no data rewrite.
  // Null on every existing row, which reads as "unknown language" — the sync
  // repository treats that as a match rather than forcing every installed
  // device through a full resync on upgrade for a book that is almost
  // certainly already in the right language.
  //
  // Why it is needed: `shopName` is localised server-side against
  // `Accept-Language`, and the list summary carries no language-independent
  // name. A delta cannot fix a stale language because nothing changed
  // server-side, so without this the directory renders the language it was
  // first synced in forever.
  21: (m, db) async {
    await _addColumnIfMissing(
        m, db, db.depotSyncMeta, db.depotSyncMeta.syncedLanguage);
  },
  // v22: carry the rep's reason for checking in outside the geofence.
  //
  // Additive and nullable, so a pure `addColumn` with no data rewrite. Null on
  // every existing row is the correct reading: those check-ins were either
  // inside the geofence or recorded before an override was possible, and
  // neither has a reason to give.
  //
  // Why it is needed: the override was built end to end — the event, the bloc,
  // the entity, the row mapper and the push payload all carry
  // `overrideReason` — but the column was never added, so
  // `visit_drift_mappers.dart` referenced a field the generated row did not
  // have and the whole app stopped compiling.
  22: (m, db) async {
    await _addColumnIfMissing(
        m, db, db.visitCheckIns, db.visitCheckIns.overrideReason);
  },

  // v23: the customer -> depot rename reaches the physical schema.
  //
  // The rename itself is NOT done here. It runs in [_renameLegacyDepotSchema],
  // before the stepwise loop, because every step above was rewritten in place
  // to say `db.depots`: a device on v10 runs steps 11..22, and each of those
  // would hit `ALTER TABLE depots` on a database whose table is still called
  // `customers`. Renaming first is what makes every starting version land on
  // the same schema.
  //
  // This entry exists so the version bump has a matching step, as the contract
  // on [kCurrentSchemaVersion] requires, and so the explanation sits next to
  // the number it belongs to.
  23: (m, db) async {},

  // v24: quotations sync to the Admin backend instead of a mock SAP service.
  //
  // Additive and nullable only — no data rewrite, nothing dropped. Existing
  // queue rows read as "the backend has never seen this", which is true: the
  // old submitter was a mock, so no row was ever really submitted.
  //
  //   * `quotations.remote_id` links a local quotation to its server document.
  //   * `sync_queue.remote_*` / `decision_reason` hold the review state read
  //     back from the backend.
  //   * `sync_queue.owner_user_id` scopes a queued push to the rep who made it.
  24: (m, db) async {
    await _addColumnIfMissing(m, db, db.quotations, db.quotations.remoteId);
    for (final column in [
      db.syncQueue.remoteQuotationId,
      db.syncQueue.remoteNumber,
      db.syncQueue.remoteStatus,
      db.syncQueue.decisionReason,
      db.syncQueue.remoteCheckedAt,
      db.syncQueue.ownerUserId,
    ]) {
      await _addColumnIfMissing(m, db, db.syncQueue, column);
    }
  },
};
