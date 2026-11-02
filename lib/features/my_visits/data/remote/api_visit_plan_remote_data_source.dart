import 'package:dio/dio.dart';
import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/my_visits/data/models/ad_hoc_plan_model.dart';
import 'package:steelforce/features/my_visits/data/models/plan_check_in_model.dart';
import 'package:steelforce/features/my_visits/data/models/plan_visit_close_model.dart';
import 'package:steelforce/features/my_visits/data/models/visit_plans_model.dart';
import 'package:steelforce/features/my_visits/data/remote/plan_check_in_log.dart';
import 'package:steelforce/features/my_visits/data/remote/plan_visit_debug_log.dart';
import 'package:steelforce/features/my_visits/data/remote/plan_visit_request_rows.dart';
import 'package:steelforce/features/my_visits/data/remote/visit_plan_remote_data_source.dart';
import 'package:steelforce/features/my_visits/domain/entities/ad_hoc_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_check_in.dart';
import 'package:steelforce/features/my_visits/domain/entities/plan_visit_close.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plan.dart';
import 'package:steelforce/features/my_visits/domain/entities/visit_plans_overview.dart';

/// The plans endpoints over the app's authenticated [Dio].
///
/// The bearer token and the single 401 refresh are the auth interceptor's job;
/// nothing here identifies the rep — the server reads that from the token.
class ApiVisitPlanRemoteDataSource implements VisitPlanRemoteDataSource {
  ApiVisitPlanRemoteDataSource(this._client, {AppLogger? logger})
      : _log = PlanCheckInLog(logger);

  final Dio _client;
  final PlanCheckInLog _log;

  @override
  Future<VisitPlansOverview> fetchMyPlans(PlanPeriod period) => _get(
        ApiEndpoints.mobilePlansEndpoint,
        query: {'period': period.apiValue},
      );

  @override
  Future<VisitPlansOverview> fetchTodayPlans() =>
      _get(ApiEndpoints.mobilePlansTodayEndpoint);

  /// The 200 body (`MyPlanDetail`) is not read: its schema is not in the
  /// contract we have, and the list is re-fetched afterwards anyway. The
  /// envelope is still checked so a `success: false` is not taken as done.
  @override
  Future<void> skipPlan(String planId, String reason) async {
    try {
      final res = await _client.post<DataMap>(
        ApiEndpoints.mobilePlanSkipEndpoint(planId),
        data: {'reason': reason},
      );
      ApiEnvelope.fromBody(res.data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    } on TypeError catch (e) {
      throw ServerException(message: '$e');
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    }
  }

  @override
  Future<PlanCheckInTarget> fetchCheckInTarget(String planId) =>
      _guard(() async {
        final res =
            await _client.get<DataMap>(ApiEndpoints.mobilePlanEndpoint(planId));
        return PlanCheckInModel.targetFromJson(
            ApiEnvelope.fromBody(res.data).data);
      });

  /// Success is the 200/201 status with a readable envelope, never the
  /// shape of a list in it. Each attempt is logged by [PlanCheckInLog].
  @override
  Future<PlanCheckInResult> checkIn(PlanCheckInRequest request) async {
    final path = ApiEndpoints.mobilePlanCheckInEndpoint(request.planId);
    final clock = Stopwatch()..start();
    _log.started(request, path);
    try {
      final (res, result) = await PlanVisitDebugLog.trace(
        step: 'CHECK-IN',
        method: 'POST',
        path: path,
        rows: () => PlanVisitRequestRows.checkIn(request),
        send: () async {
          final res = await _client.post<DataMap>(path,
              data: await PlanCheckInModel.toFormData(request));
          final result = PlanCheckInModel.resultFromJson(
              ApiEnvelope.fromBody(res.data).data, request.checkInId);
          return (res: res, value: (res, result));
        },
      );
      _log.succeeded(request, res, result, clock.elapsed);
      return result;
    } on DioException catch (e) {
      final error = ApiError.fromDio(e);
      _log.failed(request, e, error, clock.elapsed);
      throw ApiException(error);
    } on TypeError catch (e) {
      _log.unreadable(request, e, clock.elapsed);
      throw ServerException(message: '$e');
    } on FormatException catch (e) {
      _log.unreadable(request, e, clock.elapsed);
      throw ServerException(message: e.message);
    } on ServerException catch (e) {
      _log.unreadable(request, e.message, clock.elapsed);
      rethrow;
    }
  }

  /// The 200 body (`InventoryView`) is not read: the screen only needs to know
  /// the photos landed. The envelope is still checked.
  @override
  Future<void> uploadInventoryPhotos(PlanInventoryUploadRequest request) =>
      _guard(() => PlanVisitDebugLog.trace(
            step: 'INVENTORY PHOTOS',
            method: 'POST',
            path: ApiEndpoints.mobilePlanInventoryPhotoUploadEndpoint(
                request.planId),
            rows: () => PlanVisitRequestRows.inventory(request),
            send: () async {
              final res = await _client.post<DataMap>(
                ApiEndpoints.mobilePlanInventoryPhotoUploadEndpoint(
                    request.planId),
                data: await PlanVisitCloseModel.uploadForm(request),
              );
              ApiEnvelope.fromBody(res.data);
              return (res: res, value: null);
            },
          ));

  /// The 200 body (`MyPlanDetail`) is not read: the lists are re-fetched
  /// afterwards. The envelope is still checked.
  @override
  Future<void> checkOut(PlanCheckOutRequest request) =>
      _guard(() => PlanVisitDebugLog.trace(
            step: 'CHECK-OUT',
            method: 'POST',
            path: ApiEndpoints.mobilePlanCheckOutEndpoint(request.planId),
            rows: () => PlanVisitRequestRows.checkOut(request),
            send: () async {
              final res = await _client.post<DataMap>(
                ApiEndpoints.mobilePlanCheckOutEndpoint(request.planId),
                data: PlanVisitCloseModel.checkOutJson(request),
              );
              ApiEnvelope.fromBody(res.data);
              return (res: res, value: null);
            },
          ));

  @override
  Future<({VisitPlan plan, bool created})> startAdHoc(
          String visitId, AdHocPlanOutlet outlet) =>
      _guard(() => PlanVisitDebugLog.trace(
            step: 'AD HOC START',
            method: 'POST',
            path: ApiEndpoints.mobilePlansAdHocEndpoint,
            rows: () => PlanVisitRequestRows.adHoc(visitId, outlet),
            send: () async {
              final res = await _client.post<DataMap>(
                ApiEndpoints.mobilePlansAdHocEndpoint,
                data: AdHocPlanModel.toJson(visitId, outlet),
              );
              final data = ApiEnvelope.fromBody(res.data).data;
              return (
                res: res,
                value: (
                  plan: AdHocPlanModel.planFromJson(data, visitId, outlet),
                  created: res.statusCode != 200,
                ),
              );
            },
          ));

  Future<VisitPlansOverview> _get(String path, {DataMap? query}) =>
      _guard(() async {
        final res = await _client.get<DataMap>(path, queryParameters: query);
        return VisitPlansModel.fromJson(ApiEnvelope.fromBody(res.data).data);
      });

  /// Transport and parse errors as the data-source contract promises them.
  Future<T> _guard<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    } on TypeError catch (e) {
      throw ServerException(message: '$e');
    } on FormatException catch (e) {
      throw ServerException(message: e.message);
    }
  }
}
