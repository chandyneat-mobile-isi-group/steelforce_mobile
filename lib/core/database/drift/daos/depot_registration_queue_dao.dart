import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/depot_registration_queue_table.dart';

part 'depot_registration_queue_dao.g.dart';

/// The depot registration outbox (ADR-004: no feature holds a raw handle).
///
/// Every method is a single statement, so each transition is atomic on its own.
/// The row is the source of truth for what the replay has done: a crash between
/// two calls leaves the row describing the last step that landed, and the next
/// drain resumes from there.
@DriftAccessor(tables: [DepotRegistrationQueue])
class DepotRegistrationQueueDao extends DatabaseAccessor<AppDatabase>
    with _$DepotRegistrationQueueDaoMixin {
  DepotRegistrationQueueDao(super.db);

  Future<List<DepotRegistrationQueueRow>> all() =>
      (select(depotRegistrationQueue)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();

  Stream<List<DepotRegistrationQueueRow>> watchAll() =>
      (select(depotRegistrationQueue)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .watch();

  Future<DepotRegistrationQueueRow?> byId(String id) =>
      (select(depotRegistrationQueue)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<int> count() async {
    final c = depotRegistrationQueue.id.count();
    final row =
        await (selectOnly(depotRegistrationQueue)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<int> countIn(Set<String> statuses) async {
    final c = depotRegistrationQueue.id.count();
    final row = await (selectOnly(depotRegistrationQueue)
          ..addColumns([c])
          ..where(depotRegistrationQueue.status.isIn(statuses)))
        .getSingle();
    return row.read(c) ?? 0;
  }

  /// Persists a registration **before** anything else happens to it.
  Future<void> insert(DepotRegistrationQueueCompanion row) =>
      into(depotRegistrationQueue).insert(row);

  /// Moves a row from [from] to [to] and answers whether this caller got it.
  ///
  /// One conditional `UPDATE`, so it is atomic even when the foreground sync
  /// engine and the background worker drain at the same moment from different
  /// isolates: exactly one of them sees a row change and sends. Checking the
  /// status in Dart and then writing would let both send — and this endpoint
  /// has no idempotency key to absorb the second.
  Future<bool> claim(
    String id, {
    required String from,
    required String to,
    required DateTime at,
  }) =>
      (update(depotRegistrationQueue)
            ..where((t) => t.id.equals(id) & t.status.equals(from)))
          .write(DepotRegistrationQueueCompanion(
            status: Value(to),
            lastAttemptAt: Value(at),
          ))
          .then((changed) => changed == 1);

  /// Makes every row in [statuses] due now.
  Future<void> clearBackoff(Set<String> statuses) => (update(
          depotRegistrationQueue)
        ..where((t) => t.status.isIn(statuses)))
      .write(const DepotRegistrationQueueCompanion(nextAttemptAt: Value(null)));

  /// Applies a state transition to one row.
  Future<void> patch(String id, DepotRegistrationQueueCompanion changes) =>
      (update(depotRegistrationQueue)..where((t) => t.id.equals(id)))
          .write(changes);

  /// Deletes a row only while it is in one of [statuses], and answers whether
  /// it did. For the rep's actions: a row a drain has just claimed (`sending`,
  /// `uploadingPhotos`) must not vanish from under the request using it.
  Future<bool> removeIfIn(String id, Set<String> statuses) =>
      (delete(depotRegistrationQueue)
            ..where((t) => t.id.equals(id) & t.status.isIn(statuses)))
          .go()
          .then((deleted) => deleted == 1);

  Future<void> remove(String id) =>
      (delete(depotRegistrationQueue)..where((t) => t.id.equals(id))).go();
}
