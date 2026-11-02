import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// Steel-framed tactile card shell with Corner Watermarks — the shared frame of
/// every "Continue Working" card state (skeleton, single draft, many drafts).
/// Restyle the card border, shadow, and watermarks here.
class ContinueWorkingCardShell extends StatelessWidget {
  const ContinueWorkingCardShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: context.rr(12),
            offset: Offset(0, context.rh(6)),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(context.rr(17)),
        child: Stack(
          children: [
            // Top-Left Corner Decorative Circle Watermark
            Positioned(
              top: -context.rr(22),
              left: -context.rr(22),
              child: _CornerWatermark(color: scheme.primary),
            ),
            // Bottom-Right Corner Decorative Circle Watermark
            Positioned(
              bottom: -context.rr(22),
              right: -context.rr(22),
              child: _CornerWatermark(color: scheme.primary),
            ),
            // Card Content
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

/// Dual-Bordered Icon Avatar Badge — the round history icon that leads the
/// single-draft and many-drafts cards. Restyle the badge here.
class ContinueWorkingIconBadge extends StatelessWidget {
  const ContinueWorkingIconBadge({
    super.key,
    required this.padding,
    required this.iconSize,
  });

  /// Unscaled padding around the icon (scaled with `context.rr`).
  final double padding;

  /// Unscaled icon size (scaled with `context.rsp`).
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(context.rr(padding)),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: AppColors.steelRim.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: context.rr(4),
            offset: Offset(0, context.rh(2)),
          ),
        ],
      ),
      child: Icon(
        Icons.history_rounded,
        size: context.rsp(iconSize),
        color: scheme.primary,
      ),
    );
  }
}

/// Decorative outlined circle peeking in from a card corner.
class _CornerWatermark extends StatelessWidget {
  const _CornerWatermark({required this.color});
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
