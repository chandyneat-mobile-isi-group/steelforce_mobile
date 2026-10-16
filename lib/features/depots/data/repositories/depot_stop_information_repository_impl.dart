import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/remote/depot_stop_information_remote_data_source.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';
import 'package:steelforce/features/depots/domain/repositories/depot_stop_information_repository.dart';

class DepotStopInformationRepositoryImpl
    implements DepotStopInformationRepository {
  const DepotStopInformationRepositoryImpl({
    required DepotStopInformationRemoteDataSource remote,
    required NetworkInfo network,
    required AppLogger logger,
  })  : _remote = remote,
        _network = network,
        _logger = logger;

  final DepotStopInformationRemoteDataSource _remote;
  final NetworkInfo _network;
  final AppLogger _logger;

  @override
  ResultFuture<DepotStopInformation> fetch(String depotId) async {
    if (depotId.trim().isEmpty) {
      return const Failed(DepotStopInformationUnavailableFailure());
    }

    // Offline is a normal state, not an error state (ADR-0002 §4). The stop
    // screen keeps rendering what the route sync already gave it.
    if (!await _network.isConnected) return const Failed(NetworkFailure());

    try {
      return Success(await _remote.fetch(depotId));
    } on ApiException catch (e) {
      // Ids are not logged: the depot id identifies a named outlet.
      _logger.error('depots.stopInformation.failed', fields: {
        'status': e.error.statusCode,
        'errorCode': e.error.code,
        'correlationId': e.error.correlationId,
      });

      if (e.error.statusCode == 404) {
        // "Does not exist" and "not entitled" arrive identically, by design —
        // distinguishing them would confirm an outlet exists to someone who is
        // not allowed to know. So neither is presented as "deleted".
        return const Failed(DepotStopInformationUnavailableFailure());
      }
      return Failed(ServerFailure(
        message: e.error.message ??
            'Could not load the outlet details. Please try again.',
        statusCode: e.error.statusCode,
      ));
    } on ServerException catch (e) {
      return Failed(
          ServerFailure(message: e.message, statusCode: e.statusCode));
    }
  }
}
