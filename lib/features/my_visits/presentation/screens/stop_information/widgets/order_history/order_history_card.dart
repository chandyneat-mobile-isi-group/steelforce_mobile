import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/order_history_mock_data.dart';

/// One order in the history list: ID, SAP doc and status, the items, and the
/// date, terms, amount and re-order action.
class OrderHistoryCard extends StatelessWidget {
  const OrderHistoryCard({super.key, required this.order});

  final OrderHistoryEntry order;

  Color _statusColor(OrderHistoryStatus status) {
    switch (status) {
      case OrderHistoryStatus.completed:
        return Colors.green;
      case OrderHistoryStatus.inDelivery:
        return Colors.blue;
      case OrderHistoryStatus.pending:
        return Colors.orange;
      case OrderHistoryStatus.cancelled:
        return Colors.red;
    }
  }

  String _statusText(OrderHistoryStatus status) {
    switch (status) {
      case OrderHistoryStatus.completed:
        return 'COMPLETED';
      case OrderHistoryStatus.inDelivery:
        return 'IN DELIVERY';
      case OrderHistoryStatus.pending:
        return 'PENDING';
      case OrderHistoryStatus.cancelled:
        return 'CANCELLED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(context.rr(16)),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(context.rr(16)),
        border: Border.all(color: colors.border),
        boxShadow: colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Order ID & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderId,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: context.rsp(14.5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: context.rh(2)),
                  Text(
                    'SAP DOC: ${order.sapDocNum}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.rw(8),
                  vertical: context.rh(4),
                ),
                decoration: BoxDecoration(
                  color: _statusColor(order.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(context.rr(6)),
                ),
                child: Text(
                  _statusText(order.status),
                  style: TextStyle(
                    color: _statusColor(order.status),
                    fontSize: context.rsp(10.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.rh(12)),

          // Order Items Description
          Text(
            order.itemsSummary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12.5),
              height: 1.35,
            ),
          ),
          SizedBox(height: context.rh(12)),
          Divider(color: colors.border, height: 1),
          SizedBox(height: context.rh(12)),

          // Footer Details & Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${order.orderDate} · ${order.paymentTerm}',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11.5),
                    ),
                  ),
                  SizedBox(height: context.rh(2)),
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: context.rsp(16),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Re-ordering items from ${order.orderId}...'),
                    ),
                  );
                },
                icon: Icon(Icons.refresh_rounded, size: context.rr(16)),
                label: const Text('Re-order'),
                style: TextButton.styleFrom(
                  foregroundColor: scheme.primary,
                  textStyle: TextStyle(
                    fontSize: context.rsp(12.5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
