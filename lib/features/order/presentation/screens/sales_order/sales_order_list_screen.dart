import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/di/injection_container.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/presentation/bloc/sales_order/sales_order_list_cubit.dart';
import 'package:steelforce/features/order/presentation/bloc/sales_order/sales_order_list_state.dart';
import 'package:steelforce/features/order/presentation/screens/sales_order/sales_order_detail_screen.dart';
import 'package:steelforce/features/order/presentation/widgets/sales_order/sales_order_card.dart';

/// Every sales order the rep has raised, newest first, filterable by status.
///
/// This is what the home Orders card opens. Reads the local database through a
/// live stream, so it is fully usable offline and updates itself when an order
/// is created or a sync moves a status — no refresh required.
///
/// Not to be confused with `SalesOrderScreen`, which *creates* an order from a
/// quotation. This one only reads.
class SalesOrderListScreen extends StatelessWidget {
  const SalesOrderListScreen({super.key, this.initialFilter});

  static const routeName = 'order-sales-order-list';

  /// Lets the caller land on a specific segment — the home card's "pending"
  /// badge opens straight into pending rather than making the rep filter
  /// again.
  final SalesOrderFilter? initialFilter;

  /// Opens the list. One line from any tap handler:
  /// `onTap: () => SalesOrderListScreen.open(context)`.
  static Future<void> open(BuildContext context,
          {SalesOrderFilter? initialFilter}) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: routeName),
          builder: (_) => LocalizedBuilder(
            builder: (_) => SalesOrderListScreen(initialFilter: initialFilter),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = sl<SalesOrderListCubit>();
        if (initialFilter != null) cubit.setFilter(initialFilter!);
        return cubit;
      },
      child: const _SalesOrderListView(),
    );
  }
}

