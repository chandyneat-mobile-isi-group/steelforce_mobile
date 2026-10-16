// ignore_for_file: experimental_member_use
part of '../schema_migrations.dart';

/// Schema steps v25–v30: ad hoc visits, the depot registration outbox, and
/// whatever follows.
/// Keyed by the version each upgrades *to*; see [_stepwiseMigrations].
final Map<int, SchemaMigrationStep> _stepsV25toV30 = <int, SchemaMigrationStep>{
  // v25: a stop can exist without a planned window, and can say who added it.
  //
  // ## Why this is not purely additive
  //
  // An ad hoc visit has no planned arrival or departure — nobody scheduled it,
  // and the backend sends null rather than inventing a window the rep would
  // then be measured against. `planned_arrival` and `planned_departure` were
  // declared NOT NULL, so the row could not be stored at all.
  //
  // **SQLite has no `DROP NOT NULL`.** `ALTER TABLE` cannot relax a column
  // constraint, so the only way to make these two nullable is to rebuild the
  // table and copy the rows across, which is what drift's [TableMigration]
  // does. Reaching for `_addColumnIfMissing` here would silently do nothing and
  // the column would still reject nulls at runtime — the failure would then
  // surface as an aborted route-sync transaction on a rep's phone, taking down
  // their whole day rather than one stop.
  //
  // Nothing is transformed. Every existing row keeps its values and merely
  // stops being required to have them.
  //
  // ## Why the rebuild is safe to replay
  //
  // The migration fixtures build the *current* schema and rewind
  // `user_version`, so this step routinely meets a `route_stops` that is
  // already nullable and already has `visit_source`. `addColumn` is guarded the
  // usual way; the rebuild is naturally idempotent because it copies whatever
  // is there onto a table with the same shape.
  25: (m, db) async {
    // Additive: every existing stop is a Call Plan stop, which is what they
    // all are. Done first so the rebuild below copies a table that already
    // carries the column, rather than leaving drift to reconcile two changes.
    await _addColumnIfMissing(m, db, db.routeStops, db.routeStops.visitSource);

    // Not additive — see above. A rebuild that loses rows is the classic way
    // to wipe a rep's day, so the migration test opens a v24 database holding
    // stops and asserts every one survives with its values intact.
    await m.alterTable(TableMigration(db.routeStops));

    // The ad hoc outbox. New table, so `_createTableIfMissing` rather than a
    // bare `createTable`, which would abort the whole upgrade on replay.
    await _createTableIfMissing(m, db, db.adHocVisitQueue);
  },

  // v26: the ad hoc endpoint is keyed on the depot's SAP code (`sk`), not its
  // id, so a queued request has to carry the code to be replayable. Purely
  // additive and nullable — a row queued under v25 has no code, and the drain
  // drops it rather than inventing one.
  26: (m, db) async {
    await _addColumnIfMissing(m, db, db.adHocVisitQueue, db.adHocVisitQueue.sk);
  },

  // v27: the depot registration outbox. A new local-only table, so purely
  // additive — `_createTableIfMissing` keeps the step safe to replay against a
  // fixture that already holds it.
  27: (m, db) async {
    await _createTableIfMissing(m, db, db.depotRegistrationQueue);
  },

  // v28: live check-in / check-out (check-in-check-out-mobile.md §11). A
  // check-in records its route; a check-out records how the visit ended —
  // with an order (and which) or without (and why). Purely additive and
  // nullable: a check-out queued before v28 is sent as it is and the server
  // stores its outcome as `unknown`.
  28: (m, db) async {
    await _addColumnIfMissing(
        m, db, db.visitCheckIns, db.visitCheckIns.routeId);
    for (final column in [
      db.visitCheckOuts.checkInId,
      db.visitCheckOuts.outcome,
      db.visitCheckOuts.ordersJson,
      db.visitCheckOuts.noOrderReason,
      db.visitCheckOuts.noOrderNote,
    ]) {
      await _addColumnIfMissing(m, db, db.visitCheckOuts, column);
    }
  },
};
