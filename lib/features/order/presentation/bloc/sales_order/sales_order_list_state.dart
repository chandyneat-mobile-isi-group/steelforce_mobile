import 'package:equatable/equatable.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/entities/sales_order_status.dart';

/// Which slice of the order list the rep is looking at.
///
/// Mirrors the two segments the home Orders card already splits on — pending
/// vs. everything else — so tapping a segment and landing on the matching
/// filter is a straight line rather than a re-interpretation.
enum SalesOrderFilter { all, pending, confirmed }

sealed class SalesOrderListState extends Equatable {
  const SalesOrderListState();
  @override
  List<Object?> get props => [];
}

final class SalesOrderListLoading extends SalesOrderListState {
  const SalesOrderListLoading();
}

final class SalesOrderListLoaded extends SalesOrderListState {
  const SalesOrderListLoaded({required this.orders, required this.filter});

  /// Every order the local database holds, newest first — unfiltered, because
  /// the counts below have to describe the whole set no matter which filter is
  /// active. A tab that hides its own total is a tab nobody trusts.
  final List<SalesOrder> orders;

  final SalesOrderFilter filter;

  /// The orders actually rendered, in the order they are rendered.
  List<SalesOrder> get visibleOrders => switch (filter) {
        SalesOrderFilter.all => orders,
        SalesOrderFilter.pending => orders
            .where((o) => o.status == SalesOrderStatus.pending)
            .toList(growable: false),
        SalesOrderFilter.confirmed => orders
            .where((o) => o.status == SalesOrderStatus.confirmed)
            .toList(growable: false),
      };

  int get totalCount => orders.length;

  int get pendingCount =>
      orders.where((o) => o.status == SalesOrderStatus.pending).length;

  int get confirmedCount =>
      orders.where((o) => o.status == SalesOrderStatus.confirmed).length;

  /// Combined value of the *visible* orders.
  ///
  /// Scoped to the filter on purpose: a "confirmed" total that silently
  /// included pending orders would overstate committed revenue, which is the
  /// one number on this screen nobody should have to double-check.
  double get visibleTotal => visibleOrders.fold(0.0, (sum, o) => sum + o.total);

  bool get isEmpty => orders.isEmpty;

  SalesOrderListLoaded copyWith({
    List<SalesOrder>? orders,
    SalesOrderFilter? filter,
  }) =>
      SalesOrderListLoaded(
        orders: orders ?? this.orders,
        filter: filter ?? this.filter,
      );

  @override
  List<Object?> get props => [orders, filter];
}

final class SalesOrderListError extends SalesOrderListState {
  const SalesOrderListError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}
