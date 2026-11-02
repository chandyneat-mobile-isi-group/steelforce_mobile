import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_result.dart';
import 'package:steelforce/features/my_visits/domain/entities/route_sync_scope.dart';
import 'package:steelforce/features/my_visits/domain/repositories/route_sync_repository.dart';

/// The route pull, as the practice dashboard reaches it.
///
/// The practice route is built in memory, so there is nothing to pull: a sync
/// started from the practice dashboard makes no request and writes nothing,
/// and reports an empty, successful pull. The real watermark is read as-is
/// (it is a read, and true), so the dashboard does not mistake the lesson for
/// a first launch.
///
/// Once [PracticeWorld.isClosed], every call goes to the real repository.
class PracticeRouteSyncRepository implements RouteSyncRepository {
  PracticeRouteSyncRepository(this._real, this._world);

  final RouteSyncRepository _real;
  final PracticeWorld _world;

  bool get _live => !_world.isClosed;

  Result<RouteSyncResult> get _nothingPulled => Success(
      RouteSyncResult(upserted: 0, deleted: 0, syncedAt: DateTime.now()));

  @override
  ResultFuture<DateTime?> lastSyncedAt() => _real.lastSyncedAt();

  @override
  ResultFuture<RouteSyncResult> runInitialSync(RouteSyncScope scope) async {
    if (!_live) return _real.runInitialSync(scope);
    return _nothingPulled;
  }

  @override
  ResultFuture<RouteSyncResult> runDeltaSync(RouteSyncScope scope) async {
    if (!_live) return _real.runDeltaSync(scope);
    return _nothingPulled;
  }
}
