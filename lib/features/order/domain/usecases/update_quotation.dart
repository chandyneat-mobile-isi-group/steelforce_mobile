import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class UpdateQuotation extends UseCase<Quotation, UpdateQuotationParams> {
  const UpdateQuotation(this._repository);
  final QuotationRepository _repository;

  @override
  ResultFuture<Quotation> call(UpdateQuotationParams params) =>
      _repository.updateQuotation(
        params.existing,
        items: params.items,
        subtotal: params.subtotal,
        discount: params.discount,
        tax: params.tax,
        total: params.total,
        remoteId: params.remoteId,
      );
}
