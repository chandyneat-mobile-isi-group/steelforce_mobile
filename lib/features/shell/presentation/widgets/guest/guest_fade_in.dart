import 'package:flutter/material.dart';

/// Staggered fade-and-rise entrance for the guest sections.
///
/// Each section passes an increasing [delay] so they cascade in rather than all
/// appearing at once — the "smooth, premium" reveal the guest screen wants.
///
/// Uses a real [AnimationController] (not `TweenAnimationBuilder`) precisely
/// because it needs a *delay*: the controller is created at rest and started
/// after [delay], which `TweenAnimationBuilder` cannot express. The controller
/// is disposed with the widget, so there is no leak.
///
/// Respects `MediaQuery.disableAnimations` (Reduce Motion): the child appears
/// immediately at its resting position, so the entrance never blocks content
/// for users who have motion disabled.
class GuestFadeIn extends StatefulWidget {
  const GuestFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = 24,
  });

  final Widget child;

  /// How long to wait before this section starts animating in.
  final Duration delay;
  final Duration duration;

  /// Starting vertical offset in logical pixels; animates to 0.
  final double offset;

  @override
  State<GuestFadeIn> createState() => _GuestFadeInState();
}

class _GuestFadeInState extends State<GuestFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration);

  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Read Reduce Motion here (needs an inherited widget), and start exactly
    // once. `didChangeDependencies` can fire more than once, hence the guard.
    if (_started) return;
    _started = true;

    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1; // Straight to resting state, no motion.
      return;
    }
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) => Opacity(
        opacity: _curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _curve.value) * widget.offset),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
