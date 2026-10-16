import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/repositories/sales_order_repository.dart';
import 'package:steelforce/features/order/domain/usecases/catalog_params.dart';

class GetSalesOrderById extends UseCase<SalesOrder?, SalesOrderIdParams> {
  const GetSalesOrderById(this._repository);
  final SalesOrderRepository _repository;

  @override
  ResultFuture<SalesOrder?> call(SalesOrderIdParams params) =>
      _repository.getSalesOrderById(params.salesOrderId);
}
