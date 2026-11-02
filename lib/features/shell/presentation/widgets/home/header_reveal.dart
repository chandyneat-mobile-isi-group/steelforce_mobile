import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';

/// Grows [child] in along [axis] while fading it in, and shrinks it away the
/// same way when it becomes null — so the header never jumps.
class HeaderReveal extends StatelessWidget {
  const HeaderReveal({
    super.key,
    required this.duration,
    required this.axis,
    required this.child,
  });

  final Duration duration;
  final Axis axis;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: AppCurves.emphasized,
      switchOutCurve: AppCurves.standard,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        axis: axis,
        // Grows from the pill's side: down for the popup, out for the badge.
        alignment:
            axis == Axis.vertical ? Alignment.topCenter : Alignment.centerLeft,
        child: FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.85, end: 1.0).animate(animation),
            child: child,
          ),
        ),
      ),
      child: child ?? const SizedBox.shrink(key: ValueKey('none')),
    );
  }
}
