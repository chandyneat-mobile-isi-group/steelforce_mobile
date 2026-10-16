import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/features/order/domain/entities/mobile_price.dart';

/// What this depot pays for one material, as the backend last said it.
///
/// ## Nothing here computes a price
///
/// The amount and the currency are transcribed from `MobilePrice`, which is
/// transcribed from the pricing endpoint. SAP's conditions are not re-derived
/// on the handset and the catalogue figure on `Product.pricing` is never used
/// as a stand-in — a quoted price a depot can hold a rep to has exactly one
/// source, and a plausible local substitute is worse than an honest absence.
///
/// ## Why the states are not collapsed
///
/// "Loading", "this depot has no price for this material" and "the request
/// failed" are three different things a rep has to act on differently: wait,
/// call the office, or retry. Rendering them as one grey dash sends a rep
/// nowhere. Only [PricingState.error] offers a retry — [PricingState.unavailable]
/// is a settled answer from the backend, and retrying asks the same question.
class MaterialPriceView extends StatelessWidget {
  const MaterialPriceView({
    super.key,
    required this.price,
    this.manualPrice,
    this.unit,
    this.onRetry,
    this.onInputPrice,
  });

  /// Null when the screen has no pricing context at all — renders nothing,
  /// unless a manualPrice or onInputPrice is provided.
  final MobilePrice? price;

  /// A manual unit price override in USD set by the sales rep.
  final double? manualPrice;

  /// The material's selling unit, appended as "/ KG". Identification that
  /// comes off the catalogue row, not from the pricing call.
  final String? unit;

  final VoidCallback? onRetry;

  /// Triggered when the user wants to input or edit the price directly.
  final VoidCallback? onInputPrice;

  @override
  Widget build(BuildContext context) {
    final price = this.price;
    final manualPrice = this.manualPrice;

    // Outside pricing context: if no price, no manual price, and no input action,
    // render nothing to keep the card reusable outside quotation flow.
    if (price == null && manualPrice == null && onInputPrice == null) {
      return const SizedBox.shrink();
    }

    final Widget current;
    final Object stateKey;

    if (price != null && price.isBusy) {
      current = const _PriceLoading();
      stateKey = 'busy';
    } else if (price != null && price.hasAmount) {
      // Requirement 1: If material already got price successfully from backend,
      // hide manual price completely and display official backend price.
      current = _PriceAmount(price: price, unit: unit);
      stateKey = 'amount:${price.price}:${price.currency}';
    } else if (manualPrice != null && manualPrice > 0) {
      // Requirement 2: Manual price is allowed ONLY when material cannot get
      // price from backend (price == null or !price.hasAmount).
      current = _ManualPriceAmount(
        manualPrice: manualPrice,
        unit: unit,
        onInputPrice: onInputPrice,
      );
      stateKey = 'manual:$manualPrice';
    } else {
      current = _PriceMissing(
        price: price,
        onRetry: onRetry,
        onInputPrice: onInputPrice,
      );
      stateKey = 'missing:${price?.errorKind}';
    }

    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return current;
    }

    return AnimatedSize(
      duration: AppDurations.medium,
      curve: AppCurves.standard,
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: AppDurations.medium,
        switchInCurve: AppCurves.emphasized,
        switchOutCurve: AppCurves.standard,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(stateKey), child: current),
      ),
    );
  }
}

/// The figure, plus whether it is still known to be current.
class _PriceAmount extends StatelessWidget {
  const _PriceAmount({required this.price, this.unit});

  final MobilePrice price;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priceColor = isDark ? const Color(0xFF60A5FA) : colors.brandNavy;
    final unit = this.unit?.trim() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            formatMaterialPrice(price),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: priceColor,
              fontSize: context.rsp(18.5),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ),
        if (unit.isNotEmpty) ...[
          SizedBox(width: context.rw(4)),
          Text(
            '/ $unit',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        SizedBox(width: context.rw(6)),
        if (price.isLive)
          _PriceTag(
            label: 'orders.pricing.live'.tr,
            color: scheme.primary,
            dot: true,
          )
        else
          _PriceTag(
            label: 'orders.pricing.not_live'.tr,
            color: colors.textSecondary,
            dot: false,
          ),
      ],
    );
  }
}

class _ManualPriceAmount extends StatelessWidget {
  const _ManualPriceAmount({
    required this.manualPrice,
    this.unit,
    this.onInputPrice,
  });

