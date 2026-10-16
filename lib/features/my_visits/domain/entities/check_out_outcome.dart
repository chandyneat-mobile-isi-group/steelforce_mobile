import 'package:equatable/equatable.dart';

/// How a visit ended. The rep picks one at check-out
/// (`check-in-check-out-mobile.md` §5).
enum CheckOutOutcome { withOrder, withoutOrder }

/// An order taken at the stop, as a check-out references it.
///
/// [clientId] is the quotation's id on this device — always known, even
/// offline. [quotationId] is the server's id once the quotation has synced;
/// the server also matches on [clientId], so it is optional.
class VisitOrderRef extends Equatable {
  const VisitOrderRef({
    required this.clientId,
    this.quotationId,
    this.type = 'quotation',
  });

  final String clientId;
  final String? quotationId;

  /// `quotation` today; `salesOrder` once that API exists.
  final String type;

  Map<String, Object?> toJson() =>
      {'clientId': clientId, 'quotationId': quotationId, 'type': type};

  static VisitOrderRef? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final clientId = raw['clientId'];
    if (clientId is! String || clientId.isEmpty) return null;
    final quotationId = raw['quotationId'];
    final type = raw['type'];
    return VisitOrderRef(
      clientId: clientId,
      quotationId: quotationId is String ? quotationId : null,
      type: type is String ? type : 'quotation',
    );
  }

  @override
  List<Object?> get props => [clientId, quotationId, type];
}

/// What the rep chose on the check-out sheet: with order (which) or without
/// (why). The sheet only offers "with order" when at least one order is
/// selected, matching the server's `Visit.OrderRequired` rule.
class CheckOutChoice extends Equatable {
  const CheckOutChoice.withOrder(this.orders)
      : outcome = CheckOutOutcome.withOrder,
        noOrderReason = null,
        noOrderNote = null;

  // A non-null reason, stored in a nullable field (it is null on the
  // with-order shape).
  const CheckOutChoice.withoutOrder({
    required String reason,
    this.noOrderNote,
  })  : noOrderReason = reason,
        outcome = CheckOutOutcome.withoutOrder,
        orders = const [];

  final CheckOutOutcome outcome;
  final List<VisitOrderRef> orders;
  final String? noOrderReason;
  final String? noOrderNote;

  @override
  List<Object?> get props => [outcome, orders, noOrderReason, noOrderNote];
}
