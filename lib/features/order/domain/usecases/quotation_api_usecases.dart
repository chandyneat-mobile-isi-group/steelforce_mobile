import 'package:equatable/equatable.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/paged_result.dart';
import 'package:steelforce/features/order/domain/entities/quotation_api_entities.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_api_repository.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

class GetQuotationsParams extends Equatable {
  const GetQuotationsParams({
    this.status,
    this.depotId,
    this.page = 1,
    this.pageSize = 20,
  });

  final String? status;
  final String? depotId;
  final int page;
  final int pageSize;

  @override
  List<Object?> get props => [status, depotId, page, pageSize];
}

class GetQuotationsList
    implements UseCase<PagedResult<QuotationSummary>, GetQuotationsParams> {
  const GetQuotationsList(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<PagedResult<QuotationSummary>> call(GetQuotationsParams params) {
    return _repository.getQuotations(
      status: params.status,
      depotId: params.depotId,
      page: params.page,
      pageSize: params.pageSize,
    );
  }
}

class OpenQuotationParams extends Equatable {
  const OpenQuotationParams({
    required this.depotId,
    this.shipmentType = 'Pickup',
    this.shipTo,
  });

  final String depotId;
  final String shipmentType;
  final String? shipTo;

  @override
  List<Object?> get props => [depotId, shipmentType, shipTo];
}

class OpenQuotation implements UseCase<QuotationDetail, OpenQuotationParams> {
  const OpenQuotation(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(OpenQuotationParams params) {
    return _repository.createQuotation(
      depotId: params.depotId,
      shipmentType: params.shipmentType,
      shipTo: params.shipTo,
    );
  }
}

class QuotationIdParams extends Equatable {
  const QuotationIdParams(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class GetQuotationDetail
    implements UseCase<QuotationDetail, QuotationIdParams> {
  const GetQuotationDetail(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(QuotationIdParams params) {
    return _repository.getQuotationDetail(params.id);
  }
}

class UpdateQuotationHeaderParams extends Equatable {
  const UpdateQuotationHeaderParams({
    required this.id,
    required this.shipmentType,
    this.shipTo,
    this.paymentTerm,
    this.depotReference,
    this.remarks,
  });

  final String id;
  final String shipmentType;
  final String? shipTo;
  final String? paymentTerm;
  final String? depotReference;
  final String? remarks;

  @override
  List<Object?> get props =>
      [id, shipmentType, shipTo, paymentTerm, depotReference, remarks];
}

class UpdateQuotationHeader
    implements UseCase<QuotationDetail, UpdateQuotationHeaderParams> {
  const UpdateQuotationHeader(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(UpdateQuotationHeaderParams params) {
    return _repository.updateQuotationHeader(
      params.id,
      shipmentType: params.shipmentType,
      shipTo: params.shipTo,
      paymentTerm: params.paymentTerm,
      depotReference: params.depotReference,
      remarks: params.remarks,
    );
  }
}

class AddQuotationLineParams extends Equatable {
  const AddQuotationLineParams({
    required this.id,
    required this.materialNumber,
    required this.quantity,
    this.unit,
  });

  final String id;
  final String materialNumber;
  final double quantity;
  final String? unit;

  @override
  List<Object?> get props => [id, materialNumber, quantity, unit];
}

class AddQuotationLine
    implements UseCase<QuotationDetail, AddQuotationLineParams> {
  const AddQuotationLine(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(AddQuotationLineParams params) {
    return _repository.addLine(
      params.id,
      materialNumber: params.materialNumber,
      quantity: params.quantity,
      unit: params.unit,
    );
  }
}

class UpdateQuotationLineParams extends Equatable {
  const UpdateQuotationLineParams({
    required this.id,
    required this.lineId,
    required this.quantity,
    this.unit,
  });

  final String id;
  final String lineId;
  final double quantity;
  final String? unit;

  @override
  List<Object?> get props => [id, lineId, quantity, unit];
}

class UpdateQuotationLine
    implements UseCase<QuotationDetail, UpdateQuotationLineParams> {
  const UpdateQuotationLine(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(UpdateQuotationLineParams params) {
    return _repository.updateLine(
      params.id,
      params.lineId,
      quantity: params.quantity,
      unit: params.unit,
    );
  }
}

class DeleteQuotationLineParams extends Equatable {
  const DeleteQuotationLineParams({
    required this.id,
    required this.lineId,
  });

  final String id;
  final String lineId;

  @override
  List<Object?> get props => [id, lineId];
}

class DeleteQuotationLineItem
    implements UseCase<QuotationDetail, DeleteQuotationLineParams> {
  const DeleteQuotationLineItem(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(DeleteQuotationLineParams params) {
    return _repository.deleteLine(params.id, params.lineId);
  }
}

class SetQuotationDiscountsParams extends Equatable {
  const SetQuotationDiscountsParams({
    required this.id,
    required this.lines,
  });

  final String id;
  final List<QuotationDiscountIntent> lines;

  @override
  List<Object?> get props => [id, lines];
}

class SetQuotationDiscounts
    implements UseCase<QuotationDetail, SetQuotationDiscountsParams> {
  const SetQuotationDiscounts(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(SetQuotationDiscountsParams params) {
    return _repository.setDiscounts(params.id, lines: params.lines);
  }
}

class GetQuotationPreview
    implements UseCase<QuotationPreviewData, QuotationIdParams> {
  const GetQuotationPreview(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationPreviewData> call(QuotationIdParams params) {
    return _repository.getPreview(params.id);
  }
}

class RepriceQuotation implements UseCase<QuotationDetail, QuotationIdParams> {
  const RepriceQuotation(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(QuotationIdParams params) {
    return _repository.reprice(params.id);
  }
}

class SubmitQuotation implements UseCase<QuotationDetail, QuotationIdParams> {
  const SubmitQuotation(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(QuotationIdParams params) {
    return _repository.submit(params.id);
  }
}

class CancelQuotation implements UseCase<QuotationDetail, QuotationIdParams> {
  const CancelQuotation(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<QuotationDetail> call(QuotationIdParams params) {
    return _repository.cancel(params.id);
  }
}

class GetQuotationHistory
    implements UseCase<List<QuotationApprovalHistory>, QuotationIdParams> {
  const GetQuotationHistory(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<List<QuotationApprovalHistory>> call(QuotationIdParams params) {
    return _repository.getHistory(params.id);
  }
}

class DepotAgreementsParams extends Equatable {
  const DepotAgreementsParams(this.depotId);
  final String depotId;

  @override
  List<Object?> get props => [depotId];
}

class GetDepotAgreements
    implements UseCase<List<DepotAgreement>, DepotAgreementsParams> {
  const GetDepotAgreements(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<List<DepotAgreement>> call(DepotAgreementsParams params) {
    return _repository.getDepotAgreements(params.depotId);
  }
}

class DepotIncentivesParams extends Equatable {
  const DepotIncentivesParams({
    required this.depotId,
    this.shipment,
  });

  final String depotId;
  final String? shipment;

  @override
  List<Object?> get props => [depotId, shipment];
}

class GetDepotIncentives
    implements UseCase<List<PromoGroup>, DepotIncentivesParams> {
  const GetDepotIncentives(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<List<PromoGroup>> call(DepotIncentivesParams params) {
    return _repository.getDepotIncentives(
      params.depotId,
      shipment: params.shipment,
    );
  }
}

class DepotPromotionsParams extends Equatable {
  const DepotPromotionsParams(this.depotId);
  final String depotId;

  @override
  List<Object?> get props => [depotId];
}

class GetDepotPromotions
    implements UseCase<List<PromoView>, DepotPromotionsParams> {
  const GetDepotPromotions(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<List<PromoView>> call(DepotPromotionsParams params) {
    return _repository.getDepotPromotions(params.depotId);
  }
}

class GetDiscountAuthority implements UseCase<DiscountAuthority, NoParams> {
  const GetDiscountAuthority(this._repository);
  final QuotationApiRepository _repository;

  @override
  ResultFuture<DiscountAuthority> call([NoParams params = const NoParams()]) {
    return _repository.getDiscountAuthority();
  }
}