  final double manualPrice;
  final String? unit;
  final VoidCallback? onInputPrice;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priceColor = isDark ? const Color(0xFF60A5FA) : colors.brandNavy;
    final unit = this.unit?.trim() ?? '';
    final formatted = NumberFormat('#,##0.00').format(manualPrice);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            '\$$formatted',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: priceColor,
              fontSize: context.rsp(18.5),
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ),
        if (unit.isNotEmpty) ...[
          SizedBox(width: context.rw(4)),
          Text(
            '/ $unit',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(12),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        SizedBox(width: context.rw(6)),
        InkWell(
          onTap: onInputPrice,
          borderRadius: BorderRadius.circular(context.rr(4)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.rw(5),
              vertical: context.rh(2),
            ),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(context.rr(4)),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '(Manual USD)',
                  style: TextStyle(
                    fontSize: context.rsp(9.5),
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
                SizedBox(width: context.rw(2)),
                Icon(
                  Icons.edit_outlined,
                  size: context.rr(10),
                  color: scheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PriceLoading extends StatelessWidget {
  const _PriceLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        SizedBox(
          width: context.rr(11),
          height: context.rr(11),
          child: CircularProgressIndicator(
            strokeWidth: 1.8,
            color: colors.textSecondary,
          ),
        ),
        SizedBox(width: context.rw(7)),
        Flexible(
          child: Text(
            'orders.pricing.loading'.tr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(11.5),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// No figure to show — and which of the several reasons it is.
class _PriceMissing extends StatelessWidget {
  const _PriceMissing({
    this.price,
    this.onRetry,
    this.onInputPrice,
  });

  final MobilePrice? price;
  final VoidCallback? onRetry;
  final VoidCallback? onInputPrice;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final retryable = price?.isRetryable == true && onRetry != null;
    final reasonText = price != null ? _reasonKey(price!).tr : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Note: Material doesn't have price
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.rw(6),
            vertical: context.rh(2.5),
          ),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(context.rr(4)),
            border: Border.all(
              color: colors.warning.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: context.rr(11),
                color: colors.warningAlt,
              ),
              SizedBox(width: context.rw(4)),
              Flexible(
                child: Text(
                  "Material doesn't have price",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.warningAlt,
                    fontSize: context.rsp(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (reasonText.isNotEmpty) ...[
          SizedBox(height: context.rh(2)),
          Text(
            reasonText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: context.rsp(10.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (onInputPrice != null) ...[
          SizedBox(height: context.rh(4)),
          Wrap(
            spacing: context.rw(6),
            runSpacing: context.rh(4),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              InkWell(
                onTap: onInputPrice,
                borderRadius: BorderRadius.circular(context.rr(6)),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.rw(8),
                    vertical: context.rh(3),
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(context.rr(6)),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: context.rr(13),
                        color: scheme.primary,
                      ),
                      SizedBox(width: context.rw(3)),
                      Text(
                        'Input Price (USD)',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: context.rsp(11),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (retryable) _retryButton(context, scheme),
            ],
          ),
        ] else if (retryable) ...[
          SizedBox(height: context.rh(3)),
          _retryButton(context, scheme),
        ],
      ],
    );
  }

  Widget _retryButton(BuildContext context, ColorScheme scheme) {
    return InkWell(
      onTap: onRetry,
      borderRadius: BorderRadius.circular(context.rr(4)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.rw(4),
          vertical: context.rh(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded,
                size: context.rr(12), color: scheme.primary),
            SizedBox(width: context.rw(3)),
            Text(
              'orders.pricing.retry'.tr,
              style: TextStyle(
                color: scheme.primary,
                fontSize: context.rsp(11),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _reasonKey(MobilePrice price) => switch (price.errorKind) {
        PricingErrorKind.networkUnavailable => 'orders.pricing.offline',
        PricingErrorKind.backendUnavailable => 'orders.pricing.backend_down',
        PricingErrorKind.unauthorized => 'orders.pricing.unauthorized',
        PricingErrorKind.depotNotFound => 'orders.pricing.no_depot',
        PricingErrorKind.depotNotPriceable => 'orders.pricing.not_priceable',
        PricingErrorKind.noPrice => 'orders.pricing.no_price',
        PricingErrorKind.none => price.state == PricingState.error
            ? 'orders.pricing.unavailable'
            : 'orders.pricing.no_price',
        PricingErrorKind.unknown => 'orders.pricing.unavailable',
      };
}

class _PriceTag extends StatelessWidget {
  const _PriceTag(
      {required this.label, required this.color, required this.dot});

  final String label;
  final Color color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot) ...[
          Container(
            width: context.rr(5),
            height: context.rr(5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: context.rw(4)),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: context.rsp(10),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// The amount written in the currency the backend sent with it.
///
/// The currency travels on every item for a reason: a price without it is a
/// number somebody has to remember the currency of. So the symbol is not
/// hardcoded — stamping `$` on a KHR amount would render a figure roughly four
/// thousand times wrong, and it would look entirely plausible.
String formatMaterialPrice(MobilePrice price) {
  final amount = price.price;
  if (amount == null) return '';

  final currency = price.currency.trim().toUpperCase();
  final digits = NumberFormat('#,##0.00').format(amount);

  return switch (currency) {
    'USD' => '\$$digits',
    '' => digits,
    _ => '$digits $currency',
  };
}
