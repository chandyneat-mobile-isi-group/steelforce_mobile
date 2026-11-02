/// Top row of the Monthly Target card: calendar medallion + "`<Month>` Target"
/// title on the left, "View KPI" link with a drifting arrow on the right.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/monthly_target/monthly_target_medallion.dart';

/// Header with Title & Animated View KPI Tag
class MonthlyTargetHeader extends StatelessWidget {
  const MonthlyTargetHeader({
    super.key,
    required this.monthName,
    required this.slideAnimation,
    required this.reduceMotion,
  });

  // Style constants (design units).
  static const double _medallionGap = 10;
  static const double _titleFontSize = 14;
  static const double _titleToKpiGap = 8;
  static const double _kpiIconSize = 14;
  static const double _kpiIconGap = 4;
  static const double _kpiFontSize = 11;
  static const double _arrowSize = 10;

  final String monthName;

  /// Drives the arrow's horizontal drift; owned by the card's state.
  final Animation<double> slideAnimation;

  /// FS-ANI-7 — when true the arrow stays put.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const MonthlyTargetMedallion(),
              SizedBox(width: context.rw(_medallionGap)),
              Flexible(
                child: Text(
                  'shell.monthly_target'.trParams({'month': monthName}),
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: context.rsp(_titleFontSize),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.rw(_titleToKpiGap)),
        Row(
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: context.rsp(_kpiIconSize),
              color: scheme.primary,
            ),
            SizedBox(width: context.rw(_kpiIconGap)),
            Text(
              'home.view_kpi'.tr,
              style: TextStyle(
                color: scheme.primary,
                fontSize: context.rsp(_kpiFontSize),
                fontWeight: FontWeight.w800,
              ),
            ),
            // The AnimatedBuilder belongs here, on the
            // only thing that reads the animation. It used
            // to wrap the percentage pill — whose builder
            // never touched the value — so the pill
            // repainted a gradient and shadow every frame
            // for nothing while this arrow, sampling
            // `.value` with no listener, never moved at
            // all.
            AnimatedBuilder(
              animation: slideAnimation,
              // The icon is identical every frame; only
              // its offset changes. Built once and passed
              // through, so the rebuild is a translation
              // and not an Icon reconstruction.
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: context.rsp(_arrowSize),
                color: scheme.primary,
              ),
              builder: (context, child) => Transform.translate(
                offset: Offset(reduceMotion ? 0 : slideAnimation.value, 0),
                child: child,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
