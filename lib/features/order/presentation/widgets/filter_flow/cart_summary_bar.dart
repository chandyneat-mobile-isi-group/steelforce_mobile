import 'package:flutter/material.dart';
import 'package:steelforce/features/order/presentation/widgets/quotation/pricing_text.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Running total of what the quantity steppers have put in the quotation.
///
/// Necessary precisely because there is no "Add to cart" button any more: when
/// a `+` tap is the whole commit action, the rep needs an unambiguous, always
/// current answer to "did that land, and what am I at now".
///
/// Purely presentational — it renders the numbers it is handed and reports
/// taps. Totals are computed by `CartCubit`, which stays the single source of
/// truth for quotation money.
class CartSummaryBar extends StatelessWidget {
  const CartSummaryBar({
    super.key,
    required this.lineCount,
    required this.totalQuantity,
    required this.subtotal,
    this.onTap,
  });

  final int lineCount;
  final double totalQuantity;

  /// The running total, or **null** while any line is waiting for HQ pricing.
  ///
  /// Null renders "Waiting for HQ" rather than a figure. A subtotal that
  /// silently omits the unpriced lines is a smaller, wronger number than no
  /// subtotal at all — and it is the one sitting in front of the depot.
  final double? subtotal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      child: lineCount == 0
          ? const SizedBox(width: double.infinity)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: scheme.primary.withValues(alpha: 0.30)),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_cart_rounded,
                          size: context.rr(19), color: scheme.primary),
                      SizedBox(width: context.rw(10)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'orders.guided_filter.cart_lines'
                                  .trParams({'count': lineCount}),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: context.rsp(13),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: context.rh(1)),
                            Text(
                              'orders.guided_filter.cart_units'.trParams(
                                  {'count': totalQuantity.toStringAsFixed(0)}),
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: context.rsp(11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.horizontal,
                            child: child,
                          ),
                        ),
                        child: Text(
                          PricingText.amount(subtotal),
                          key: ValueKey('subtotal-$subtotal'),
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: context.rsp(16),
                            fontWeight: FontWeight.w900,
                          ),
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
