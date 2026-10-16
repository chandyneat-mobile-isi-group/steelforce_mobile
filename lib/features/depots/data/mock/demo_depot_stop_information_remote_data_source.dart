/// `GET /api/v1/mobile/depots/{depotId}/stop-information`, from the demo book.
///
/// Accepts the platform id or the depot code, as the live route does, and
/// answers 404 for anything it does not hold — which the repository presents
/// as "not available", never as "deleted".
///
/// TODO(release-gate): demo-only, selected only when DataSourceMode.useMocks.
library;

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_directory.dart';
import 'package:steelforce/features/depots/data/mock/demo_depot_fixtures.dart';
import 'package:steelforce/features/depots/data/models/depot_stop_information_mapper.dart';
import 'package:steelforce/features/depots/data/remote/depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';

class DemoDepotStopInformationRemoteDataSource
    implements DepotStopInformationRemoteDataSource {
  const DemoDepotStopInformationRemoteDataSource(
    this._network,
    this._directory,
  );

  final DemoNetwork _network;
  final DemoDepotDirectory _directory;

  @override
  Future<DepotStopInformation> fetch(String depotId) async {
    await _network.roundTrip();
    final row = _directory.find(depotId);
    if (row == null) {
      throw const ApiException(
        ApiError(code: ApiErrorCodes.depotNotFound, statusCode: 404),
      );
    }
    final envelope = ApiEnvelope.fromBody({
      'success': true,
      'data': DemoDepotFixtures.stopInformationOf(row),
    });
    return DepotStopInformationMapper.fromData(envelope.data);
  }
}
