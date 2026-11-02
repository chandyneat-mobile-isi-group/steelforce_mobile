/// Middle row of the Monthly Target card: "achieved$ / target$" figures and,
/// when the card is tappable, the green percentage pill.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:steelforce/core/localization/localized_text_context.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Values Display & Clickable Visual Hint
class MonthlyTargetAmounts extends StatelessWidget {
  const MonthlyTargetAmounts({
    super.key,
    required this.achievedAmount,
    required this.targetAmount,
    required this.percentage,
    required this.showPercentage,
  });

  // Style constants (design units).
  static const double _achievedFontSize = 24;
  static const double _targetFontSize = 14;
  static const double _amountGap = 6;
  static const double _pillGap = 8;
  static const double _pillPadH = 12;
  static const double _pillPadV = 4;
  static const double _pillRadius = 20;
  static const double _pillFontSize = 12;

  final double achievedAmount;
  final double targetAmount;
  final int percentage;

  /// The pill is only shown when the card has an `onTap`.
  final bool showPercentage;

  /// `100000` → `100,000$`: whole dollars, grouped in thousands, the sign
  /// after the amount. Truncated rather than rounded so the achieved figure
  /// never claims a dollar the rep has not reached yet.
  static String _dollars(BuildContext context, double amount) =>
      '${NumberFormat('#,##0', context.languageCode).format(amount.truncate())}\$';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Shrinks rather than overflows: a seven-digit
        // target with its thousands separators, or large
        // system text, is wider than the space beside the
        // percentage pill.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _dollars(context, achievedAmount),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: context.rsp(_achievedFontSize),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(width: context.rw(_amountGap)),
                Text(
                  '/ ${_dollars(context, targetAmount)}',
                  style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: 0.5),
                    fontSize: context.rsp(_targetFontSize),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: context.rw(_pillGap)),

        // Explicit "View KPI" interactive affordance pill
        if (showPercentage) _percentagePill(context),
      ],
    );
  }

  Widget _percentagePill(BuildContext context) {
    final appColors = context.appColors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.rw(_pillPadH),
        vertical: context.rh(_pillPadV),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            appColors.success,
            Color.lerp(appColors.success, AppColors.brandNavy, 0.25)!,
          ],
        ),
        borderRadius: BorderRadius.circular(context.rr(_pillRadius)),
        boxShadow: [
          BoxShadow(
            color: appColors.success.withValues(alpha: 0.35),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          color: Colors.white,
          fontSize: context.rsp(_pillFontSize),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
