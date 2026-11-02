import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// Steel-framed shell of the "Continue visit" card with info-tinted corner
/// watermarks. Restyle the visit card's border, shadow, and watermarks here.
class ContinueVisitCardFrame extends StatelessWidget {
  const ContinueVisitCardFrame({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(context.rr(18)),
        border: Border.all(
          color: AppColors.steelRim,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: context.rr(12),
            offset: Offset(0, context.rh(4)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.rr(17)),
        child: Stack(
          children: [
            // Top-Left Watermark Circle
            Positioned(
              top: -context.rr(22),
              left: -context.rr(22),
              child: _Watermark(color: colors.info),
            ),
            // Bottom-Right Watermark Circle
            Positioned(
              bottom: -context.rr(22),
              right: -context.rr(22),
              child: _Watermark(color: colors.info),
            ),
            Padding(
              padding: EdgeInsets.all(context.rr(14)),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _Watermark extends StatelessWidget {
  const _Watermark({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.rr(55),
      height: context.rr(55),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
    );
  }
}
