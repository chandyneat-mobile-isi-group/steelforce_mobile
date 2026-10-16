import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/repositories/sales_order_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class CreateSalesOrder extends UseCase<SalesOrder, CreateSalesOrderParams> {
  const CreateSalesOrder(this._repository);
  final SalesOrderRepository _repository;

  @override
  ResultFuture<SalesOrder> call(CreateSalesOrderParams params) =>
      _repository.createFromQuotation(params.quotation, items: params.items);
}
