import 'package:flutter/material.dart';

import 'app_animations.dart';

/// Fades a child in while sliding it up a few logical pixels.
///
/// Plays exactly once when first mounted. Pass a [delay] to stagger a group
/// (see [FadeSlideIn.staggerDelay]). Honours the platform "reduce motion"
/// setting by rendering the child immediately when animations are disabled,
/// which also keeps widget tests deterministic.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppDurations.entrance,
    this.curve = AppCurves.standard,
    this.offset = 16,
    this.enabled = true,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  /// Vertical travel in logical pixels (positive = starts lower, slides up).
  final double offset;

  /// When false the child is shown immediately with no animation.
  final bool enabled;

  /// Convenience delay for the [index]-th item in a staggered group.
  static Duration staggerDelay(
    int index, {
    Duration interval = AppDurations.stagger,
    Duration base = Duration.zero,
  }) =>
      base + interval * index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.enabled || reduceMotion) {
      _controller.value = 1;
      return;
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - v)),
            child: child,
          ),
        );
      },
    );
  }
}
