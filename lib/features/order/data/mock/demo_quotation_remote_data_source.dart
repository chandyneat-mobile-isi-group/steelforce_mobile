import 'dart:async';

import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';
import 'package:steelforce/features/order/data/mock/demo_depot_commercial_fixtures.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_document.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_store.dart';
import 'package:steelforce/features/order/data/models/quotation_api_models.dart';
import 'package:steelforce/features/order/data/remote/quotation_remote_data_source.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

/// `/api/v1/mobile/quotations` (and the depot commercial reads the builder
/// makes beside it) for a demo build.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// Every method first spends one simulated round trip on [DemoNetwork], so a
/// demo switched offline fails exactly as a dropped connection does and the
/// repositories' and sync gateway's real offline paths run. Answers are built
/// as wire JSON and parsed with the live models' own `fromJson`, so a field
/// the real contract does not carry cannot reach the screens from here.
///
/// The online builder and the offline outbox both land here: the outbox's
/// `ApiQuotationAdminGateway` creates with the device's `clientId`, reconciles
/// lines and discounts, and submits — the same calls the builder makes.
class DemoQuotationRemoteDataSource implements QuotationRemoteDataSource {
  DemoQuotationRemoteDataSource(this._network, this._store);

  final DemoNetwork _network;
  final DemoQuotationStore _store;

  /// The live list endpoint clamps rather than rejects a large page.
  static const _maxPageSize = 100;

  @override
  Future<({List<QuotationSummaryModel> quotations, ApiMetadata? metadata})>
      fetchQuotations({
    String? status,
    String? depotId,
    int page = 1,
    int pageSize = 20,
  }) async {
    await _network.roundTrip();
    final size = pageSize.clamp(1, _maxPageSize);
    final current = page < 1 ? 1 : page;
    final result = _store.list(
        status: status, depotId: depotId, page: current, pageSize: size);
    final pages = (result.total / size).ceil();
    return (
      quotations: result.rows.map(QuotationSummaryModel.fromJson).toList(),
      metadata: ApiMetadata(
        page: current,
        pageSize: size,
        totalRecords: result.total,
        totalPages: pages,
        hasNextPage: current < pages,
        hasPreviousPage: current > 1,
      ),
    );
  }

  @override
  Future<QuotationDetailModel> createQuotation({
    required String depotId,
    String shipmentType = 'Pickup',
    String? shipTo,
    String? clientId,
  }) =>
      _detail(() => _store.create(depotId, shipmentType, shipTo, clientId));

  @override
  Future<QuotationDetailModel> fetchQuotationById(String id) =>
      _detail(() => _store.get(id));

  @override
  Future<QuotationDetailModel> updateHeader(
    String id, {
    required String shipmentType,
    String? shipTo,
    String? paymentTerm,
    String? depotReference,
    String? remarks,
  }) =>
      _detail(() => _store.updateHeader(id, {
            'shipmentType': shipmentType,
            'shipTo': shipTo,
            'paymentTerm': paymentTerm,
            'depotReference': depotReference,
            'remarks': remarks,
          }));

  @override
  Future<QuotationDetailModel> addLine(
    String id, {
    required String materialNumber,
    required double quantity,
    String? unit,
  }) =>
      _detail(() => _store.addLine(id, materialNumber, quantity, unit));

  @override
  Future<QuotationDetailModel> updateLine(
    String id,
    String lineId, {
    required double quantity,
    String? unit,
  }) =>
      _detail(() => _store.updateLine(id, lineId, quantity));

  @override
  Future<QuotationDetailModel> deleteLine(String id, String lineId) =>
      _detail(() => _store.deleteLine(id, lineId));

  @override
  Future<QuotationDetailModel> setDiscounts(
    String id, {
    required List<QuotationDiscountIntent> lines,
  }) =>
      _detail(() => _store.setDiscounts(id, lines));

  @override
  Future<QuotationPreviewModel> getPreview(String id) async {
    await _network.roundTrip();
    final doc = _store.get(id);
    final ageing = DateTime.now().subtract(const Duration(days: 3));
    return QuotationPreviewModel.fromJson({
      'quotationId': doc.id,
      'lines': doc.linesJson(),
      'totals': doc.totalsJson(),
      'warnings': [
        if (doc.isEditable)
          for (final line in doc.lines)
            if (line.pricedAt.isBefore(ageing))
              {'code': 'Quotation.PriceAgeing', 'lineId': line.id},
      ],
      'manualDiscountLimitPercent': DemoDepotCommercial.repAuthorityPercent,
      'lineDiscountCapPercent': DemoDepotCommercial.lineCapPercent,
      'requiredApprovalLevel': doc.requiredApprovalLevel,
    });
  }

  @override
  Future<QuotationDetailModel> reprice(String id) =>
      _detail(() => _store.reprice(id));

  @override
  Future<QuotationDetailModel> submit(String id) =>
      _detail(() => _store.submit(id));

  @override
  Future<QuotationDetailModel> cancel(String id) =>
      _detail(() => _store.cancel(id));

  @override
  Future<List<QuotationHistoryRecordModel>> fetchHistory(String id) async {
    await _network.roundTrip();
    return _store
        .history(id)
        .map(QuotationHistoryRecordModel.fromJson)
        .toList();
  }

  @override
  Future<List<DepotAgreementModel>> fetchDepotAgreements(String depotId) async {
    await _network.roundTrip();
    return DemoDepotCommercial.agreementsJson(depotId)
        .map(DepotAgreementModel.fromJson)
        .toList();
  }

  @override
  Future<List<PromoGroup>> fetchDepotIncentives(
    String depotId, {
    String? shipment,
  }) async {
    await _network.roundTrip();
    return DemoDepotCommercial.incentivesJson(depotId)
        .map(PromoGroup.fromJson)
        .toList();
  }

  @override
  Future<List<PromoView>> fetchDepotPromotions(String depotId) async {
    await _network.roundTrip();
    return DemoDepotCommercial.promotionsJson(depotId)
        .map(PromoView.fromJson)
        .toList();
  }

  @override
  Future<DiscountAuthorityModel> fetchDiscountAuthority() async {
    await _network.roundTrip();
    return DiscountAuthorityModel.fromJson(DemoDepotCommercial.authorityJson());
  }

  Future<QuotationDetailModel> _detail(
      FutureOr<DemoQuotationDoc> Function() action) async {
    await _network.roundTrip();
    final doc = await action();
    return QuotationDetailModel.fromJson(doc.detailJson());
  }
}
