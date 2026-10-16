import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/check_in_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/check_out_record_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_api_mapper.dart';
import 'package:steelforce/features/my_visits/data/models/visit_check_models.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_check_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/no_order_reason.dart';
import 'package:steelforce/features/my_visits/domain/entities/server_visit.dart';

/// `POST /visits/check-ins`, `POST /visits/check-outs` and
/// `GET /visits/check-out-reasons`.
///
/// The request bodies are the same JSON as the `/push` rows
/// ([CheckInRecordApiJson], [CheckOutRecordApiJson]), so a record the server
/// sees online and the same record arriving later in a batch are identical.
class ApiVisitCheckRemoteDataSource implements VisitCheckRemoteDataSource {
  const ApiVisitCheckRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<ServerVisit> checkIn(CheckInRecordModel record) =>
      _postVisit(ApiEndpoints.visitCheckInsEndpoint, record.toApiJson());

  @override
  Future<ServerVisit> checkOut(CheckOutRecordModel record) =>
      _postVisit(ApiEndpoints.visitCheckOutsEndpoint, record.toApiJson());

  @override
  Future<List<NoOrderReason>> fetchCheckOutReasons() async {
    try {
      final res =
          await _client.get<Object?>(ApiEndpoints.visitCheckOutReasonsEndpoint);
      final rows = ApiListEnvelope.fromBody(res.data).items;
      return rows.map(noOrderReasonFromJson).whereType<NoOrderReason>().toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  Future<ServerVisit> _postVisit(String path, DataMap body) async {
    try {
      final res = await _client.post<DataMap>(path, data: body);
      return serverVisitFromJson(ApiEnvelope.fromBody(res.data).data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }
}
