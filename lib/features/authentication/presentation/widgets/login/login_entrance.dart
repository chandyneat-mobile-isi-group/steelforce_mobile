import 'package:flutter/material.dart';

/// One beat of the sign-in screen's entrance: fades its child in while
/// sliding it up a few pixels, over the [begin]–[end] slice of a shared
/// controller.
///
/// One controller for the whole screen keeps the stagger in step and costs a
/// single ticker. Nothing waits on it — every control is in the tree and
/// tappable from the first frame, the entrance only paints over that.
class LoginEntrance extends StatelessWidget {
  LoginEntrance({
    super.key,
    required Animation<double> parent,
    required double begin,
    required double end,
    required this.child,
    this.offset = 18,
  }) : _t = CurvedAnimation(
          parent: parent,
          curve: Interval(begin, end, curve: Curves.easeOutCubic),
        );

  final Animation<double> _t;
  final Widget child;

  /// Vertical travel in logical pixels.
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: child,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - _t.value)),
          child: child,
        ),
      ),
    );
  }
}
