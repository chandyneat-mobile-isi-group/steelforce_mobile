import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/sync_result.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';

/// The only thing in this feature allowed to talk to
/// [ProductRemoteDataSource] — every other repository reads local-only.
abstract interface class SyncRepository {
  ResultFuture<DateTime?> lastSyncedAt();

  /// Full first-time pull, scoped to [scope], paged into the local DB.
  ResultFuture<SyncResult> runInitialSync(SyncScope scope);

  /// Pulls only what changed since the last sync (products, prices, stock,
  /// deletions) — never re-downloads the full catalog.
  ResultFuture<SyncResult> runDeltaSync(SyncScope scope);
}
