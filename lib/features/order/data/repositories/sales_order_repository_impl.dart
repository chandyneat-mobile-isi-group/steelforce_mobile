import 'dart:async';
import 'dart:math';

import 'package:steelforce/core/error/exceptions.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/order/data/local/order_line_codec.dart';
import 'package:steelforce/features/order/data/local/product_local_data_source.dart';
import 'package:steelforce/features/order/data/local/sales_order_local_data_source.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/quotation.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';
import 'package:steelforce/features/order/domain/repositories/sales_order_repository.dart';

class SalesOrderRepositoryImpl implements SalesOrderRepository {
  SalesOrderRepositoryImpl(
      {required SalesOrderLocalDataSource local,
      required ProductLocalDataSource productLocal})
      : _local = local,
        _lines = OrderLineCodec(productLocal);

  final SalesOrderLocalDataSource _local;
  final OrderLineCodec _lines;

  final StreamController<List<SalesOrder>> _controller =
      StreamController<List<SalesOrder>>.broadcast();

  @override
  ResultFuture<SalesOrder> createFromQuotation(Quotation quotation,
      {required List<CartItem> items}) async {
    try {
      if (items.isEmpty) {
        return const Failed(CacheFailure(message: 'Sales order has no items.'));
      }
      // "SAP performs final pricing" — mocked as a no-op lock: totals are
      // simply frozen from the (possibly rep-edited) line items, no numeric
      // repricing, and the order is marked confirmed.
      final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineSubtotal);
      final discount = items.fold<double>(0, (sum, i) => sum + i.lineDiscount);
      final tax = (subtotal - discount) * 0.10;
      final total = subtotal - discount + tax;

      final order = SalesOrder(
        id: _newId('SO'),
        quotationId: quotation.id,
        depotId: quotation.depotId,
        shopName: quotation.shopName,
        leadId: quotation.leadId,
        leadDisplayName: quotation.leadDisplayName,
        lines: items,
        subtotal: subtotal,
        discount: discount,
        tax: tax,
        total: total,
        status: SalesOrderStatus.confirmed,
        offVisitReason: quotation.offVisitReason,
        sapStatus: 'Confirmed by SAP — pricing locked',
        createdAt: DateTime.now(),
      );

      await _local.insertSalesOrder(_toRow(order));
      unawaited(_broadcast());
      return Success(order);
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  ResultFuture<SalesOrder?> getSalesOrderById(String id) async {
    try {
      final row = await _local.getById(id);
      return Success(row == null ? null : await _fromRow(row));
    } on CacheException catch (e) {
      return Failed(CacheFailure(message: e.message));
    }
  }

  @override
  Stream<List<SalesOrder>> watchSalesOrders() async* {
    yield await _loadAll();
    yield* _controller.stream;
  }

  Future<void> _broadcast() async {
    if (!_controller.hasListener) return;
    try {
      _controller.add(await _loadAll());
    } on CacheException {
      // Keep the last good list on a transient read error.
    }
  }

  Future<List<SalesOrder>> _loadAll() async {
    final rows = await _local.fetchAll();
    return Future.wait(rows.map(_fromRow));
  }

  DataMap _toRow(SalesOrder o) => {
        'id': o.id,
        'quotation_id': o.quotationId,
        'depot_id': o.depotId,
        'shop_name': o.shopName,
        'lead_id': o.leadId,
        'lead_display_name': o.leadDisplayName,
        'lines_json': _encodeLines(o.lines),
        'subtotal': o.subtotal,
        'discount': o.discount,
        'tax': o.tax,
        'total': o.total,
        'status': o.status.name,
        'off_visit_reason': o.offVisitReason?.name,
        'sap_status': o.sapStatus,
        'created_at': o.createdAt.toIso8601String(),
      };

  Future<SalesOrder> _fromRow(DataMap row) async {
    return SalesOrder(
      id: row['id'] as String,
      quotationId: row['quotation_id'] as String,
      depotId: row['depot_id'] as String?,
      shopName: row['shop_name'] as String?,
      leadId: row['lead_id'] as String?,
      leadDisplayName: row['lead_display_name'] as String?,
      lines: await _decodeLines(row['lines_json'] as String,
          depotId: row['depot_id'] as String?,
          leadId: row['lead_id'] as String?),
      subtotal: (row['subtotal'] as num).toDouble(),
      discount: (row['discount'] as num).toDouble(),
      tax: (row['tax'] as num).toDouble(),
      total: (row['total'] as num).toDouble(),
      status:
          SalesOrderStatus.values.firstWhere((s) => s.name == row['status']),
      offVisitReason: row['off_visit_reason'] == null
          ? null
          : OffVisitReason.values
              .firstWhere((r) => r.name == row['off_visit_reason']),
      sapStatus: row['sap_status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  /// Shared with the quotation repository. Before this, the two encoders had
  /// diverged: this one omitted `customization`, so converting a customized
  /// quotation into a sales order silently discarded the measurements and the
  /// drawing the depot had signed off on.
  String _encodeLines(List<CartItem> items) => _lines.encode(items);

  Future<List<CartItem>> _decodeLines(String json,
          {String? depotId, String? leadId}) =>
      _lines.decode(json, depotId: depotId, leadId: leadId);

  static String _newId(String prefix) =>
      '$prefix-${(DateTime.now().microsecondsSinceEpoch + Random().nextInt(99999)) % 1000000}';
}
