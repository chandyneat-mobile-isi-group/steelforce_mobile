import 'package:equatable/equatable.dart';

class VisitReturn extends Equatable {
  const VisitReturn({
    required this.id,
    required this.stopId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.reason,
  });

  final String id;
  final String stopId;
  final String productId;
  final String productName;
  final double quantity;
  final String reason;

  @override
  List<Object?> get props => [id, stopId, productId, quantity, reason];
}
