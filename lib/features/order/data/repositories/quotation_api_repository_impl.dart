import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/network/connectivity/network_info.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/remote/quotation_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_api_repository.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

class QuotationApiRepositoryImpl implements QuotationApiRepository {
  const QuotationApiRepositoryImpl({
    required QuotationRemoteDataSource remote,
    required NetworkInfo network,
  })  : _remote = remote,
        _network = network;

  final QuotationRemoteDataSource _remote;
  final NetworkInfo _network;

  Failure _mapException(Object e) {
    if (e is ApiException) {
      return ServerFailure(
        message: e.error.message ?? e.error.detail ?? 'Server error',
        statusCode: e.error.statusCode,
        code: e.error.code,
      );
    }
    if (e is ServerException) {
      return ServerFailure(message: e.message, statusCode: e.statusCode);
    }
    return ServerFailure(message: e.toString());
  }

  @override
  ResultFuture<PagedResult<QuotationSummary>> getQuotations({
    String? status,
    String? depotId,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final result = await _remote.fetchQuotations(
        status: status,
        depotId: depotId,
        page: page,
        pageSize: pageSize,
      );
      final hasMore = result.metadata?.hasNextPage ??
          (result.quotations.length >= pageSize);
      return Success(PagedResult(
        items: result.quotations,
        page: page,
        hasMore: hasMore,
      ));
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> createQuotation({
    required String depotId,
    String shipmentType = 'Pickup',
    String? shipTo,
  }) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.createQuotation(
        depotId: depotId,
        shipmentType: shipmentType,
        shipTo: shipTo,
      );
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> getQuotationDetail(String id) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.fetchQuotationById(id);
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> updateQuotationHeader(
    String id, {
    required String shipmentType,
    String? shipTo,
    String? paymentTerm,
    String? depotReference,
    String? remarks,
  }) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.updateHeader(
        id,
        shipmentType: shipmentType,
        shipTo: shipTo,
        paymentTerm: paymentTerm,
        depotReference: depotReference,
        remarks: remarks,
      );
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> addLine(
    String id, {
    required String materialNumber,
    required double quantity,
    String? unit,
  }) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.addLine(
        id,
        materialNumber: materialNumber,
        quantity: quantity,
        unit: unit,
      );
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> updateLine(
    String id,
    String lineId, {
    required double quantity,
    String? unit,
  }) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.updateLine(
        id,
        lineId,
        quantity: quantity,
        unit: unit,
      );
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> deleteLine(String id, String lineId) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.deleteLine(id, lineId);
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> setDiscounts(
    String id, {
    required List<QuotationDiscountIntent> lines,
  }) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.setDiscounts(id, lines: lines);
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationPreviewData> getPreview(String id) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final preview = await _remote.getPreview(id);
      return Success(preview);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> reprice(String id) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.reprice(id);
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> submit(String id) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.submit(id);
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<QuotationDetail> cancel(String id) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final quotation = await _remote.cancel(id);
      return Success(quotation);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<List<QuotationApprovalHistory>> getHistory(String id) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final history = await _remote.fetchHistory(id);
      return Success(history);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<List<DepotAgreement>> getDepotAgreements(String depotId) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final agreements = await _remote.fetchDepotAgreements(depotId);
      return Success(agreements);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<List<PromoGroup>> getDepotIncentives(
    String depotId, {
    String? shipment,
  }) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final incentives = await _remote.fetchDepotIncentives(
        depotId,
        shipment: shipment,
      );
      return Success(incentives);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<List<PromoView>> getDepotPromotions(String depotId) async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final promotions = await _remote.fetchDepotPromotions(depotId);
      return Success(promotions);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }

  @override
  ResultFuture<DiscountAuthority> getDiscountAuthority() async {
    if (!await _network.isConnected) {
      return const Failed(NetworkFailure());
    }
    try {
      final authority = await _remote.fetchDiscountAuthority();
      return Success(authority);
    } catch (e) {
      return Failed(_mapException(e));
    }
  }
}
