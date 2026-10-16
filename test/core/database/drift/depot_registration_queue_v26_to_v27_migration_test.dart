import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v26 → v27: the depot registration outbox.
///
/// A new local-only table, so purely additive. What matters is that the
/// upgrade leaves every existing outbox alone — an ad hoc request already
/// waiting must keep its `clientRequestId` — and that the new table matches a
/// fresh install column for column.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_v27_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// The current schema, with one queued ad hoc request, rewound to v26: no
  /// registration outbox.
  Future<void> createV26Fixture() async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.routeDao.enqueueAdHocVisit(AdHocVisitQueueCompanion.insert(
      id: 'req-v26',
      depotId: 'dep-10',
      sk: const Value('1000123'),
      depotName: 'Mekong Steel Supply',
      createdAt: DateTime.utc(2026, 9, 30, 9),
    ));
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('DROP TABLE depot_registration_queue;');
    raw.execute('PRAGMA user_version = 26;');
    raw.dispose();
  }

  test('the upgrade runs and lands on the current version', () async {
    await createV26Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });

  test('an ad hoc request queued under v26 survives untouched', () async {
    await createV26Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final row = (await db.select(db.adHocVisitQueue).get()).single;
    expect(row.id, 'req-v26');
    expect(row.sk, '1000123');
  });

  test('the new outbox accepts a registration', () async {
    await createV26Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db.depotRegistrationQueueDao.insert(
      DepotRegistrationQueueCompanion.insert(
        id: 'reg-1',
        depotName: 'Toul Kork Yard',
        payload: '{"Name1":"Toul Kork Yard"}',
        status: 'queued',
        createdAt: DateTime.utc(2026, 10, 2, 8),
      ),
    );

    final row = (await db.depotRegistrationQueueDao.all()).single;
    expect(row.attachments, '[]');
    expect(row.attempts, 0);
    expect(row.depotId, isNull);
  });

  test('replaying the step on a database that has the table is safe', () async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.customSelect('SELECT 1;').get();
    await setup.close();
    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('PRAGMA user_version = 26;');
    raw.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);
    expect(await db.depotRegistrationQueueDao.count(), 0);
  });

  test('the migrated schema matches a fresh install exactly', () async {
    await createV26Fixture();
    final upgraded = AppDatabase(NativeDatabase(dbFile));
    final upgradedSql = await _schemaOf(upgraded);
    await upgraded.close();

    final freshFile = File(p.join(tempDir.path, 'fresh.db'));
    final fresh = AppDatabase(NativeDatabase(freshFile));
    final freshSql = await _schemaOf(fresh);
    await fresh.close();

    expect(upgradedSql, freshSql);
  });
}

/// Every table and index definition, normalised and ordered so two databases
/// built by different routes can be compared directly.
Future<List<String>> _schemaOf(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT sql FROM sqlite_master "
        "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY name;",
      )
      .get();
  return rows
      .map((r) => r.read<String>('sql').replaceAll(RegExp(r'\s+'), ' ').trim())
      .toList()
    ..sort();
}
