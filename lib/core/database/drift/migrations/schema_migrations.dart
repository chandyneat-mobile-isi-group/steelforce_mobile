// ignore_for_file: experimental_member_use
import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';

// The registry is assembled from version-range parts so no one file holds
// every migration ever written. Add a new step to the newest range (or open a
// new range file), bump [kCurrentSchemaVersion], and move the version pin in
// the newest migration test — together.
part 'legacy_depot_rename.dart';
part 'schema_migration_helpers.dart';
part 'steps/schema_steps_v02_v12.dart';
part 'steps/schema_steps_v13_v18.dart';
part 'steps/schema_steps_v19_v24.dart';
part 'steps/schema_steps_v25_v30.dart';

/// The single source of truth for the encrypted database's schema version.
/// Bump this by exactly one whenever a schema change ships, and add the matching
/// step to [_stepwiseMigrations].
const int kCurrentSchemaVersion = 28;

/// Keys under which the migrator records bookkeeping in `app_metadata`, so the
/// on-device schema history is auditable and a failed/partial upgrade is
/// detectable.
class SchemaMetadataKeys {
  SchemaMetadataKeys._();

  static const String schemaVersion = 'schema.version';
  static const String createdAt = 'schema.created_at';
  static const String lastMigratedAt = 'schema.last_migrated_at';
  static const String lastMigratedFrom = 'schema.last_migrated_from';
}

/// A single stepwise migration: transforms the schema from version `v-1` to `v`.
/// Must be idempotent-safe and self-contained.
typedef SchemaMigrationStep = Future<void> Function(
  Migrator migrator,
  AppDatabase db,
);

/// Ordered registry of stepwise migrations, keyed by the version they upgrade
/// *to*. v1 is the initial `createAll`, so the first entry here will be `2`.
///
final Map<int, SchemaMigrationStep> _stepwiseMigrations =
    <int, SchemaMigrationStep>{
  ..._stepsV2toV12,
  ..._stepsV13toV18,
  ..._stepsV19toV24,
  ..._stepsV25toV30,
};

/// Builds the [MigrationStrategy] for [db]: creates the schema on first run,
/// walks stepwise migrations on upgrade, records the version registry after
/// every transition, and enforces foreign keys on every connection.
MigrationStrategy buildMigrationStrategy(AppDatabase db) {
  return MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await db.appMetadataDao
          .setValue(SchemaMetadataKeys.schemaVersion, '$kCurrentSchemaVersion');
      await db.appMetadataDao.setValue(SchemaMetadataKeys.createdAt, _nowIso());
    },
    onUpgrade: (migrator, from, to) async {
      // Before any step. Every step below was rewritten in place to address
      // `depots`, so they only make sense once the tables carry that name —
      // see the v23 entry in [_stepwiseMigrations].
      await _renameLegacyDepotSchema(db);
      for (var v = from + 1; v <= to; v++) {
        final step = _stepwiseMigrations[v];
        if (step != null) {
          await step(migrator, db);
        }
      }
      await db.appMetadataDao.setValue(SchemaMetadataKeys.schemaVersion, '$to');
      await db.appMetadataDao
          .setValue(SchemaMetadataKeys.lastMigratedFrom, '$from');
      await db.appMetadataDao
          .setValue(SchemaMetadataKeys.lastMigratedAt, _nowIso());
    },
    beforeOpen: (details) async {
      await db.customStatement('PRAGMA foreign_keys = ON;');
    },
  );
}

String _nowIso() => DateTime.now().toUtc().toIso8601String();
