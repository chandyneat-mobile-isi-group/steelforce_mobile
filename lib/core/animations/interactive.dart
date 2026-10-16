import 'package:flutter/material.dart';

/// Shared tap/hover motion for the whole app: press scales a tap target
/// down (works on touch and mouse alike), hover scales it up slightly on
/// desktop/web (a no-op on touch-only devices, which never report hover).
/// Same physical metaphor everywhere — down = pressed, up = lifted — so
/// interactions feel consistent whether the surface underneath is a card,
/// a chip, or a grid tile, and stay tasteful for a traditional CRM
/// audience while giving the snappier feel newer users expect.
///
/// [builder] receives the live hover/press flags so callers can react in
/// their own decoration (e.g. deepen a shadow on hover) — this widget only
/// owns the scale animation and the gesture/mouse plumbing, never the
/// child's colors or shadows.
class InteractiveScale extends StatefulWidget {
  const InteractiveScale({
    super.key,
    required this.onTap,
    required this.builder,
    this.pressScale = 0.96,
    this.hoverScale = 1.03,
  });

  final VoidCallback onTap;
  final Widget Function(BuildContext context, bool isHovered, bool isPressed)
      builder;
  final double pressScale;
  final double hoverScale;

  @override
  State<InteractiveScale> createState() => _InteractiveScaleState();
}

class _InteractiveScaleState extends State<InteractiveScale> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scale =
        _pressed ? widget.pressScale : (_hovered ? widget.hoverScale : 1.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: Duration(milliseconds: _pressed ? 100 : 160),
          curve: Curves.easeOut,
          child: widget.builder(context, _hovered, _pressed),
        ),
      ),
    );
  }
}

/// Hover-only lift, for surfaces that already own their own internal tap
/// targets (e.g. a product card with +/- stepper buttons) — wrapping those
/// in [InteractiveScale]'s tap-capturing `GestureDetector` would compete
/// with the child buttons' own gestures, so this only listens for mouse
/// enter/exit (desktop/web) and never intercepts taps.
class HoverLift extends StatefulWidget {
  const HoverLift({super.key, required this.builder, this.liftScale = 1.015});

  final Widget Function(BuildContext context, bool isHovered) builder;
  final double liftScale;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.liftScale : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: widget.builder(context, _hovered),
      ),
    );
  }
}
