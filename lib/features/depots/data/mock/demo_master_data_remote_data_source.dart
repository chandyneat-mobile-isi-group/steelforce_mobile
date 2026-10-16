/// The SAP Depot Helper lookups for a demo build.
///
/// Delegates the rows to [MockMasterDataRemoteDataSource], which is what a
/// live build also uses until the SAP gateway exists, and adds the one thing
/// a demo needs on top: it goes offline when the presenter switches the demo
/// network off, so the repository's cached-copy fallback is what runs.
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/remote/master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/data/remote/mock_master_data_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_item.dart';
import 'package:steelforce/features/depots/domain/entities/master_data_type.dart';

class DemoMasterDataRemoteDataSource implements MasterDataRemoteDataSource {
  const DemoMasterDataRemoteDataSource(
    this._network, {
    MasterDataRemoteDataSource rows = const MockMasterDataRemoteDataSource(),
  }) : _rows = rows;

  final DemoNetwork _network;
  final MasterDataRemoteDataSource _rows;

  @override
  Future<List<MasterDataItem>> fetch(MasterDataType type) async {
    try {
      await _network.roundTrip();
    } on ApiException {
      // This contract speaks typed failures, not transport exceptions — the
      // repository's stale-cache fallback catches only `Failure`.
      throw const NetworkFailure();
    }
    return _rows.fetch(type);
  }
}
