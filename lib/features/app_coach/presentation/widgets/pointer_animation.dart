import 'package:flutter/material.dart';

/// A small pulsing tap-pointer that draws the eye to the spotlighted target.
///
/// Respects reduced-motion: when [animate] is false it renders a static dot, so
/// it stays accessible and costs nothing on low-end devices.
class PointerAnimation extends StatefulWidget {
  const PointerAnimation({super.key, required this.color, this.animate = true});

  final Color color;
  final bool animate;

  @override
  State<PointerAnimation> createState() => _PointerAnimationState();
}

class _PointerAnimationState extends State<PointerAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  static const double _dotSize = 22.0;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return _Dot(color: widget.color, size: _dotSize);
    }
    return SizedBox(
      width: _dotSize * 2.6,
      height: _dotSize * 2.6,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Stack(
          alignment: Alignment.center,
          children: [
            // Two staggered ripples read as a continuous pulse rather than a
            // single mechanical loop.
            _ripple(_c.value),
            _ripple((_c.value + 0.5) % 1.0),
            child!,
          ],
        ),
        child: _Dot(color: widget.color, size: _dotSize * 0.62),
      ),
    );
  }

  Widget _ripple(double t) {
    final eased = Curves.easeOutCubic.transform(t);
    return Opacity(
      opacity: (1 - eased) * 0.45,
      child: Transform.scale(
        scale: 0.5 + eased * 1.6,
        child: _RingDot(color: widget.color, size: _dotSize),
      ),
    );
  }
}

/// The solid tap indicator: a soft gradient fill with a light contact shadow
/// so it reads as a raised, tappable point rather than a flat sticker.
class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color.lerp(color, Colors.white, 0.35) ?? color,
              color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      );
}

/// Lightweight flat circle used for the expanding ripple echoes — no shadow,
/// since several are drawn per frame.
class _RingDot extends StatelessWidget {
  const _RingDot({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
