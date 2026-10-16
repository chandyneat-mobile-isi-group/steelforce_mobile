import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/data/remote/product_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/sync_result.dart';
import 'package:steelforce/features/order/domain/entities/sync_scope.dart';
import 'package:steelforce/features/order/domain/repositories/sync_repository.dart';

const _productsEntity = 'products';

/// The only repository allowed to touch [ProductRemoteDataSource] — every
/// read repository in this feature reads local-only, so this is where
/// "never download the full catalog again" and "pull only what changed"
/// actually live.
class SyncRepositoryImpl implements SyncRepository {
  const SyncRepositoryImpl({
    required ProductRemoteDataSource remote,
    required ProductLocalDataSource local,
    required NetworkInfo network,
  })  : _remote = remote,
        _local = local,
        _network = network;

  final ProductRemoteDataSource _remote;
  final ProductLocalDataSource _local;
  final NetworkInfo _network;

  static const _pageSize = 500;

  @override
  ResultFuture<DateTime?> lastSyncedAt() async {
    try {
      return Success(await _local.getLastSyncedAt(_productsEntity));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  /// Replaces the local category list with what the backend currently
  /// publishes.
  ///
  /// Categories are reference data, not a syncable entity: there are no
  /// tombstones for them, so the only way to notice one has been retired is to
  /// diff against the full list. Shared by both sync paths so they cannot
  /// drift — a retired category left behind orphans the join behind the
  /// product finder's opening screen.
  Future<void> _syncCategories() async {
    final categories = await _remote.fetchCategories();
    await _local.upsertCategories(categories);
    await _local.pruneCategoriesNotIn(
      categories.map((c) => c.id).toList(growable: false),
    );
  }

  @override
  ResultFuture<SyncResult> runInitialSync(SyncScope scope) async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      await _syncCategories();

      var page = 0;
      var total = 0;
      while (true) {
        final result = await _remote.fetchInitial(
            scope: scope, page: page, pageSize: _pageSize);
        if (result.items.isNotEmpty) {
          await _local.upsertProducts(result.items);
          total += result.items.length;
        }
        if (!result.hasMore) break;
        page++;
      }

      final now = DateTime.now();
      await _local.setLastSyncedAt(_productsEntity, now);
      return Success(SyncResult(upserted: total, deleted: 0, syncedAt: now));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<SyncResult> runDeltaSync(SyncScope scope) async {
    if (!await _network.isConnected) return const Failed(NetworkFailure());
    try {
      final since = await _local.getLastSyncedAt(_productsEntity);
      if (since == null) return runInitialSync(scope);

      // Categories are refreshed on the delta path too, not just the initial
      // one. They are ~30 rows, and a device that had already synced would
      // otherwise never learn the taxonomy changed: it pulls changed products
      // happily and shows an empty category picker, because the products now
      // reference ids the local category table has never seen.
      await _syncCategories();

      final delta = await _remote.fetchDelta(scope: scope, since: since);
      if (delta.upserted.isNotEmpty) {
        await _local.upsertProducts(delta.upserted);
      }
      if (delta.deletedIds.isNotEmpty) {
        await _local.markDeleted(delta.deletedIds);
      }

      final now = DateTime.now();
      await _local.setLastSyncedAt(_productsEntity, now);
      return Success(SyncResult(
        upserted: delta.upserted.length,
        deleted: delta.deletedIds.length,
        syncedAt: now,
      ));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }
}
