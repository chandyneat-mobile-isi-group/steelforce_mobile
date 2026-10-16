import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

/// Permanently discards a draft quotation.
class DeleteQuotation extends UseCase<void, QuotationIdParams> {
  const DeleteQuotation(this._repository);
  final QuotationRepository _repository;

  @override
  ResultFuture<void> call(QuotationIdParams params) =>
      _repository.deleteQuotation(params.quotationId);
}
