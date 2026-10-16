import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:steelforce/core/usecase/usecase.dart';
import 'package:steelforce/features/order/domain/entities/sales_order.dart';
import 'package:steelforce/features/order/domain/usecases/watch_sales_orders.dart';
import 'package:steelforce/features/order/presentation/bloc/sales_order/sales_order_list_state.dart';

/// Drives the sales-order list off a live [WatchSalesOrders] stream, the same
/// shape `RouteDashboardCubit` uses.
///
/// Reading the stream rather than a one-shot fetch is what makes the list
/// correct without a refresh: an order created on the Sales Order screen, or a
/// status moved by a sync, lands here on its own. The local database is the
/// source of truth (ADR-002), so this works with no connectivity.
class SalesOrderListCubit extends Cubit<SalesOrderListState> {
  SalesOrderListCubit({
    required WatchSalesOrders watchSalesOrders,
    SalesOrderFilter initialFilter = SalesOrderFilter.all,
  })  : _watchSalesOrders = watchSalesOrders,
        _filter = initialFilter,
        super(const SalesOrderListLoading()) {
    _subscribe();
  }

  final WatchSalesOrders _watchSalesOrders;

  /// Held outside the state because the state starts as
  /// [SalesOrderListLoading], which carries no filter. Keeping it only in the
  /// state meant a caller opening straight into "pending" was silently ignored
  /// — the first snapshot arrived and reset to `all`.
  SalesOrderFilter _filter;
  StreamSubscription<List<SalesOrder>>? _subscription;

  void _subscribe() {
    _subscription?.cancel();
    _subscription = _watchSalesOrders(const NoParams()).listen(
      (orders) {
        // Newest first. The repository does not promise an order, and a list
        // whose rows shuffle between emissions is worse than one sorted
        // "wrongly" but stably — the rep loses their place mid-scroll.
        final sorted = [...orders]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // `_filter` survives every emission, so a row changing underneath the
        // rep never yanks them out of the list they were working through.
        emit(SalesOrderListLoaded(orders: sorted, filter: _filter));
      },
      // A stream error must not take the screen down (FS-NN-4). The message is
      // resolved to translated copy at the widget, never rendered raw.
      onError: (Object e) => emit(SalesOrderListError(e.toString())),
    );
  }

  void setFilter(SalesOrderFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    // Recorded even while loading — the first snapshot then arrives already
    // filtered, with no flash of the wrong list.
    final current = state;
    if (current is SalesOrderListLoaded) {
      emit(current.copyWith(filter: filter));
    }
  }

  /// Re-attaches the stream, re-reading the local cache. Used by
  /// pull-to-refresh and by the error state's retry.
  void reload() => _subscribe();

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
