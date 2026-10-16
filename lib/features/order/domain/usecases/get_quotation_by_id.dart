import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class GetQuotationById extends UseCase<Quotation?, QuotationIdParams> {
  const GetQuotationById(this._repository);
  final QuotationRepository _repository;

  @override
  ResultFuture<Quotation?> call(QuotationIdParams params) =>
      _repository.getQuotationById(params.quotationId);
}
