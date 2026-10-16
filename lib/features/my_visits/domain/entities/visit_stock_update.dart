import 'package:equatable/equatable.dart';
import 'package:steelforce/features/my_visits/domain/entities/stock_level.dart';

/// One product's stock status captured during field work.
///
/// Captured either at a route stop (then [stopId] is set) or during a depot
/// count (then [depotId] is set) — exactly one of the two is non-null.
class VisitStockUpdate extends Equatable {
  const VisitStockUpdate({
    required this.id,
    this.stopId,
    this.depotId,
    required this.productId,
    required this.productName,
    required this.stockLevel,
    required this.notes,
  }) : assert((stopId != null) != (depotId != null),
            'A stock update belongs to exactly one of stop or depot');

  final String id;
  final String? stopId;
  final String? depotId;
  final String productId;
  final String productName;
  final StockLevel stockLevel;
  final String notes;

  @override
  List<Object?> get props => [id, stopId, depotId, productId, stockLevel];
}
