import 'package:flutter/material.dart';

import 'app_animations.dart';

/// A premium, interactive card surface.
///
/// Combines, in one reusable widget:
///  * a real Material ripple (clipped to the corner radius — not a fake
///    overlay),
///  * a press scale-down (1.0 -> [pressedScale]),
///  * an animated elevation/shadow that lifts on hover and settles on press,
///  * desktop/web hover (scale + pointer cursor, provided by [InkWell]).
///
/// Provide either [child] (static) or [builder], which receives the current
/// `pressed` / `hovered` state so inner content (e.g. an icon) can react —
/// used by the My Work cards to bounce their icon on press.
class AnimatedCard extends StatefulWidget {
  const AnimatedCard({
    super.key,
    this.child,
    this.builder,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.color,
    this.border,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.restShadow,
    this.hoverShadow,
    this.pressedShadow,
    this.pressedScale = AppScale.pressedCard,
    this.hoverScale = AppScale.hover,
    this.splashColor,
    this.highlightColor,
    this.enableHoverScale = true,
    this.semanticLabel,
    this.clipContent = true,
  })  : assert(child != null || builder != null,
            'Provide either child or builder'),
        assert(child == null || builder == null,
            'Provide only one of child or builder');

  final Widget? child;

  /// Alternative to [child]; receives live `pressed` / `hovered` flags.
  final Widget Function(BuildContext context, bool pressed, bool hovered)?
      builder;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final BoxBorder? border;
  final BorderRadius borderRadius;

  final List<BoxShadow>? restShadow;
  final List<BoxShadow>? hoverShadow;
  final List<BoxShadow>? pressedShadow;

  final double pressedScale;
  final double hoverScale;
  final Color? splashColor;
  final Color? highlightColor;
  final bool enableHoverScale;
  final String? semanticLabel;
  final bool clipContent;

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> {
  bool _pressed = false;
  bool _hovered = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  List<BoxShadow> _defaultShadow(ThemeData theme, double intensity) {
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? 0.22 : 0.05;
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: base * intensity),
        blurRadius: 10 * intensity,
        offset: Offset(0, 4 * intensity),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final rest = widget.restShadow ?? _defaultShadow(theme, 1.0);
    final hover = widget.hoverShadow ?? _defaultShadow(theme, 1.6);
    final pressed = widget.pressedShadow ?? _defaultShadow(theme, 0.5);
    final currentShadow = _pressed ? pressed : (_hovered ? hover : rest);

    final scale = reduceMotion
        ? 1.0
        : _pressed
            ? widget.pressedScale
            : (_hovered && widget.enableHoverScale ? widget.hoverScale : 1.0);

    final content =
        widget.builder?.call(context, _pressed, _hovered) ?? widget.child!;

    // Border + shadow live on the outer container; the Material inside paints
    // the surface and clips the ripple to the same radius.
    Widget card = AnimatedContainer(
      duration: AppDurations.fast,
      curve: AppCurves.standard,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: widget.border,
        boxShadow: currentShadow,
      ),
      child: Material(
        color: widget.color ?? scheme.surface,
        borderRadius: widget.borderRadius,
        clipBehavior: widget.clipContent ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: widget.borderRadius,
          splashColor:
              widget.splashColor ?? scheme.primary.withValues(alpha: 0.10),
          highlightColor:
              widget.highlightColor ?? scheme.primary.withValues(alpha: 0.04),
          onHighlightChanged: _setPressed,
          onHover: _setHovered,
          child: Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: content,
          ),
        ),
      ),
    );

    card = AnimatedScale(
      scale: scale,
      duration: _pressed ? AppDurations.pressDown : AppDurations.pressUp,
      curve: _pressed ? AppCurves.pressDown : AppCurves.pressUp,
      child: card,
    );

    if (widget.semanticLabel != null) {
      card = Semantics(
        button: true,
        label: widget.semanticLabel,
        child: card,
      );
    }
    return card;
  }
}
