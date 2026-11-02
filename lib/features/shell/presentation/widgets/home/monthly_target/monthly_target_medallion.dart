/// The round, blue-rimmed calendar badge at the left of the Monthly Target
/// card header. Restyle the medallion here.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/shared/animations/calendar_month_icon.dart';

/// Embossed Calendar Medallion
class MonthlyTargetMedallion extends StatelessWidget {
  const MonthlyTargetMedallion({super.key});

  // Style constants (design units).
  static const double _size = 36;
  static const double _iconSize = 20;
  static const double _rimWidth = 1.2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: context.rr(_size),
      height: context.rr(_size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary.withValues(alpha: 0.22),
            scheme.primary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: _rimWidth,
        ),
      ),
      child: Center(
        // Drawn, not a glyph: the medallion now
        // shows a month filling in and a day
        // being marked, which is what the card
        // is about. See CalendarMonthIcon.
        child: CalendarMonthIcon(
          size: context.rr(_iconSize),
          accent: scheme.primary,
          ink: scheme.onSurface.withValues(alpha: 0.70),
          muted: scheme.onSurface.withValues(alpha: 0.30),
        ),
      ),
    );
  }
}
