/// Read/erase access to a **legacy plaintext sqflite database** — `routes.db`
/// (T1.5) or `catalog.db` (T1.5b).
///
/// A seam, not indirection for its own sake, for two reasons:
///
/// 1. `sqflite` is platform-channel based and cannot open a database on the
///    host test VM, so without this the importers' mapping and reconciliation
///    rules — the parts that can actually lose a rep's data — would be
///    untestable outside an integration run. Reading rows out of SQLite is the
///    thin part; deciding what happens to them is not.
/// 2. `sqflite` has no web implementation. The seam is what lets the importers
///    stay in the shared codebase while `sqflite` never reaches a web compile
///    (`docs/blueprint/web-architecture.md`).
///
/// The interface is deliberately raw-map-shaped rather than model-shaped: the
/// legacy schemas are frozen history, and giving them typed models would imply
/// they still deserve maintenance. It gets deleted once both imports are
/// verified in production.
abstract interface class LegacySqliteSource {
  /// False on a fresh install that never ran the sqflite build — the import is
  /// then a no-op, not an error. Always false on web, where no legacy database
  /// can exist.
  Future<bool> exists();

  Future<List<Map<String, Object?>>> readTable(String table);

  /// Deletes every row of [table]. Used only after the import is verified
  /// (`docs/blueprint/migration-plan.md` T1.5: "old plaintext files purged after verified
  /// import").
  Future<void> deleteAllRows(String table);

  Future<void> close();
}