class _SalesOrderListView extends StatelessWidget {
  const _SalesOrderListView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        // Back button in `leading`, not packed into `title` with a Row. The
        // Row form overflows at large text scales: AppBar sizes `actions`
        // first, and what is left over can be narrower than an IconButton's
        // 48dp minimum, which cannot shrink to fit.
        leading: IconButton(
          tooltip: 'common.back'.tr,
          icon: Icon(Icons.chevron_left_rounded,
              color: colors.textPrimary, size: context.rsp(28)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'orders.sales_order.list_title'.tr,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: context.rsp(17),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<SalesOrderListCubit, SalesOrderListState>(
          builder: (context, state) => switch (state) {
            SalesOrderListLoading() => const _ListSkeleton(),
            SalesOrderListError(:final message) => _ErrorView(message: message),
            SalesOrderListLoaded() => _LoadedView(state: state),
          },
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});
  final SalesOrderListLoaded state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SalesOrderListCubit>();
    final visible = state.visibleOrders;

    return Column(
      children: [
        _FilterBar(state: state, onChanged: cubit.setFilter),
        if (!state.isEmpty) _TotalsBanner(state: state),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => cubit.reload(),
            child: visible.isEmpty
                // Still scrollable, or pull-to-refresh is dead exactly when
                // the rep most wants it.
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: context.rh(80)),
                      _EmptyView(filter: state.filter),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(context.rw(16), context.rh(4),
                        context.rw(16), context.rh(20)),
                    itemCount: visible.length,
                    // Keyed by order id so a filter change reuses elements
                    // instead of rebuilding every row.
                    itemBuilder: (_, i) {
                      final order = visible[i];
                      return SalesOrderCard(
                        key: ValueKey(order.id),
                        order: order,
                        onTap: () =>
                            SalesOrderDetailScreen.open(context, order),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

/// Status segments, each carrying its own count.
///
/// The count is what makes this a summary rather than three buttons: a rep can
/// read "4 pending" without selecting the tab.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state, required this.onChanged});

  final SalesOrderListLoaded state;
  final ValueChanged<SalesOrderFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          context.rw(16), context.rh(4), context.rw(16), context.rh(10)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              filter: SalesOrderFilter.all,
              label: 'orders.sales_order.filter_all'.tr,
              count: state.totalCount,
              selected: state.filter == SalesOrderFilter.all,
              onTap: () => onChanged(SalesOrderFilter.all),
            ),
            SizedBox(width: context.rw(8)),
            _FilterChip(
              filter: SalesOrderFilter.pending,
              label: 'orders.sales_order.status_pending'.tr,
              count: state.pendingCount,
              selected: state.filter == SalesOrderFilter.pending,
              onTap: () => onChanged(SalesOrderFilter.pending),
            ),
            SizedBox(width: context.rw(8)),
            _FilterChip(
              filter: SalesOrderFilter.confirmed,
              label: 'orders.sales_order.status_confirmed'.tr,
              count: state.confirmedCount,
              selected: state.filter == SalesOrderFilter.confirmed,
              onTap: () => onChanged(SalesOrderFilter.confirmed),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  /// Only identity — the chip renders from [label]/[count]. It exists so the
  /// chip carries a stable key: its label is the same word the status badge on
  /// each card uses, which makes a text-based finder ambiguous.
  final SalesOrderFilter filter;

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count',
      child: Material(
        key: ValueKey('sales-order-filter-${filter.name}'),
        color: selected ? colors.accentPurple : colors.card,
        borderRadius: BorderRadius.circular(context.rr(999)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rr(999)),
          child: AnimatedContainer(
            // Short and eased — a filter should feel immediate, not animated
            // at (§6).
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
                horizontal: context.rw(14), vertical: context.rh(8)),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(context.rr(999)),
              border: Border.all(
                  color: selected ? colors.accentPurple : colors.border),
            ),
            child: Text(
              '$label  $count',
              style: TextStyle(
                color: selected ? Colors.white : colors.textSecondary,
                fontSize: context.rsp(12.5),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Combined value of whatever is currently visible.
class _TotalsBanner extends StatelessWidget {
  const _TotalsBanner({required this.state});
  final SalesOrderListLoaded state;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final total =
        NumberFormat.currency(locale: context.languageCode, symbol: r'$')
            .format(state.visibleTotal);

    return Container(
      margin: EdgeInsets.fromLTRB(
          context.rw(16), 0, context.rw(16), context.rh(10)),
      padding: EdgeInsets.symmetric(
          horizontal: context.rw(14), vertical: context.rh(10)),
      decoration: BoxDecoration(
        color: colors.surfaceSoft,
        borderRadius: BorderRadius.circular(context.rr(14)),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_rounded,
              size: context.rr(16), color: colors.iconMuted),
          SizedBox(width: context.rw(8)),
          Expanded(
            child: Text(
              'orders.sales_order.selected_total'.tr,
              style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(12),
                  fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            total,
            style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(14),
                fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.filter});
  final SalesOrderFilter filter;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // A filtered-empty list is a different situation from having no orders at
    // all, and saying "no orders yet" to someone with twelve confirmed ones
    // reads as a bug.
    final messageKey = switch (filter) {
      SalesOrderFilter.all => 'orders.no_orders',
      SalesOrderFilter.pending => 'orders.sales_order.empty_pending',
      SalesOrderFilter.confirmed => 'orders.sales_order.empty_confirmed',
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rw(32)),
      child: Column(
        children: [
          Icon(Icons.receipt_long_rounded,
              size: context.rr(48), color: colors.iconMuted),
          SizedBox(height: context.rh(14)),
          Text(
            messageKey.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: context.rsp(13.5),
                height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.rw(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: context.rr(44), color: colors.warning),
            SizedBox(height: context.rh(12)),
            // Translated copy, not the raw exception (FS-NN-4). The technical
            // text stays in the logs where it is useful.
            Text(
              'orders.sales_order.load_failed'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(13.5),
                  height: 1.45),
            ),
            SizedBox(height: context.rh(16)),
            OutlinedButton.icon(
              onPressed: () => context.read<SalesOrderListCubit>().reload(),
              icon: Icon(Icons.refresh_rounded, size: context.rr(18)),
              label: Text('common.retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shape-matched placeholder rows, so the first real frame does not shift the
/// layout under the rep's thumb.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          context.rw(16), context.rh(12), context.rw(16), context.rh(20)),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        height: context.rh(118),
        margin: EdgeInsets.only(bottom: context.rh(10)),
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(context.rr(16)),
          border: Border.all(color: colors.border),
        ),
      ),
    );
  }
}
