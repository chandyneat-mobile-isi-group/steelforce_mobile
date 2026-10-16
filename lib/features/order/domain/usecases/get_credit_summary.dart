import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/credit_summary.dart';
import 'package:steelforce/features/order/domain/services/credit_service.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class GetCreditSummary extends UseCase<CreditSummary, GetCreditSummaryParams> {
  const GetCreditSummary(this._service);
  final CreditService _service;

  @override
  ResultFuture<CreditSummary> call(GetCreditSummaryParams params) =>
      _service.getSummary(params.depotId);
}
