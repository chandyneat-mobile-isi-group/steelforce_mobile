/// The Monthly Target card's shell: press-depth shadows, steel gradient frame,
/// tinted inner surface and corner ornaments. Restyle the card body here.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/traditional_corner_ornament.dart';

class MonthlyTargetFrame extends StatelessWidget {
  const MonthlyTargetFrame({
    super.key,
    required this.isPressed,
    required this.child,
  });

  // Style constants (design units).
  static const double _radius = 20;
  static const double _innerRadius = 18;
  static const double _frameWidth = 2;
  static const double _padding = 18;
  static const double _ornamentSize = 40;
  static const double _ornamentInset = 16;

  /// Flattens the shadow while the finger is down.
  final bool isPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final depthOffset = isPressed ? 2.0 : 6.0;
    final outerRadius = BorderRadius.circular(context.rr(_radius));
    final innerRadius = BorderRadius.circular(context.rr(_innerRadius));

    return Container(
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: isDark ? 0.30 : 0.18),
            offset: Offset(0, depthOffset),
            blurRadius: isPressed ? 2 : 6,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
            offset: Offset(0, depthOffset + 2),
            blurRadius: isPressed ? 4 : 12,
          ),
        ],
      ),
      child: Container(
        // Outer steel frame gradient
        decoration: BoxDecoration(
          borderRadius: outerRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.steelLight,
              AppColors.steelRim,
              AppColors.steelLight,
            ],
          ),
        ),
        padding: EdgeInsets.all(context.rr(_frameWidth)),
        child: Container(
          padding: EdgeInsets.all(context.rw(_padding)),
          decoration: BoxDecoration(
            borderRadius: innerRadius,
            color: scheme.surface,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.surface,
                Color.lerp(scheme.surface, scheme.primary, 0.04)!,
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: innerRadius,
            child: Stack(
              children: [
                // Corner Decorative Accents
                ...TraditionalCornerOrnament.corners(
                  context,
                  color: scheme.primary,
                  size: _ornamentSize,
                  inset: _ornamentInset,
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
