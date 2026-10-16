import 'package:flutter/material.dart';

import 'app_animations.dart';

/// Scales its child down slightly while pressed, then snaps back on release.
///
/// Use this for tappable elements that are NOT Material surfaces (icon
/// buttons, avatars, custom chips). For card surfaces prefer [AnimatedCard],
/// which also provides a proper Material ripple.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = AppScale.pressedAction,
    this.enabled = true,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enabled;
  final HitTestBehavior behavior;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (!widget.enabled) return;
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final scale = (_pressed && !reduceMotion) ? widget.pressedScale : 1.0;

    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: scale,
        duration: _pressed ? AppDurations.pressDown : AppDurations.pressUp,
        curve: _pressed ? AppCurves.pressDown : AppCurves.pressUp,
        child: widget.child,
      ),
    );
  }
}
