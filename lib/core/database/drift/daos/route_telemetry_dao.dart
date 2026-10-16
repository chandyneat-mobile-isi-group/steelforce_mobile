import 'package:drift/drift.dart';
import 'package:steelforce/core/database/drift/app_database.dart';
import 'package:steelforce/core/database/drift/tables/route_tables.dart';
import 'package:steelforce/core/database/drift/tables/syncable_table.dart';

part 'route_telemetry_dao.g.dart';

/// Scoped accessor for route telemetry: the GPS breadcrumb trail and the fraud
/// signals derived from it.
///
/// Grouped as one aggregate because they are written by the same subsystem
/// (location tracking + fraud detection during route execution) and are both
/// *push-only* — SAP never sends these back, so they have no pull path.
/// `docs/blueprint/sync-architecture.md` §4 classifies them as `telemetry`, the lowest drain
/// priority: a rep's check-in must never queue behind a backlog of GPS points.
///
/// Replaces the hand-written SQL in
/// `my_visits/data/local/location_sample_local_data_source.dart` (ADR-004).
@DriftAccessor(tables: [LocationSamples, FraudFlags])
class RouteTelemetryDao extends DatabaseAccessor<AppDatabase>
    with _$RouteTelemetryDaoMixin {
  RouteTelemetryDao(super.db);

  // ── Location samples ────────────────────────────────────────────────

  Future<void> insertSample(LocationSamplesCompanion sample) =>
      into(locationSamples).insertOnConflictUpdate(sample);

  /// Batch insert — the tracking service accumulates points and flushes them
  /// together, which is one transaction rather than N (`playbook` §9: no N+1).
  Future<void> insertSamples(List<LocationSamplesCompanion> samples) =>
      batch((b) => b.insertAllOnConflictUpdate(locationSamples, samples));

  Future<List<LocationSampleRow>> fetchSamples(String routeId) =>
      (select(locationSamples)
            ..where((t) => t.routeId.equals(routeId))
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  /// Samples still awaiting a push, oldest first.
  Future<List<LocationSampleRow>> fetchPendingSamples({int? limit}) {
    final query = select(locationSamples)
      ..where((t) => t.syncState.equals(SyncStates.dirty))
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  // ── Fraud flags ─────────────────────────────────────────────────────

  Future<void> insertFraudFlag(FraudFlagsCompanion flag) =>
      into(fraudFlags).insertOnConflictUpdate(flag);

  Future<List<FraudFlagRow>> fetchFraudFlags(String routeId) =>
      (select(fraudFlags)
            ..where((t) => t.routeId.equals(routeId))
            ..where((t) => t.deleted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

  Future<List<FraudFlagRow>> fetchPendingFraudFlags() => (select(fraudFlags)
        ..where((t) => t.syncState.equals(SyncStates.dirty))
        ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
      .get();

  // ── Post-push bookkeeping ───────────────────────────────────────────

  /// Marks rows confirmed by the server. Called by the sync engine *after* a
  /// successful push, never speculatively — a row marked synced that never
  /// landed is silently lost data.
  Future<void> markSamplesSynced(List<String> ids) {
    if (ids.isEmpty) return Future.value();
    return (update(locationSamples)..where((t) => t.id.isIn(ids))).write(
      const LocationSamplesCompanion(
        syncState: Value(SyncStates.synced),
        dirty: Value(false),
      ),
    );
  }

  Future<void> markFraudFlagsSynced(List<String> ids) {
    if (ids.isEmpty) return Future.value();
    return (update(fraudFlags)..where((t) => t.id.isIn(ids))).write(
      const FraudFlagsCompanion(
        syncState: Value(SyncStates.synced),
        dirty: Value(false),
      ),
    );
  }

  /// Deletes synced samples older than [before] — the GPS trail is the fastest
  /// growing table on the device and is worthless once pushed
  /// (`docs/blueprint/sync-architecture.md` §11 TTL purge). Never deletes unsynced rows.
  Future<int> purgeSyncedSamplesBefore(DateTime before) =>
      (delete(locationSamples)
            ..where((t) => t.syncState.equals(SyncStates.synced))
            ..where((t) => t.timestamp.isSmallerThanValue(before)))
          .go();
}
