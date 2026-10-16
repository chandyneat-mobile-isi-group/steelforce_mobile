import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// The order count and total sales value across the outlet's history.
class OrderSummaryBanner extends StatelessWidget {
  const OrderSummaryBanner({
    super.key,
    required this.totalOrders,
    required this.totalRevenue,
  });

  final int totalOrders;
  final double totalRevenue;

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
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.rr(10)),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: scheme.primary,
                    size: context.rr(22),
                  ),
                ),
                SizedBox(width: context.rw(12)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Orders',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: context.rsp(11.5),
                      ),
                    ),
                    SizedBox(height: context.rh(2)),
                    Text(
                      '$totalOrders Orders',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: context.rsp(15),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            height: context.rh(32),
            width: 1,
            color: colors.border,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: context.rw(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Sales Value',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: context.rsp(11.5),
                    ),
                  ),
                  SizedBox(height: context.rh(2)),
                  Text(
                    '\$${totalRevenue.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: context.rsp(15),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
