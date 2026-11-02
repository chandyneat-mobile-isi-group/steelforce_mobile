import 'package:steelforce/core/session/session_scoped_store.dart';
import 'package:steelforce/core/sync/offline_data_prefetcher.dart';
import 'package:steelforce/core/sync/sync_engine.dart';

/// Stops session-owned sync work before the database and caches are cleared.
/// Both services wait for their active run to finish, so an old request cannot
/// write its result back after the reset transaction commits.
class SessionSyncStore implements SessionScopedStore {
  const SessionSyncStore({
    required SyncEngine engine,
    required OfflineDataPrefetcher prefetcher,
  })  : _engine = engine,
        _prefetcher = prefetcher;

  final SyncEngine _engine;
  final OfflineDataPrefetcher _prefetcher;

  @override
  String get debugName => 'background synchronization';

  @override
  Future<void> clearForSignOut() async {
    await Future.wait<void>([_engine.stop(), _prefetcher.stop()]);
  }
}
