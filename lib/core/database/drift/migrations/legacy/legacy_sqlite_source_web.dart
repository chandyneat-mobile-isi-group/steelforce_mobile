import 'package:steelforce/core/database/drift/migrations/legacy/legacy_sqlite_source.dart';

/// Web factory. Selected by the conditional export in
/// `legacy_source_factory.dart` — never compiled on Android/iOS.
LegacySqliteSource createLegacySqliteSource(String fileName) =>
    const AbsentLegacySource();

/// A legacy source that is always absent.
///
/// This is not a stub standing in for unfinished work — it is the correct and
/// complete behaviour. The legacy databases are `sqflite` files in the app's
/// native sandbox, written by earlier Android/iOS builds. A browser has never
/// run those builds and has no such file, so there is definitionally nothing to
/// import.
///
/// Reporting [exists] as false makes both importers take their existing
/// "fresh install" path — a documented no-op that leaves no marker, rather than
/// an error (`LegacyImportResult.noop`). No importer needed a web branch as a
/// result.
class AbsentLegacySource implements LegacySqliteSource {
  const AbsentLegacySource();

  @override
  Future<bool> exists() async => false;

  // The importers guard every call behind `exists()`, so the methods below are
  // unreachable in practice. They return empty / do nothing rather than
  // throwing: a defensive throw here would turn a future caller's ordering
  // mistake into a crash on the user's first launch, and there is no data to
  // protect by failing loudly.
  @override
  Future<List<Map<String, Object?>>> readTable(String table) async => const [];

  @override
  Future<void> deleteAllRows(String table) async {}

  @override
  Future<void> close() async {}
}
