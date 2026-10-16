import 'package:equatable/equatable.dart';

/// Why an order line cannot be committed, or [none] when it can.
///
/// Ordered by which answer helps the rep most: a SKU that cannot be sold at all
/// outranks a quantity that merely needs lowering, because "pick another
/// location" and "ask for fewer" are different conversations with the depot.
enum OrderLineIssue {
  none,

  /// Zero or negative. Removing a line is a separate gesture from asking for
  /// none of it, so this never silently becomes a delete.
  nonPositiveQuantity,

  /// The SKU no longer resolves — a deleted or re-keyed material.
  ///
  /// An **identity** problem, not an availability one. This is deliberately no
  /// longer raised for a material that merely has nothing on hand: material
  /// selection is independent of stock, and refusing the line on a synced
  /// figure the materials API never supplies blocked every order.
  skuUnavailable,
}

/// The verdict on one requested SKU + quantity, with the numbers the UI needs
/// to explain it. Carries the figures rather than a formatted string so the
/// message can be localised at the point of display.
class OrderLineValidation extends Equatable {
  const OrderLineValidation({
    required this.issue,
    required this.requestedQuantity,
    required this.availableQuantity,
    required this.isStockStale,
  });

  const OrderLineValidation.valid({
    required this.requestedQuantity,
    required this.availableQuantity,
    required this.isStockStale,
  }) : issue = OrderLineIssue.none;

  final OrderLineIssue issue;
  final double requestedQuantity;

  /// `stock.quantity - stock.reserved` for the SKU's own warehouse, as last
  /// synced. Never a live SAP figure — see [isStockStale].
  final double availableQuantity;

  /// True when [availableQuantity] came from the local cache without a fresh
  /// SAP confirmation, which is every read this app makes today (ADR-002:
  /// the order UI never calls SAP directly). Surfaced so the UI can say
  /// "as of last sync" instead of implying a real-time reservation.
  final bool isStockStale;

  bool get isValid => issue == OrderLineIssue.none;

  /// The localisation key explaining [issue]. Null when the line is valid.
  String? get messageKey => switch (issue) {
        OrderLineIssue.none => null,
        OrderLineIssue.nonPositiveQuantity =>
          'orders.order_line.error_quantity_positive',
        OrderLineIssue.skuUnavailable =>
          'orders.order_line.error_sku_unavailable',
      };

  @override
  List<Object?> get props =>
      [issue, requestedQuantity, availableQuantity, isStockStale];
}
