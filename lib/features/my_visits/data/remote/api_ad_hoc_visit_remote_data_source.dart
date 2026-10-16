import 'package:dio/dio.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/ad_hoc_visit_response.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_debug_log.dart';
import 'package:steelforce/features/my_visits/data/remote/ad_hoc_visit_remote_data_source.dart';

/// `POST /api/v1/mobile/visits/ad-hoc` — the real thing.
///
/// Follows `ApiDepotRemoteDataSource`: one `Dio`, `ApiEnvelope.fromBody`,
/// `ApiError.fromDio`. Every refusal leaves here as an [ApiException] carrying
/// the platform code; the repository is the only place that decides what a code
/// means, because most of them are not failures.
class ApiAdHocVisitRemoteDataSource implements AdHocVisitRemoteDataSource {
  const ApiAdHocVisitRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<AdHocVisitResponse> create({
    required String sk,
    required String clientRequestId,
  }) async {
    final body = <String, dynamic>{
      // The depot's SAP code, which is what the server looks the depot up
      // by (`ad-hoc-visits-mobile.md` §4). Not the id, not `code`.
      'sk': sk,
      // Generated once per tap and persisted before the first send, so a
      // retry replays this request rather than creating a second visit.
      'clientRequestId': clientRequestId,
      // Always null: the server owns the day. A non-null date is rejected
      // as `Visit.AdHocDateInvalid`.
      'visitDate': null,
    };
    AdHocVisitDebugLog.request('POST', ApiEndpoints.visitAdHocEndpoint, body);
    final watch = Stopwatch()..start();

    try {
      final res = await _client.post<DataMap>(
        ApiEndpoints.visitAdHocEndpoint,
        data: body,
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final response = AdHocVisitResponse.fromJson(envelope.data);
      AdHocVisitDebugLog.success(
        status: res.statusCode,
        elapsedMs: watch.elapsedMilliseconds,
        created: response.created,
        stopId: response.stop.id,
        depotId: response.depot.id,
        sequence: response.stop.sequence,
        visitDate: response.visitDate,
      );
      return response;
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);
      AdHocVisitDebugLog.failure(
        error: error,
        transport: '${e.response?.statusCode ?? e.type.name}',
        elapsedMs: watch.elapsedMilliseconds,
        sk: sk,
        body: e.response?.data,
      );
      throw ApiException(error);
    } on FormatException catch (e) {
      AdHocVisitDebugLog.unreadable(e.message);
      // A 200 whose body we cannot read. Surfaced as a server fault rather
      // than swallowed: the visit may well exist, and the queue must not
      // silently treat this as "sent and done".
      throw ServerException(message: e.message);
    }
  }
}
