import 'package:equatable/equatable.dart';

enum CollectionMethod { cash, check, bankTransfer }

class VisitCollection extends Equatable {
  const VisitCollection({
    required this.id,
    required this.stopId,
    required this.amount,
    required this.method,
    required this.reference,
    required this.notes,
  });

  final String id;
  final String stopId;
  final double amount;
  final CollectionMethod method;
  final String reference;
  final String notes;

  @override
  List<Object?> get props => [id, stopId, amount, method, reference];
}
