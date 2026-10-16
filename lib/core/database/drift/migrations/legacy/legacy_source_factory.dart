/// Platform-selected factory for [LegacySqliteSource].
///
/// Same mechanism and rationale as `connection/database_connection.dart`: the
/// native implementation imports `sqflite` and `dart:io`, neither of which
/// exists on web, so the choice has to be made by the compiler rather than by a
/// runtime `kIsWeb` check.
///
/// Both sides expose `LegacySqliteSource createLegacySqliteSource(String
/// fileName)`. On web it always returns an [AbsentLegacySource], which makes
/// the importers no-op without either of them needing a platform branch.
library;

export 'legacy_sqlite_source_web.dart'
    if (dart.library.ffi) 'legacy_sqlite_source_native.dart';
