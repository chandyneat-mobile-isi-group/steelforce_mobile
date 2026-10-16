import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/repositories/quotation_repository.dart';

class WatchQuotations extends StreamUseCase<List<Quotation>, NoParams> {
  const WatchQuotations(this._repository);
  final QuotationRepository _repository;

  @override
  Stream<List<Quotation>> call(NoParams params) =>
      _repository.watchQuotations();
}
