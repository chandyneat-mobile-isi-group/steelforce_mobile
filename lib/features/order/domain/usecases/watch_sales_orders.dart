import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/repositories/sales_order_repository.dart';

class WatchSalesOrders extends StreamUseCase<List<SalesOrder>, NoParams> {
  const WatchSalesOrders(this._repository);
  final SalesOrderRepository _repository;

  @override
  Stream<List<SalesOrder>> call(NoParams params) =>
      _repository.watchSalesOrders();
}
