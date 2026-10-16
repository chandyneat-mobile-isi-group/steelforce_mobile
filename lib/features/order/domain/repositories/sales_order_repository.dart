import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';

abstract interface class SalesOrderRepository {
  ResultFuture<SalesOrder> createFromQuotation(Quotation quotation,
      {required List<CartItem> items});

  ResultFuture<SalesOrder?> getSalesOrderById(String id);

  Stream<List<SalesOrder>> watchSalesOrders();
}
