// ignore_for_file: experimental_member_use
part of '../schema_migrations.dart';

/// Schema steps v31–v36.
/// Keyed by the version each upgrades *to*; see [_stepwiseMigrations].
final Map<int, SchemaMigrationStep> _stepsV31toV36 = <int, SchemaMigrationStep>{
  // v31: an outlet's SAP sales areas — credit limit and credit term days per
  // area — so the Sales tab shows them offline. Purely additive and nullable:
  // a depot synced under v30 simply has none until the next pull.
  31: (m, db) async {
    await _addColumnIfMissing(m, db, db.depots, db.depots.salesAreasJson);
  },

  // v32: plan visit steps worked offline — check-in, inventory photos,
  // check-out — waiting for the server. A new device-owned table, so purely
  // additive.
  32: (m, db) async {
    await _createTableIfMissing(m, db, db.planVisitOutbox);
  },
};
