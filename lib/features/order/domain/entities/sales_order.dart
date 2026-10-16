import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/domain/entities/off_visit_reason.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';

/// A confirmed sales order converted from a [Quotation] — lines may differ
/// from the source quotation (quantities edited/lines removed during
/// conversion).
class SalesOrder extends Equatable {
  const SalesOrder({
    required this.id,
    required this.quotationId,
    required this.lines,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.status,
    required this.sapStatus,
    required this.createdAt,
    this.depotId,
    this.shopName,
    this.leadId,
    this.leadDisplayName,
    this.offVisitReason,
  });

  final String id;
  final String quotationId;
  final String? depotId;
  final String? shopName;
  final String? leadId;
  final String? leadDisplayName;
  final List<CartItem> lines;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final SalesOrderStatus status;
  final OffVisitReason? offVisitReason;
  final String sapStatus;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        quotationId,
        depotId,
        shopName,
        leadId,
        leadDisplayName,
        lines,
        subtotal,
        discount,
        tax,
        total,
        status,
        offVisitReason,
        sapStatus,
        createdAt,
      ];
}
