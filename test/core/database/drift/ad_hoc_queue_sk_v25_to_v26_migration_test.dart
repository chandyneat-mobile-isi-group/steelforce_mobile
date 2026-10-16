import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v25 → v26: a queued ad hoc request carries the depot's SAP code (`sk`),
/// which is what `POST /mobile/visits/ad-hoc` is keyed on.
///
/// Purely additive. What matters is that a request already waiting in the
/// outbox survives the upgrade under its original `clientRequestId` — losing
/// it would lose a visit the rep has already asked for — and that it arrives
/// with no code rather than an invented one.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('isi_v26_migration');
    dbFile = File(p.join(tempDir.path, 'app.db'));
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  /// The current schema, with one queued request, rewound to v25: the outbox
  /// without its `sk` column.
  Future<void> createV25Fixture() async {
    final setup = AppDatabase(NativeDatabase(dbFile));
    await setup.into(setup.adHocVisitQueue).insert(
          AdHocVisitQueueCompanion.insert(
            id: 'req-v25',
            depotId: 'dep-9',
            depotName: 'Toul Kork Yard',
            createdAt: DateTime.utc(2026, 9, 29, 14, 32),
            attempts: const Value(2),
            lastErrorCode: const Value('Client.Network'),
          ),
        );
    await setup.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('ALTER TABLE ad_hoc_visit_queue DROP COLUMN sk;');
    raw.execute('PRAGMA user_version = 25;');
    raw.dispose();
  }

  test('the upgrade runs and lands on the current version', () async {
    await createV25Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });

  test('a request queued under v25 survives, with no SAP code', () async {
    await createV25Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final row = (await db.select(db.adHocVisitQueue).get()).single;
    // Same id: a replay must still be the same request.
    expect(row.id, 'req-v25');
    expect(row.depotId, 'dep-9');
    expect(row.depotName, 'Toul Kork Yard');
    expect(row.attempts, 2);
    expect(row.lastErrorCode, 'Client.Network');
    // Null, not guessed — the drain drops a row it cannot send correctly.
    expect(row.sk, isNull);
  });

  test('a new request stores its SAP code', () async {
    await createV25Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    await db.routeDao.enqueueAdHocVisit(AdHocVisitQueueCompanion.insert(
      id: 'req-v26',
      depotId: 'dep-10',
      sk: const Value('1000123'),
      depotName: 'Mekong Steel Supply',
      createdAt: DateTime.utc(2026, 9, 30, 9),
    ));

    final row = await (db.select(db.adHocVisitQueue)
          ..where((t) => t.id.equals('req-v26')))
        .getSingle();
    expect(row.sk, '1000123');
  });

  test('the migrated schema matches a fresh install exactly', () async {
    await createV25Fixture();
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
