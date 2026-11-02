// TODO(release-gate): demo-only data source; must never be registered in a release mobile build (USE_MOCK_DATA=false).
//
// [VisitSyncRemoteDataSource] for the static web demo: `POST /visits/push`
// answered from [MockVisitWorld], with no network call, so the Sync Center
// can be shown draining.
//
// Lenient like the real `/push`: check-ins and check-outs are applied to the
// visit they name (a conflict keeps the server's copy), every capture row is
// accepted, and only a row for a stop the demo never issued is discarded,
// with the server's `Visit.StopNotFound`. Photos are accepted too — live they
// wait for an upload path, which would strand every demo photo as pending.
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/my_visits/data/remote/mock/mock_visit_world.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_batch.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_push_result.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_sync_remote_data_source.dart';
import 'package:steelforce/features/my_visits/data/repositories/visit_repository_impl.dart';

class MockVisitSyncRemoteDataSource implements VisitSyncRemoteDataSource {
  const MockVisitSyncRemoteDataSource(this._world);

  final MockVisitWorld _world;

  @override
  Future<VisitPushResult> pushVisitData(VisitPushBatch batch) async {
    await MockLatency.tick();
    final accepted = <String>[];
    final discarded = <String>[];

    void sort(String id, String? stopId) =>
        (stopId == null || _world.find(stopId) != null ? accepted : discarded)
            .add(id);

    // Check-ins before check-outs, the order the server applies them in.
    for (final r in batch.checkIns) {
      _world.find(r.stopId)?.checkIn(r.id, r.timestamp);
      sort(r.id, r.stopId);
    }
    for (final r in batch.checkOuts) {
      _world.find(r.stopId)?.checkOut(r.timestamp);
      sort(r.id, r.stopId);
    }
    for (final r in batch.orderLines) {
      sort(r.id, r.stopId);
    }
    for (final r in batch.stockUpdates) {
      sort(r.id, r.stopId);
    }
    for (final r in batch.returns) {
      sort(r.id, r.stopId);
    }
    for (final r in batch.collections) {
      sort(r.id, r.stopId);
    }
    for (final r in batch.notes) {
      sort(r.id, r.stopId);
    }
    for (final r in batch.photos) {
      sort(r.id, r.stopId);
    }

    return VisitPushResult(
      acceptedIds: accepted,
      rejectedIds: const [],
      discardedIds: discarded,
      discardReasons: {
        for (final id in discarded) id: VisitErrorCodes.stopNotFound,
      },
      syncedAt: _world.now().toUtc(),
    );
  }
}
