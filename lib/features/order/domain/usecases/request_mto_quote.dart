import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/mto_quote.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';
import 'package:steelforce/features/order/domain/services/mto_pricing_service.dart';

class RequestMtoQuote extends UseCase<MtoQuote, Product> {
  const RequestMtoQuote(this._service);
  final MtoPricingService _service;

  @override
  ResultFuture<MtoQuote> call(Product params) => _service.requestQuote(params);
}
