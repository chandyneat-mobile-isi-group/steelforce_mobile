/// Bottom row of the Monthly Target card: the steel-edged track with the green
/// fill showing achieved / target. Restyle the bar here.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Progress Track
class MonthlyTargetProgressBar extends StatelessWidget {
  const MonthlyTargetProgressBar({super.key, required this.progress});

  // Style constants (design units).
  static const double _height = 12;
  static const double _radius = 10;

  /// Fill fraction, already clamped to 0..1 by the card.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final appColors = context.appColors;
    final radius = BorderRadius.circular(context.rr(_radius));

    return Container(
      height: context.rh(_height),
      decoration: BoxDecoration(
        color: appColors.surfaceSoft,
        borderRadius: radius,
        border: Border.all(
          color: AppColors.steelRim,
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: context.rh(_height),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    appColors.success.withValues(alpha: 0.85),
                    appColors.success,
                    Color.lerp(appColors.success, AppColors.brandNavy, 0.3)!,
                  ],
                ),
                borderRadius: radius,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
