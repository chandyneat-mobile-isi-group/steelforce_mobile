import 'package:dio/dio.dart';
import 'package:steelforce/core/network/api/api_endpoints.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/features/order/data/models/quotation_api_models.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

abstract class QuotationRemoteDataSource {
  Future<({List<QuotationSummaryModel> quotations, ApiMetadata? metadata})>
      fetchQuotations({
    String? status,
    String? depotId,
    int page = 1,
    int pageSize = 20,
  });

  /// [clientId] is the quotation's id on this device. It makes the create
  /// idempotent (the same id again answers the existing quotation) and is
  /// what a visit check-out's `orders[].clientId` links to
  /// (`check-in-check-out-mobile.md` §7).
  Future<QuotationDetailModel> createQuotation({
    required String depotId,
    String shipmentType = 'Pickup',
    String? shipTo,
    String? clientId,
  });

  Future<QuotationDetailModel> fetchQuotationById(String id);

  Future<QuotationDetailModel> updateHeader(
    String id, {
    required String shipmentType,
    String? shipTo,
    String? paymentTerm,
    String? depotReference,
    String? remarks,
  });

  Future<QuotationDetailModel> addLine(
    String id, {
    required String materialNumber,
    required double quantity,
    String? unit,
  });

  Future<QuotationDetailModel> updateLine(
    String id,
    String lineId, {
    required double quantity,
    String? unit,
  });

  Future<QuotationDetailModel> deleteLine(String id, String lineId);

  Future<QuotationDetailModel> setDiscounts(
    String id, {
    required List<QuotationDiscountIntent> lines,
  });

  Future<QuotationPreviewModel> getPreview(String id);

  Future<QuotationDetailModel> reprice(String id);

  Future<QuotationDetailModel> submit(String id);

  Future<QuotationDetailModel> cancel(String id);

  Future<List<QuotationHistoryRecordModel>> fetchHistory(String id);

  Future<List<DepotAgreementModel>> fetchDepotAgreements(String depotId);

  Future<List<PromoGroup>> fetchDepotIncentives(
    String depotId, {
    String? shipment,
  });

  Future<List<PromoView>> fetchDepotPromotions(String depotId);

  Future<DiscountAuthorityModel> fetchDiscountAuthority();
}

