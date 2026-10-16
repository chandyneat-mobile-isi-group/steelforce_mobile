// ignore_for_file: experimental_member_use
part of 'schema_migrations.dart';

// Idempotent building blocks every step uses: a step may be replayed against
// a database that already has what it adds (see [_addColumnIfMissing]).

/// `createTable`, skipped when the table is already there.
///
/// See the note in the v19 step for why this is required rather than defensive:
/// a replayed `CREATE TABLE` aborts the entire upgrade.
Future<void> _createTableIfMissing(
  Migrator m,
  AppDatabase db,
  TableInfo<Table, dynamic> table,
) async {
  final existing = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?;",
    variables: [Variable<String>(table.actualTableName)],
  ).get();
  if (existing.isNotEmpty) return;
  await m.createTable(table);
}

/// `addColumn`, skipped when the column is already there.
///
/// [SchemaMigrationStep] requires every step to be idempotent-safe, and a bare
/// `addColumn` is not: SQLite fails the whole upgrade with
/// `duplicate column name`, which on a real device leaves the user on a
/// database that will not open.
///
/// That is not hypothetical. The migration fixtures build the *current* schema
/// with Drift's own DDL and then rewind `user_version` — deliberately, so the
/// fixture cannot drift from reality — which means every replayed step meets
/// columns that already exist. Any additive migration has to tolerate that, or
/// each new one silently breaks every fixture before it.
Future<void> _addColumnIfMissing(
  Migrator m,
  AppDatabase db,
  TableInfo<Table, dynamic> table,
  GeneratedColumn<Object> column,
) async {
  final existing = await db
      .customSelect('PRAGMA table_info(${table.actualTableName});')
      .get();
  final present =
      existing.any((row) => row.read<String>('name') == column.name);
  if (present) return;
  await m.addColumn(table, column);
}

Future<bool> _tableExists(AppDatabase db, String name) async {
  final rows = await db.customSelect(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?;",
    variables: [Variable<String>(name)],
  ).get();
  return rows.isNotEmpty;
}

Future<bool> _columnExists(AppDatabase db, String table, String column) async {
  final rows = await db.customSelect('PRAGMA table_info("$table");').get();
  return rows.any((row) => row.read<String>('name') == column);
}
