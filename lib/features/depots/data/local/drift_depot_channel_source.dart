import 'package:steelforce/core/database/drift/daos/depot_dao.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_channel_source.dart';

/// [DepotChannelSource] over the encrypted database.
class DriftDepotChannelSource implements DepotChannelSource {
  const DriftDepotChannelSource(this._dao);
  final DepotDao _dao;

  @override
  ResultFuture<String?> channelOf({String? depotCode, String? depotId}) async {
    try {
      return Success(
          await _dao.channelOf(code: depotCode?.trim(), id: depotId?.trim()));
    } catch (e) {
      return Failed(CacheFailure(message: 'Failed to read depot channel: $e'));
    }
  }
}
