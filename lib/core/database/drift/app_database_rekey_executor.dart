import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/secure/database_key_rotator.dart';

/// Drift-backed [DatabaseRekeyExecutor]: issues `PRAGMA rekey` against the live
/// [AppDatabase] connection so SQLCipher re-encrypts every page in place.
class AppDatabaseRekeyExecutor implements DatabaseRekeyExecutor {
  const AppDatabaseRekeyExecutor(this._db);

  final AppDatabase _db;

  @override
  Future<void> rekey(String rawKeyHex) {
    return _db.customStatement('PRAGMA rekey = "x\'$rawKeyHex\'";');
  }
}
