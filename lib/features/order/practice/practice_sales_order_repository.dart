import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/practice/practice_ids.dart';
import 'package:steelforce/core/practice/practice_session.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';
import 'package:steelforce/features/order/domain/repositories/sales_order_repository.dart';
import 'package:steelforce/features/order/practice/order_practice_data.dart';

/// Sales orders created during practice, held in [OrderPracticeData].
///
/// [createFromQuotation] mirrors `SalesOrderRepositoryImpl`: it refuses an
/// empty line list, freezes totals from the (possibly edited) lines with 10%
/// tax, marks the order confirmed, and — like the real one — leaves the
/// source quotation's status alone. Once [PracticeWorld.isClosed] every call
/// goes to [_real].
class PracticeSalesOrderRepository implements SalesOrderRepository {
  PracticeSalesOrderRepository({
    required SalesOrderRepository real,
    required PracticeWorld world,
    required OrderPracticeData data,
  })  : _real = real,
        _world = world,
        _data = data;

  final SalesOrderRepository _real;
  final PracticeWorld _world;
  final OrderPracticeData _data;

  bool get _live => _world.isClosed;

  @override
  ResultFuture<SalesOrder> createFromQuotation(Quotation quotation,
      {required List<CartItem> items}) async {
    if (_live) return _real.createFromQuotation(quotation, items: items);
    if (items.isEmpty) {
      return const Failed(
          CacheFailure(message: 'orders.sales_order.error_no_items'));
    }
    final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);
    final discount = items.fold<double>(0, (sum, i) => sum + i.lineDiscount);
    final tax = (subtotal - discount) * OrderPracticeData.taxRate;

    final order = SalesOrder(
      id: _data.newId(PracticeIds.salesOrderPrefix),
      quotationId: quotation.id,
      depotId: quotation.depotId,
      shopName: quotation.shopName,
      leadId: quotation.leadId,
      leadDisplayName: quotation.leadDisplayName,
      lines: List.unmodifiable(items),
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: subtotal - discount + tax,
      status: SalesOrderStatus.confirmed,
      offVisitReason: quotation.offVisitReason,
      sapStatus: 'Confirmed by SAP — pricing locked',
      createdAt: _data.now(),
    );
    _data.salesOrders[order.id] = order;
    _data.salesOrdersChanged();
    return Success(order);
  }

  @override
  ResultFuture<SalesOrder?> getSalesOrderById(String id) async {
    if (_live) return _real.getSalesOrderById(id);
    return Success(_data.salesOrders[id]);
  }

  @override
  Stream<List<SalesOrder>> watchSalesOrders() async* {
    if (_live) {
      yield* _real.watchSalesOrders();
      return;
    }
    yield List.unmodifiable(_data.salesOrders.values);
    yield* _data.salesOrderChanges;
  }
}
