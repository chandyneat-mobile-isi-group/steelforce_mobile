import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/app_metadata_table.dart';

part 'app_metadata_dao.g.dart';

/// Scoped accessor for the infrastructure `app_metadata` key/value table — the
/// schema-version registry and migration bookkeeping store (T1.4). This is the
/// first concrete instance of the DAO pattern the blueprint mandates
/// (`core/database/drift/daos/`); feature DAOs follow the same shape in T2.
@DriftAccessor(tables: [AppMetadata])
class AppMetadataDao extends DatabaseAccessor<AppDatabase>
    with _$AppMetadataDaoMixin {
  AppMetadataDao(super.db);

  /// Reads a single metadata value, or `null` if the key is absent.
  Future<String?> getValue(String key) async {
    final row = await (select(appMetadata)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Inserts or updates a metadata value, stamping [AppMetadata.updatedAt].
  Future<void> setValue(String key, String value) {
    return into(appMetadata).insertOnConflictUpdate(
      AppMetadataCompanion.insert(
        key: key,
        value: value,
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Removes [key]; a no-op when it is absent.
  Future<void> deleteValue(String key) =>
      (delete(appMetadata)..where((t) => t.key.equals(key))).go();

  /// Snapshot of the whole registry (small; bookkeeping only).
  Future<Map<String, String>> all() async {
    final rows = await select(appMetadata).get();
    return {for (final r in rows) r.key: r.value};
  }
}
