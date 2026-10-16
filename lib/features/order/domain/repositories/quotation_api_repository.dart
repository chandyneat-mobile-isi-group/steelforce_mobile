import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

abstract interface class QuotationApiRepository {
  ResultFuture<PagedResult<QuotationSummary>> getQuotations({
    String? status,
    String? depotId,
    int page = 1,
    int pageSize = 20,
  });

  ResultFuture<QuotationDetail> createQuotation({
    required String depotId,
    String shipmentType = 'Pickup',
    String? shipTo,
  });

  ResultFuture<QuotationDetail> getQuotationDetail(String id);

  ResultFuture<QuotationDetail> updateQuotationHeader(
    String id, {
    required String shipmentType,
    String? shipTo,
    String? paymentTerm,
    String? depotReference,
    String? remarks,
  });

  ResultFuture<QuotationDetail> addLine(
    String id, {
    required String materialNumber,
    required double quantity,
    String? unit,
  });

  ResultFuture<QuotationDetail> updateLine(
    String id,
    String lineId, {
    required double quantity,
    String? unit,
  });

  ResultFuture<QuotationDetail> deleteLine(String id, String lineId);

  ResultFuture<QuotationDetail> setDiscounts(
    String id, {
    required List<QuotationDiscountIntent> lines,
  });

  ResultFuture<QuotationPreviewData> getPreview(String id);

  ResultFuture<QuotationDetail> reprice(String id);

  ResultFuture<QuotationDetail> submit(String id);

  ResultFuture<QuotationDetail> cancel(String id);

  ResultFuture<List<QuotationApprovalHistory>> getHistory(String id);

  ResultFuture<List<DepotAgreement>> getDepotAgreements(String depotId);

  ResultFuture<List<PromoGroup>> getDepotIncentives(
    String depotId, {
    String? shipment,
  });

  ResultFuture<List<PromoView>> getDepotPromotions(String depotId);

  ResultFuture<DiscountAuthority> getDiscountAuthority();
}
