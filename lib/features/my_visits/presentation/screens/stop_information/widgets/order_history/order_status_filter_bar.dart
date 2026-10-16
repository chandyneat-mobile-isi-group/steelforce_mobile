import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/my_visits/presentation/screens/stop_information/order_history_mock_data.dart';

/// The status tabs over the order list. A null [selected] means "All".
class OrderStatusFilterBar extends StatelessWidget {
  const OrderStatusFilterBar({
    super.key,
    required this.totalCount,
    required this.selected,
    required this.onSelected,
  });

  final int totalCount;
  final OrderHistoryStatus? selected;
  final ValueChanged<OrderHistoryStatus?> onSelected;

  static const _tabs = [
    (OrderHistoryStatus.completed, 'Completed'),
    (OrderHistoryStatus.inDelivery, 'In Delivery'),
    (OrderHistoryStatus.pending, 'Pending'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterTab(
            label: 'All ($totalCount)',
            isSelected: selected == null,
            onTap: () => onSelected(null),
          ),
          for (final (status, label) in _tabs) ...[
            SizedBox(width: context.rw(8)),
            _FilterTab(
              label: label,
              isSelected: selected == status,
              onTap: () => onSelected(status),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(context.rr(8)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(12),
          vertical: context.rh(6),
        ),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : colors.card,
          borderRadius: BorderRadius.circular(context.rr(8)),
          border: Border.all(
            color: isSelected ? scheme.primary : colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? scheme.onPrimary : colors.textPrimary,
            fontSize: context.rsp(11.5),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
