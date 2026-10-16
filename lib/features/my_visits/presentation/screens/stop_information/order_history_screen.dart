import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_builder.dart';
import 'package:steelforce/core/responsive/responsive_content_frame.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/order_history_mock_data.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/widgets/order_history/order_history_card.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/widgets/order_history/order_history_search_field.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/widgets/order_history/order_status_filter_bar.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/widgets/order_history/order_summary_banner.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({
    super.key,
    this.outletName,
  });

  static const String routeName = 'order_history';
  final String? outletName;

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  OrderHistoryStatus? _selectedStatusFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const List<OrderHistoryEntry> _orders = mockOrderHistory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LocalizedBuilder(builder: _buildContent);

  Widget _buildContent(BuildContext context) {
    final colors = context.appColors;

    final filteredOrders = _orders
        .where((o) =>
            (_selectedStatusFilter == null ||
                o.status == _selectedStatusFilter) &&
            o.matchesSearch(_searchQuery))
        .toList();

    final totalSpent =
        _orders.fold<double>(0, (sum, item) => sum + item.totalAmount);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: context.rh(56),
        iconTheme: IconThemeData(
          color: colors.textPrimary,
          size: context.rr(24),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order History (SAP)',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: context.rsp(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.outletName != null) ...[
              SizedBox(height: context.rh(2)),
              Text(
                widget.outletName!,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: context.rsp(11.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentFrame(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.pagePadding,
                  context.rh(8),
                  context.pagePadding,
                  context.rh(12),
                ),
                child: OrderSummaryBanner(
                  totalOrders: _orders.length,
                  totalRevenue: totalSpent,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
                child: OrderHistorySearchField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.pagePadding,
                  vertical: context.rh(12),
                ),
                child: OrderStatusFilterBar(
                  totalCount: _orders.length,
                  selected: _selectedStatusFilter,
                  onSelected: (status) =>
                      setState(() => _selectedStatusFilter = status),
                ),
              ),
              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Text(
                          'No orders found',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(14),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          context.pagePadding,
                          context.rh(4),
                          context.pagePadding,
                          context.rh(24),
                        ),
                        itemCount: filteredOrders.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: context.rh(12)),
                        itemBuilder: (context, index) =>
                            OrderHistoryCard(order: filteredOrders[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
