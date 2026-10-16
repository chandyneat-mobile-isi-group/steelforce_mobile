import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/database/drift/app_database.dart';

/// Guards the foreign keys the schema *deliberately keeps* — and, just as
/// importantly, the ones it deliberately removed.
///
/// ## Two separate hazards, one test file
///
/// **Hazard 1 — codegen silently drops constraints.** `drift_dev 2.31.0` +
/// `analyzer 10.2.0` emit **no** foreign keys from `references()`: the
/// reference resolves to nothing, no constraint is written, and no warning is
/// printed (`docs/blueprint/web-architecture.md` §8). Every constraint vanished on the next
/// `build_runner` run and the only symptom was a few behavioural tests a reader
/// in a hurry could dismiss as flaky. The survivors are therefore declared via
/// `customConstraints`, and the counts below are what stops that workaround
/// being removed without anyone noticing.
///
/// **Hazard 2 — constraints creeping back onto mirror tables.** ADR-011 removed
/// the foreign keys on tables that mirror backend state, because the backend
/// enforces those relationships before the row is ever sent and re-enforcing
/// them on-device destroyed data instead of protecting it. Re-adding one would
/// silently restore that data loss, so the absences are asserted explicitly.
///
/// ## Why it asserts on the live schema
///
/// Not on the table sources — they were correct the entire time; it was codegen
/// that dropped them. Not on `app_database.g.dart` either: because
/// `customConstraints` is an override on the *source* table class, the
/// generated `$…Table` subclass inherits it and the string never appears in
/// generated output. `sqlite_master` is the only place the truth is visible.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Map<String, String>> tableSql() async {
    final rows = await db
        .customSelect("SELECT name, sql FROM sqlite_master WHERE type='table'")
        .get();
    return {
      for (final r in rows)
        r.data['name'] as String: (r.data['sql'] as String?) ?? '',
    };
  }

  test('every foreign key the schema still declares reaches SQLite', () async {
    final sql = await tableSql();
    final total = sql.values.fold<int>(
      0,
      (sum, s) => sum + RegExp('FOREIGN KEY').allMatches(s).length,
    );

    expect(
      total,
      6,
      reason: 'Expected 6 foreign keys after ADR-011. Getting 0 means codegen '
          'dropped them again (docs/blueprint/web-architecture.md §8). Getting more means a '
          'constraint was re-added to a mirror table — read ADR-011 before '
          'changing this number, and do not simply update it to make a build '
          'pass.',
    );
  });

  test('the constraints that still earn their place are present', () async {
    final sql = await tableSql();

    // Catalog children. Products and their prices/stock arrive in one payload
    // from one endpoint, so a child can never reference a parent that has not
    // been written — there is no ordering hazard and nothing to lose.
    expect(sql['prices'], contains('REFERENCES products (id)'));
    expect(sql['stock'], contains('REFERENCES products (id)'));
    // Table is named 'favorites' (the class is ProductFavorites).
    expect(sql['favorites'], contains('REFERENCES products (id)'));
    expect(sql['recent_products'], contains('REFERENCES products (id)'));

    // Route-scoped telemetry. Nothing hard-deletes a route (sync upserts), so
    // these cascades never fire in normal operation, and they give correct
    // cleanup if a route is ever purged.
    expect(
      sql['location_samples'],
      contains('REFERENCES routes (id) ON DELETE CASCADE'),
    );
    expect(
      sql['fraud_flags'],
      contains('REFERENCES routes (id) ON DELETE CASCADE'),
    );
  });

  test('mirror tables carry no foreign keys (ADR-011)', () async {
    final sql = await tableSql();

    // Each of these caused, or would have caused, real data loss. The comment
    // on each is the failure it prevents -- see ADR-011 for the evidence.

    // Aborted the whole route write when one stop referenced a depot the
    // directory had not pulled yet: the rep lost the entire day, not one stop.
    expect(sql['route_stops'], isNot(contains('FOREIGN KEY')));

    // Cascaded from route_stops, which route sync replaces on every run --
    // silently deleting captured check-ins, notes and photos that had not been
    // pushed yet.
    for (final table in const [
      'visit_check_ins',
      'visit_check_outs',
      'visit_order_lines',
      'visit_stock_updates',
      'visit_returns',
      'visit_collections',
      'visit_notes',
      'visit_photos',
    ]) {
      expect(sql[table], isNot(contains('FOREIGN KEY')), reason: table);
    }

    // fraud_flags keeps route_id but must not regain stop_id: the same cascade
    // deleted compliance evidence on a routine route refresh.
    expect(sql['fraud_flags'], isNot(contains('REFERENCES route_stops')));

    // Depot children: an orphan here is invisible and self-heals on the next
    // sync, which is strictly better than failing the batch that carried it.
    for (final table in const [
      'depot_contacts',
      'depot_notes',
      'depot_activities',
      'depot_favorites',
      'depot_recent',
    ]) {
      expect(sql[table], isNot(contains('FOREIGN KEY')), reason: table);
    }

    // The route feed's own depot mirror is a leaf: nothing references it and
    // it references nothing.
    expect(sql['route_depots'], isNot(contains('FOREIGN KEY')));
  });

  test('enforcement is on, so the survivors are not decorative', () async {
    // A constraint in the DDL only does anything with `PRAGMA foreign_keys =
    // ON`, which the migration strategy sets in `beforeOpen`. This asserts the
    // two work together.
    final fk = await db.customSelect('PRAGMA foreign_keys;').get();
    expect(
      fk.first.data['foreign_keys'],
      1,
      reason: 'Foreign key enforcement is off; the constraints are decorative.',
    );
  });
}
