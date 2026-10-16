import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class SaveQuotation extends UseCase<Quotation, SaveQuotationParams> {
  const SaveQuotation(this._repository);
  final QuotationRepository _repository;

  @override
  ResultFuture<Quotation> call(SaveQuotationParams params) =>
      _repository.saveQuotation(
        items: params.items,
        depotId: params.depotId,
        shopName: params.shopName,
        leadId: params.leadId,
        leadDisplayName: params.leadDisplayName,
        offVisitReason: params.offVisitReason,
        gpsLat: params.gpsLat,
        gpsLng: params.gpsLng,
        subtotal: params.subtotal,
        discount: params.discount,
        tax: params.tax,
        total: params.total,
        remoteId: params.remoteId,
      );
}
