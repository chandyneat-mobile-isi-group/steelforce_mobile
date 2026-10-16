import 'package:flutter/material.dart';

/// A theme-aware shimmer used to build skeleton loading states.
///
/// Wrap one or more [ShimmerBox]es (or any opaque shapes) in a [Shimmer] to
/// sweep a highlight across them. Because the skeleton occupies the same
/// footprint as the real content, there is no layout jump when data arrives.
///
/// **This is the only shimmer in the app.** A second, identically-named
/// `Shimmer` used to live in `core/utils/shimmer.dart` and was deleted because
/// it rendered a solid block instead of a sweep: it combined
/// `BlendMode.srcATop` with a ~90%-opaque `surface` highlight and *clamped*
/// gradient stops (`(t ± 0.3).clamp(0, 1)`), which collapse at both ends of the
/// loop. The result repainted the entire wrapped subtree a flat near-white —
/// the "huge white container replaced a section" bug on the Route Dashboard.
///
/// The safety margin here is deliberate and worth preserving if this is ever
/// edited: the stops are **fixed and narrow** (`0.35/0.5/0.65`, never clamped),
/// and both colours are low-alpha `onSurface` tints (0.08–0.16), so even when
/// this wraps real content it tints rather than obliterates it.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1200),
    this.enabled = true,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = widget.baseColor ?? scheme.onSurface.withValues(alpha: 0.08);
    final highlight =
        widget.highlightColor ?? scheme.onSurface.withValues(alpha: 0.16);

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!widget.enabled || reduceMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = (_controller.value * 2 - 1) * bounds.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(slide),
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0, 0);
  }
}

/// A single rounded skeleton block. Compose several to mirror real content.
///
/// [radius] is a convenience for the common `BorderRadius.circular(n)` case and
/// is mutually exclusive with [borderRadius]. Both exist because this widget
/// absorbed the call sites of the former `core/utils/shimmer.dart` `SkeletonBox`
/// (deleted — see the class docs on [Shimmer]), which took a plain `double`.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.radius,
    this.color,
  }) : assert(borderRadius == null || radius == null,
            'Provide either borderRadius or radius, not both');

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  /// Shorthand for a uniform circular radius.
  final double? radius;

  /// Overrides the default block tint. Rarely needed — the default already
  /// adapts to light/dark via `onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? scheme.onSurface.withValues(alpha: 0.10),
        borderRadius: borderRadius ?? BorderRadius.circular(radius ?? 8),
      ),
    );
  }
}
