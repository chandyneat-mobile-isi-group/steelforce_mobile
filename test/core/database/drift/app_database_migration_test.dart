import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';

/// Exercises the migrator/registry (T1.4) against an in-memory NativeDatabase —
/// no SQLCipher required, so it runs on the host CI. The encryption wrapper is
/// covered separately on-device.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('reports the current schema version', () {
    expect(db.schemaVersion, kCurrentSchemaVersion);
  });

  test('onCreate builds the schema and records the version registry', () async {
    // Forces the lazy database to open → runs onCreate.
    final version =
        await db.appMetadataDao.getValue(SchemaMetadataKeys.schemaVersion);
    final createdAt =
        await db.appMetadataDao.getValue(SchemaMetadataKeys.createdAt);

    expect(version, '$kCurrentSchemaVersion');
    expect(createdAt, isNotNull);
    expect(DateTime.tryParse(createdAt!), isNotNull);
  });

  test('metadata DAO upserts idempotently (no duplicate rows)', () async {
    await db.appMetadataDao.setValue('probe', 'a');
    await db.appMetadataDao.setValue('probe', 'b');

    expect(await db.appMetadataDao.getValue('probe'), 'b');
    final all = await db.appMetadataDao.all();
    expect(all.keys.where((k) => k == 'probe').length, 1);
  });

  test('foreign key enforcement is enabled after open', () async {
    final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
    expect(result.data.values.first, 1);
  });

  test('getValue returns null for an unknown key', () async {
    expect(await db.appMetadataDao.getValue('nope'), isNull);
  });
}
