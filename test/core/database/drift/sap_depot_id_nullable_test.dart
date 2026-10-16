import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/migrations/schema_migrations.dart';

/// `depots.sap_depot_id` was `text().unique()` and the API mapper
/// collapsed a missing SAP id to `''`. SQLite treats every NULL as distinct but
/// `''` as one value, so the *second* depot without a SAP id aborted the
/// whole sync batch with
/// `UNIQUE constraint failed: depots.sap_depot_id`.
///
/// That is the normal case, not an edge one: a depot registered in the field
/// has no SAP identity until it is approved and pushed, so a fresh territory is
/// mostly `PendingApproval` rows with none.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  DepotsCompanion row(String id, {String? sapId}) => DepotsCompanion.insert(
        id: id,
        sapDepotId: Value(sapId),
        depotCode: 'ISI-$id',
        shopName: 'Shop $id',
        ownerName: 'Owner',
        phone: '012345678',
        address: 'Street 1',
        province: 'Phnom Penh',
        district: 'Chroy Changvar',
        territory: 'PP-NORTH',
        latitude: 11.59,
        longitude: 104.94,
        creditLimit: 0,
        status: 'pendingApproval',
        assignedRepId: 'rep-1',
        assignedRepName: 'Rep',
        updatedAt: DateTime.utc(2026, 8, 13),
      );

  test('many depots may have no SAP id at once', () async {
    // The exact shape of the failure: ten synced rows, none yet in SAP.
    await db.batch((b) => b.insertAll(db.depots, [
          for (var i = 0; i < 10; i++) row('c$i'),
        ]));

    final stored = await db.select(db.depots).get();
    expect(stored, hasLength(10));
    expect(stored.every((c) => c.sapDepotId == null), isTrue);
  });

  test('a real SAP id is still unique', () async {
    // The constraint must keep doing its job for rows that do have one —
    // two depots pointing at the same ERP record is a genuine corruption.
    await db.into(db.depots).insert(row('a', sapId: 'SAP-100234'));

    await expectLater(
      db.into(db.depots).insert(row('b', sapId: 'SAP-100234')),
      throwsA(anything),
    );
  });

  test('a mix of linked and unlinked rows coexists', () async {
    await db.batch((b) => b.insertAll(db.depots, [
          row('a', sapId: 'SAP-1'),
          row('b'),
          row('c', sapId: 'SAP-2'),
          row('d'),
        ]));

    final stored = await db.select(db.depots).get();
    expect(stored, hasLength(4));
    expect(stored.where((c) => c.sapDepotId == null), hasLength(2));
  });

  test('the schema version covers this change', () {
    // The migration that makes the column nullable is v16; a build shipping
    // the nullable column without the bump would leave existing installs on
    // the old NOT NULL table.
    expect(kCurrentSchemaVersion, greaterThanOrEqualTo(16));
  });
}
