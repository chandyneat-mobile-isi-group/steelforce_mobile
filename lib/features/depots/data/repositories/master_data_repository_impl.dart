import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/features/depots/data/local/master_data_cache.dart';
import 'package:steelforce/features/depots/data/remote/master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';
import 'package:steelforce/features/depots/domain/repositories/master_data_repository.dart';

/// Online-first master data with an offline fallback.
///
/// Read order for [fetch]:
///   1. offline            → cached copy if any, else [NetworkFailure]
///   2. remote             → write both cache entries, return fresh
///   3. remote failed      → cached copy if any, else rethrow the typed failure
///
/// The cache is never read ahead of the API while the device is online: the
/// lists come from the server for every session, and the copy is only what a
/// rep with no signal falls back on.
class MasterDataRepositoryImpl implements MasterDataRepository {
  const MasterDataRepositoryImpl({
    required MasterDataRemoteDataSource remote,
    required MasterDataCache cache,
    required NetworkInfo network,
  })  : _remote = remote,
        _cache = cache,
        _network = network;

  final MasterDataRemoteDataSource _remote;
  final MasterDataCache _cache;
  final NetworkInfo _network;

  @override
  Future<MasterDataResult> fetch(MasterDataType type) async {
    if (!await _network.isConnected) {
      final stale = _cache.readStale(type);
      if (stale != null) return _staleResult(type, stale);
      throw const NetworkFailure(
        message: 'No connection, and this list has not been downloaded yet.',
      );
    }

    return _fetchRemote(type);
  }

  @override
  Future<MasterDataResult> refresh(MasterDataType type) async {
    if (!await _network.isConnected) {
      final stale = _cache.readStale(type);
      if (stale != null) return _staleResult(type, stale);
      throw const NetworkFailure();
    }
    return _fetchRemote(type);
  }

  @override
  Future<void> clearCache() => _cache.clear();

  Future<MasterDataResult> _fetchRemote(MasterDataType type) async {
    try {
      final items = await _remote.fetch(type);
      await _cache.write(type, items);
      return MasterDataResult(
        items: items,
        fromCache: false,
        isStale: false,
        cachedAt: DateTime.now(),
      );
    } on Failure {
      // A typed failure still shouldn't strand the user if we hold any copy.
      // Rethrowing only when there is genuinely nothing to show keeps the
      // dropdown usable through a transient SAP outage.
      final stale = _cache.readStale(type);
      if (stale != null) return _staleResult(type, stale);
      rethrow;
    }
  }

  MasterDataResult _staleResult(
          MasterDataType type, List<MasterDataItem> items) =>
      MasterDataResult(
        items: items,
        fromCache: true,
        isStale: true,
        cachedAt: _cache.cachedAt(type),
      );
}
