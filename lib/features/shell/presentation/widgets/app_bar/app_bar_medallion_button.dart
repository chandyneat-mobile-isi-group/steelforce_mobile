/// The round, blue-rimmed "medallion" behind every icon action in the shell
/// app bar (back, notifications). Restyle the medallion here.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// 3D Tactile Medallion Container for App Bar Actions
class AppBarMedallionButton extends StatelessWidget {
  const AppBarMedallionButton({
    super.key,
    required this.child,
    this.onTap,
    this.isHome = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool isHome;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.rr(36),
        height: context.rr(36),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isHome
                ? [
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.08),
                  ]
                : [
                    scheme.surface,
                    Color.lerp(scheme.surface, scheme.onSurface, 0.05)!,
                  ],
          ),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: isHome ? 0.30 : 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isHome ? 0.3 : (isDark ? 0.35 : 0.08),
              ),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}
