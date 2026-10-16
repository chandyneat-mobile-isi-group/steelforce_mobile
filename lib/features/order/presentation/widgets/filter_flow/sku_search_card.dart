import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/product.dart';

/// A lightweight, compact card representing a single SKU / Material search result.
///
/// Displayed during free-text material searches instead of immediately rendering
/// full, heavy [ProductResultCard]s. Tapping this card selects the SKU and reveals
/// its full [ProductResultCard].
class SkuSearchCard extends StatelessWidget {
  const SkuSearchCard({
    super.key,
    required this.product,
    required this.isSelected,
    required this.onTap,
    this.specLine,
  });

  final Product product;
  final bool isSelected;
  final VoidCallback onTap;
  final String? specLine;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    final skuText = product.sku.isNotEmpty
        ? product.sku
        : (product.materialCode.isNotEmpty
            ? product.materialCode
            : product.code);

    final details = [
      if (product.familyName.isNotEmpty) product.familyName,
      if (specLine != null && specLine!.trim().isNotEmpty)
        specLine!.trim()
      else if (product.size.trim().isNotEmpty)
        product.size.trim(),
      if (product.unit.trim().isNotEmpty) product.unit.trim(),
    ].join(' · ');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color:
            isSelected ? scheme.primary.withValues(alpha: 0.06) : colors.card,
        borderRadius: BorderRadius.circular(context.rr(12)),
        border: Border.all(
          color: isSelected ? scheme.primary : colors.border,
          width: isSelected ? 1.6 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(context.rr(12)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(12),
              vertical: context.rh(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: context.rw(6),
                              vertical: context.rh(2),
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? scheme.primary.withValues(alpha: 0.15)
                                  : colors.surfaceSoft,
                              borderRadius:
                                  BorderRadius.circular(context.rr(4)),
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary.withValues(alpha: 0.4)
                                    : colors.border,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'SKU: $skuText',
                              style: TextStyle(
                                color: isSelected
                                    ? scheme.primary
                                    : colors.textSecondary,
                                fontSize: context.rsp(10.5),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (product.warehouseCode.isNotEmpty) ...[
                            SizedBox(width: context.rw(6)),
                            Text(
                              product.warehouseCode,
                              style: TextStyle(
                                color: colors.textHint,
                                fontSize: context.rsp(10),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: context.rh(4)),
                      Text(
                        context.localized(product.displayName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: context.rsp(13),
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (details.isNotEmpty) ...[
                        SizedBox(height: context.rh(3)),
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: context.rsp(11),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: context.rw(8)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isSelected
                      ? Container(
                          key: const ValueKey('selected_check'),
                          padding: EdgeInsets.all(context.rr(4)),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: context.rr(14),
                            color: scheme.onPrimary,
                          ),
                        )
                      : Icon(
                          key: const ValueKey('unselected_arrow'),
                          Icons.chevron_right_rounded,
                          size: context.rr(20),
                          color: colors.iconMuted,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