class ApiQuotationRemoteDataSource implements QuotationRemoteDataSource {
  const ApiQuotationRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<({List<QuotationSummaryModel> quotations, ApiMetadata? metadata})>
      fetchQuotations({
    String? status,
    String? depotId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.quotationsEndpoint,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (depotId != null && depotId.isNotEmpty) 'depotId': depotId,
          'page': page,
          'pageSize': pageSize,
        },
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final rawList = envelope.data['quotations'] as List<dynamic>? ??
          envelope.data['items'] as List<dynamic>? ??
          const <dynamic>[];

      final quotations = rawList
          .whereType<Map>()
          .map((m) => QuotationSummaryModel.fromJson(m.cast<String, dynamic>()))
          .toList();

      return (quotations: quotations, metadata: envelope.metadata);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> createQuotation({
    required String depotId,
    String shipmentType = 'Pickup',
    String? shipTo,
    String? clientId,
  }) async {
    try {
      final res = await _client.post<Object?>(
        ApiEndpoints.quotationsEndpoint,
        data: {
          'depotId': depotId,
          'shipmentType': shipmentType,
          'shipTo': shipTo,
          if (clientId != null) 'clientId': clientId,
        },
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> fetchQuotationById(String id) async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.quotationEndpoint(id),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> updateHeader(
    String id, {
    required String shipmentType,
    String? shipTo,
    String? paymentTerm,
    String? depotReference,
    String? remarks,
  }) async {
    try {
      final res = await _client.put<Object?>(
        ApiEndpoints.quotationEndpoint(id),
        data: {
          'shipmentType': shipmentType,
          'shipTo': shipTo,
          'paymentTerm': paymentTerm,
          'depotReference': depotReference,
          'remarks': remarks,
        },
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> addLine(
    String id, {
    required String materialNumber,
    required double quantity,
    String? unit,
  }) async {
    try {
      final res = await _client.post<Object?>(
        ApiEndpoints.quotationLinesEndpoint(id),
        data: {
          'materialNumber': materialNumber,
          'quantity': quantity,
          if (unit != null) 'unit': unit,
        },
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> updateLine(
    String id,
    String lineId, {
    required double quantity,
    String? unit,
  }) async {
    try {
      final res = await _client.put<Object?>(
        ApiEndpoints.quotationLineEndpoint(id, lineId),
        data: {
          'quantity': quantity,
          if (unit != null) 'unit': unit,
        },
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> deleteLine(String id, String lineId) async {
    try {
      final res = await _client.delete<Object?>(
        ApiEndpoints.quotationLineEndpoint(id, lineId),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> setDiscounts(
    String id, {
    required List<QuotationDiscountIntent> lines,
  }) async {
    try {
      final res = await _client.put<Object?>(
        ApiEndpoints.quotationDiscountsEndpoint(id),
        data: {
          'lines': lines.map((l) => l.toJson()).toList(),
        },
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationPreviewModel> getPreview(String id) async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.quotationPreviewEndpoint(id),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('preview') ?? envelope.data;
      return QuotationPreviewModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> reprice(String id) async {
    try {
      final res = await _client.post<Object?>(
        ApiEndpoints.quotationRepriceEndpoint(id),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> submit(String id) async {
    try {
      final res = await _client.post<Object?>(
        ApiEndpoints.quotationSubmitEndpoint(id),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<QuotationDetailModel> cancel(String id) async {
    try {
      final res = await _client.post<Object?>(
        ApiEndpoints.quotationCancelEndpoint(id),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('quotation') ?? envelope.data;
      return QuotationDetailModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<List<QuotationHistoryRecordModel>> fetchHistory(String id) async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.quotationHistoryEndpoint(id),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final rawList = envelope.data['history'] as List<dynamic>? ??
          envelope.data['records'] as List<dynamic>? ??
          const <dynamic>[];

      return rawList
          .whereType<Map>()
          .map((m) =>
              QuotationHistoryRecordModel.fromJson(m.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<List<DepotAgreementModel>> fetchDepotAgreements(String depotId) async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.depotAgreementsEndpoint(depotId),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final rawList = envelope.data['agreements'] as List<dynamic>? ??
          envelope.data['items'] as List<dynamic>? ??
          const <dynamic>[];

      return rawList
          .whereType<Map>()
          .map((m) => DepotAgreementModel.fromJson(m.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<List<PromoGroup>> fetchDepotIncentives(
    String depotId, {
    String? shipment,
  }) async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.depotIncentivesEndpoint(depotId),
        queryParameters: {
          if (shipment != null && shipment.isNotEmpty) 'shipment': shipment,
        },
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final rawList = envelope.data['groups'] as List<dynamic>? ??
          envelope.data['items'] as List<dynamic>? ??
          envelope.data['incentives'] as List<dynamic>? ??
          (envelope.data is List ? envelope.data as List : const <dynamic>[]);

      return rawList
          .whereType<Map>()
          .map((m) => PromoGroup.fromJson(m.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<List<PromoView>> fetchDepotPromotions(String depotId) async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.depotPromotionsEndpoint(depotId),
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final rawList = envelope.data['promotions'] as List<dynamic>? ??
          envelope.data['items'] as List<dynamic>? ??
          (envelope.data is List ? envelope.data as List : const <dynamic>[]);

      return rawList
          .whereType<Map>()
          .map((m) => PromoView.fromJson(m.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }

  @override
  Future<DiscountAuthorityModel> fetchDiscountAuthority() async {
    try {
      final res = await _client.get<Object?>(
        ApiEndpoints.discountAuthorityEndpoint,
      );

      final envelope = ApiEnvelope.fromBody(res.data);
      final data = envelope.object('authority') ?? envelope.data;
      return DiscountAuthorityModel.fromJson(data);
    } on DioException catch (e) {
      throw ApiException(ApiError.fromDio(e));
    }
  }
}
