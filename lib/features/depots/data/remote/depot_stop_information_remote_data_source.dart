import 'package:dio/dio.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/depots/data/models/depot_stop_information_mapper.dart';
import 'package:steelforce/features/depots/data/remote/stop_information_debug_log.dart';
import 'package:steelforce/features/depots/domain/entities/depot_stop_information.dart';

/// `GET /api/v1/mobile/depots/{depotId}/stop-information`.
abstract interface class DepotStopInformationRemoteDataSource {
  /// Requires `customers.read`.
  ///
  /// A **404 means "not available to you"** and covers both "no such outlet"
  /// and "outside your entitlement" — the server makes them deliberately
  /// indistinguishable, so a caller must not present it as "deleted".
  Future<DepotStopInformation> fetch(String depotId);
}

class ApiDepotStopInformationRemoteDataSource
    implements DepotStopInformationRemoteDataSource {
  const ApiDepotStopInformationRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<DepotStopInformation> fetch(String depotId) async {
    final path = ApiEndpoints.depotStopInformationEndpoint(depotId);
    StopInformationDebugLog.request(depotId, path);
    final clock = Stopwatch()..start();

    final Response<DataMap> res;
    try {
      res = await _client.get<DataMap>(path);
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);
      StopInformationDebugLog.failure(
        error: error,
        elapsedMs: clock.elapsedMilliseconds,
      );
      throw ApiException(error);
    }

    try {
      final info = DepotStopInformationMapper.fromData(
        ApiEnvelope.fromBody(res.data).data,
      );
      StopInformationDebugLog.success(
        elapsedMs: clock.elapsedMilliseconds,
        code: info.outlet.code,
      );
      return info;
    } on Object catch (e) {
      // A body in the wrong shape must still reach the screen as "could not
      // load" — an escaped TypeError left the banner spinning forever.
      StopInformationDebugLog.unreadable(
        elapsedMs: clock.elapsedMilliseconds,
        error: e,
      );
      if (e is ServerException) rethrow;
      throw const ServerException(
        message: 'The server returned an unexpected response.',
      );
    }
  }
}
