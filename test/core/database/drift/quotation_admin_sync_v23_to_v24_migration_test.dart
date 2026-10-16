import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

/// v24: quotations sync to the Admin backend. Additive, nullable columns only —
/// the one thing that must hold is that an installed v23 database upgrades
/// with every existing row intact and the new columns present.
void main() {
  late Directory dir;
  late File dbFile;

  const newQueueColumns = [
    'remote_quotation_id',
    'remote_number',
    'remote_status',
    'decision_reason',
    'remote_checked_at',
    'owner_user_id',
  ];

  setUp(() {
    dir = Directory.systemTemp.createTempSync('v24_migration');
    dbFile = File(p.join(dir.path, 'app.db'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  /// A v23 database with one quotation and one queue row: the current schema
  /// with the v24 columns dropped and `user_version` rewound.
  Future<void> createV23Fixture() async {
    final seed = AppDatabase(NativeDatabase(dbFile));
    await seed.customSelect('SELECT 1').get(); // forces onCreate
    await seed.close();

    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('ALTER TABLE quotations DROP COLUMN remote_id;');
    for (final c in newQueueColumns) {
      raw.execute('ALTER TABLE sync_queue DROP COLUMN $c;');
    }
    raw.execute('''
      INSERT INTO quotations (id, lines_json, subtotal, discount, tax, total,
        status, sap_draft_status, valid_until, created_at, updated_at)
      VALUES ('QT-1', '[]', 10, 0, 1, 11, 'saved', 'Draft Saved to SAP',
        '2026-10-01T00:00:00.000', '2026-09-01T00:00:00.000',
        '2026-09-01T00:00:00.000');
    ''');
    raw.execute('''
      INSERT INTO sync_queue (id, quotation_id, status, attempt_count,
        sap_document_number, created_at, updated_at)
      VALUES ('SQ-1', 'QT-1', 'accepted', 1, 'SAP-MOCK-1',
        '2026-09-01T00:00:00.000', '2026-09-01T00:00:00.000');
    ''');
    raw.execute('PRAGMA user_version = 23;');
    raw.dispose();
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table);').get();
    return {for (final r in rows) r.read<String>('name')};
  }

  test('v24 is still a registered step, not skipped by a later bump', () {
    // The exact pin moved on to `ad_hoc_visits_v24_to_v25_migration_test.dart`
    // with v25; it always lives with the newest migration. What stays here is
    // the weaker, still-useful claim: v24 must remain reachable, so a later
    // bump cannot quietly skip this step for a device upgrading from v23.
    expect(kCurrentSchemaVersion, greaterThanOrEqualTo(24));
  });

  test('v23 upgrades: new columns exist and existing rows survive', () async {
    await createV23Fixture();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);

    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    // Against [kCurrentSchemaVersion], not the literal 24: opening a v23
    // database walks every remaining step, so it lands on whatever the
    // newest version is. Pinning the literal here made the next bump fail
    // this test for no reason — the claim is that the upgrade completes.
    expect(version.data['user_version'], kCurrentSchemaVersion);

    expect(await columnsOf(db, 'quotations'), contains('remote_id'));
    expect(await columnsOf(db, 'sync_queue'), containsAll(newQueueColumns));

    final q = await db.customSelect('SELECT * FROM quotations').getSingle();
    expect(q.data['id'], 'QT-1');
    expect(q.data['remote_id'], isNull);

    final row = await db.customSelect('SELECT * FROM sync_queue').getSingle();
    expect(row.data['quotation_id'], 'QT-1');
    expect(row.data['status'], 'accepted');
    expect(row.data['remote_quotation_id'], isNull,
        reason: 'the mock submitter never reached a backend');
    expect(row.data['owner_user_id'], isNull);
  });

  test('replaying v24 over columns that already exist does not fail', () async {
    // A fixture built from the current schema and rewound — the shape every
    // migration fixture in this suite uses — meets columns that are there.
    final seed = AppDatabase(NativeDatabase(dbFile));
    await seed.customSelect('SELECT 1').get();
    await seed.close();
    final raw = sqlite.sqlite3.open(dbFile.path);
    raw.execute('PRAGMA user_version = 23;');
    raw.dispose();

    final db = AppDatabase(NativeDatabase(dbFile));
    addTearDown(db.close);
    final version = await db.customSelect('PRAGMA user_version;').getSingle();
    // Against [kCurrentSchemaVersion], not the literal 24: opening a v23
    // database walks every remaining step, so it lands on whatever the
    // newest version is. Pinning the literal here made the next bump fail
    // this test for no reason — the claim is that the upgrade completes.
    expect(version.data['user_version'], kCurrentSchemaVersion);
  });
}
