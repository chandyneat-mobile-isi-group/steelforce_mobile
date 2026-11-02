import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/sync/continue_working/continue_working_card_shell.dart';

/// Loading placeholder for the Home "Continue Working" card, shown until the
/// drafts have loaded. Mirrors the single-draft card's layout.
class ContinueWorkingCardSkeleton extends StatelessWidget {
  const ContinueWorkingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final skeletonColor = scheme.onSurface.withValues(alpha: 0.12);

    return ContinueWorkingCardShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonCircle(color: skeletonColor),
              SizedBox(width: context.rw(8)),
              Expanded(
                child: _SkeletonBar(
                  color: skeletonColor,
                  height: context.rh(14),
                  radius: context.rr(4),
                ),
              ),
              SizedBox(width: context.rw(32)),
              _SkeletonCircle(color: skeletonColor),
            ],
          ),
          SizedBox(height: context.rh(12)),
          _SkeletonBar(
            color: skeletonColor,
            width: context.rw(120),
            height: context.rh(12),
            radius: context.rr(4),
          ),
          SizedBox(height: context.rh(6)),
          _SkeletonBar(
            color: skeletonColor,
            width: context.rw(190),
            height: context.rh(12),
            radius: context.rr(4),
          ),
          SizedBox(height: context.rh(16)),
          Row(
            children: [
              Expanded(
                child: _SkeletonBar(
                  color: skeletonColor,
                  height: context.rh(40),
                  radius: context.rr(10),
                ),
              ),
              SizedBox(width: context.rw(10)),
              Expanded(
                child: _SkeletonBar(
                  color: skeletonColor,
                  height: context.rh(40),
                  radius: context.rr(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.rr(20),
      height: context.rr(20),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({
    required this.color,
    required this.height,
    required this.radius,
    this.width,
  });
  final Color color;
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
