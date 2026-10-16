import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Restarts product selection without touching the cart.
///
/// A quotation is normally several different products, and before this the
/// only way to get back to the category list was to clear chips one at a time.
/// This is the "next line item" affordance: category, filters and results
/// reset, everything already in the quotation stays.
class FindNewProductButton extends StatelessWidget {
  const FindNewProductButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: scheme.primary.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded,
                      size: context.rr(19), color: scheme.primary),
                  SizedBox(width: context.rw(8)),
                  Text(
                    'orders.guided_filter.find_new_product'.tr,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: context.rsp(14),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Muted variant for use inside a dense results header, where the full-width
  /// call to action would shout over the products themselves.
  static Widget compact(BuildContext context, {required VoidCallback onTap}) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surfaceSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: context.rr(15), color: scheme.primary),
            SizedBox(width: context.rw(5)),
            Text(
              'orders.guided_filter.find_new_product'.tr,
              style: TextStyle(
                color: scheme.primary,
                fontSize: context.rsp(12),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
