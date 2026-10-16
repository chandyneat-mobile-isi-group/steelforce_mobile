import 'dart:io';

import 'package:steelforce/core/database/drift/migrations/legacy/legacy_sqlite_source.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

/// Android/iOS factory. Selected by the conditional export in
/// `legacy_source_factory.dart` — never compiled on web.
LegacySqliteSource createLegacySqliteSource(String fileName) =>
    SqfliteLegacySource(fileName: fileName);

/// The real source, backed by a legacy plaintext sqflite file.
///
/// This is the **only** remaining `sqflite` usage in the app. It exists solely
/// to drain the two legacy databases into the encrypted Drift database on
/// devices upgrading from a pre-T1.5 build; nothing writes through it. Once
/// both imports are confirmed complete across the fleet, this file, its web
/// twin, the importers, and the `sqflite` dependency all go together.
class SqfliteLegacySource implements LegacySqliteSource {
  SqfliteLegacySource({required this.fileName});

  final String fileName;
  sqflite.Database? _db;

  Future<String> _path() async =>
      p.join(await sqflite.getDatabasesPath(), fileName);

  @override
  Future<bool> exists() async => File(await _path()).exists();

  /// Opens **read-only-ish**: no `onCreate`/`onUpgrade` is supplied, so this can
  /// never resurrect or migrate a legacy schema. If the file is gone, opening
  /// would create an empty database — hence the [exists] guard in the importers.
  Future<sqflite.Database> _open() async =>
      _db ??= await sqflite.openDatabase(await _path());

  @override
  Future<List<Map<String, Object?>>> readTable(String table) async {
    final db = await _open();
    // The legacy databases self-versioned independently, so a device on an
    // older build may genuinely lack a table. A missing table means "nothing to
    // import", not a failure — but any other error must surface.
    final present = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
      [table],
    );
    if (present.isEmpty) return const [];
    return db.query(table);
  }

  @override
  Future<void> deleteAllRows(String table) async {
    final db = await _open();
    await db.delete(table);
  }

  @override
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
