import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/cart_item.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/demo_cart_promotions.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/cart_item_tile.dart';
import 'package:steelforce/features/order/presentation/widgets/promotion/promotion_detail_sheet.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/discount_preset_chips.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

class QuotationLineTile extends StatelessWidget {
  const QuotationLineTile({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    this.onDiscountChanged,
    this.showStockStatus = false,
  });

  final CartItem item;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;
  final ValueChanged<double>? onDiscountChanged;
  final bool showStockStatus;

  @override
  Widget build(BuildContext context) {
    // Static while the shape is being reviewed. The real source is
    // `PromotionCubit`, which returns this same type — but it is not provided
    // on the sales-order screen this tile also renders on, so reading it here
    // would crash a screen that never asked about promotions.
    final promo = DemoCartPromotions.evaluate(item);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CartItemTile(
          item: item,
          onQuantityChanged: onQuantityChanged,
          onRemove: onRemove,
          promotion: promo,
          onPromotionDetail: promo == null
              ? null
              : () => showPromotionDetailSheet(
                    context,
                    promotion: promo.promotion,
                    evaluation: promo,
                  ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Row(
            children: [
              if (onDiscountChanged != null)
                Expanded(
                  child: DiscountPresetChips(
                    selected: item.discountPercent,
                    onSelected: onDiscountChanged!,
                  ),
                ),
              if (showStockStatus)
                _StockStatusChip(
                  available: item.product.isAvailable,
                  low: item.product.isBelowMinStock,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockStatusChip extends StatelessWidget {
  const _StockStatusChip({required this.available, required this.low});
  final bool available;
  final bool low;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final (label, color) = !available
        ? ('orders.sales_order.stock_out'.tr, colors.success)
        : low
            ? ('orders.sales_order.stock_low'.tr, colors.warningAlt)
            : ('orders.sales_order.stock_in'.tr, colors.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: context.rsp(10.5),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
