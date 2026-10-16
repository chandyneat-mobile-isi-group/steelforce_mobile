import 'package:equatable/equatable.dart';

/// Made-to-order pricing is intentionally never resolved from the local
/// price table — it always goes through this separate quoting path, which
/// today is a mock stand-in for an online SAP request.
class MtoQuote extends Equatable {
  const MtoQuote({required this.available, required this.message, this.price});

  final bool available;
  final String message;
  final double? price;

  @override
  List<Object?> get props => [available, message, price];
}
