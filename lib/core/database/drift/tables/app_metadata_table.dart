import 'package:drift/drift.dart';

/// A tiny key/value table that seeds the encrypted database with a real schema
/// object (Drift requires at least one table) and doubles as the place the
/// migrator (T1.2) records schema bookkeeping — e.g. the version the store was
/// created at, last migration timestamp, or a one-time data-migration marker.
///
/// Feature tables are added to the same database in later tasks (T1.3 / T2);
/// this table is intentionally infrastructure-only, never business data.
class AppMetadata extends Table {
  @override
  String get tableName => 'app_metadata';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {key};
}
