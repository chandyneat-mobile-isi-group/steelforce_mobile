import 'package:equatable/equatable.dart';

/// Deliberately lightweight (not `order`'s `CartItem`) so this feature only
/// depends on `order`'s read-only `ProductRepository` for product lookup,
/// not its cart/pricing model — keeps the two features loosely coupled.
class VisitOrderLine extends Equatable {
  const VisitOrderLine({
    required this.id,
    required this.stopId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
  });

  final String id;
  final String stopId;
  final String productId;
  final String productName;
  final double quantity;
  final String unit;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;

  @override
  List<Object?> get props => [id, stopId, productId, quantity, unit, unitPrice];
}
