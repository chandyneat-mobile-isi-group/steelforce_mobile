import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:steelforce/features/app_coach/domain/entities/coach_step.dart';
import 'package:steelforce/features/app_coach/presentation/services/coach_anchor_registry.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/assistant_bubble.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/highlight_painter.dart';
import 'package:steelforce/features/app_coach/presentation/widgets/pointer_animation.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Full-screen coaching layer: a dimming, gently blurred scrim with a
/// spotlight cutout around the current target, a glow ring + tap-pointer, and
/// the assistant bubble anchored beside it. Taps fall through the cutout to
/// the real widget so the user completes the step for real; everything else
/// is absorbed.
///
/// Robust by design: when the target key isn't laid out (deleted screen, not
/// scrolled into view, orientation change mid-frame) it degrades to a centered,
/// target-less bubble instead of crashing or pointing at nothing.
class AssistantOverlay extends StatefulWidget {
  const AssistantOverlay({
    super.key,
    required this.step,
    required this.stepNumber,
    required this.totalSteps,
    required this.progress,
    required this.reduceMotion,
    required this.onCta,
    required this.onSkip,
    required this.onClose,
  });

  final CoachStep step;
  final int stepNumber;
  final int totalSteps;
  final double progress;
  final bool reduceMotion;
  final VoidCallback onCta;
  final VoidCallback onSkip;
  final VoidCallback onClose;

  @override
  State<AssistantOverlay> createState() => _AssistantOverlayState();
}

class _AssistantOverlayState extends State<AssistantOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  Rect? _rect;

  /// Captured from the [CoachAnchorScope] above the shell, so `_syncRect` can
  /// read anchor bounds from post-frame callbacks (where an inherited-widget
  /// lookup isn't valid).
  CoachAnchorRegistry? _registry;

  static const double _pad = 8; // spotlight breathing room
  static const double _gap = 12; // space between target and bubble
  static const double _holeRadius = 20; // shared with the backdrop clip

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _glow.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = CoachAnchorScope.maybeOf(context);
    // First rect read happens here (not initState) because it needs the scope.
    _syncRect();
  }

  @override
  void didUpdateWidget(AssistantOverlay old) {
    super.didUpdateWidget(old);
    if (old.step.id != widget.step.id) _syncRect();
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  /// Re-reads the target's bounds and, while layout is still settling (target
  /// scrolling into view), re-checks next frame. Self-terminating: once the rect
  /// stops changing, no further rebuilds are scheduled.
  void _syncRect() {
    final id = widget.step.targetKeyId;
    final next = id == null ? null : _registry?.rectFor(id);
    if (next != _rect && mounted) {
      setState(() => _rect = next);
    }
    if (id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final latest = _registry?.rectFor(id);
        if (latest != _rect) setState(() => _rect = latest);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final scrim = Colors.black.withValues(alpha: 0.62);

    // Clamp the cutout to the visible area so a partially-scrolled target never
    // paints the hole off-screen.
    Rect? hole;
    if (_rect != null) {
      final inflated = _rect!.inflate(_pad);
      final screen = Offset.zero & media.size;
      if (inflated.overlaps(screen)) hole = inflated.intersect(screen);
    }

    return Stack(
      children: [
        // 1. Soft backdrop blur — glass depth cue behind the scrim. Clipped to
        // exclude the cutout so the real, focused target stays perfectly sharp.
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipper: _ScrimClipper(hole, _holeRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),

        // 2. Scrim + glow — never intercepts touches.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => CustomPaint(
                painter: HighlightPainter(
                  hole: hole,
                  radius: _holeRadius,
                  scrimColor: scrim,
                  glowColor: scheme.primary,
                  glow: widget.reduceMotion ? 0 : _glow.value,
                ),
              ),
            ),
          ),
        ),

        // 3. Touch handling: absorb everywhere except the cutout.
        ..._buildAbsorbers(hole),

        // 4. Tap-pointer over the target.
        if (hole != null)
          Positioned(
            left: hole.center.dx - context.rr(22),
            top: hole.bottom - context.rh(6),
            child: IgnorePointer(
              child: PointerAnimation(
                color: scheme.primary,
                animate: !widget.reduceMotion,
              ),
            ),
          ),

        // 5. Assistant bubble.
        _buildBubble(context, hole, media),
      ],
    );
  }

  /// Full-screen absorber for target-less steps; otherwise four panels framing
  /// the hole, leaving it interactive.
  List<Widget> _buildAbsorbers(Rect? hole) {
    if (hole == null) {
      return [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // swallow background taps for informational steps
          ),
        ),
      ];
    }
    Widget panel(
            {double? left,
            double? top,
            double? right,
            double? bottom,
            double? width,
            double? height}) =>
        Positioned(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          width: width,
          height: height,
          child: const _Absorber(),
        );
    return [
      panel(left: 0, top: 0, right: 0, height: hole.top),
      panel(left: 0, top: hole.bottom, right: 0, bottom: 0),
      panel(left: 0, top: hole.top, width: hole.left, height: hole.height),
      panel(right: 0, top: hole.top, left: hole.right, height: hole.height),
    ];
  }

  Widget _buildBubble(BuildContext context, Rect? hole, MediaQueryData media) {
    final bubble = AssistantBubble(
      key: ValueKey(widget.step.id),
      step: widget.step,
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      progress: widget.progress,
      onCta: widget.onCta,
      onSkip: widget.onSkip,
      onClose: widget.onClose,
    );

    // Cross-fade + gentle pop between steps, instead of the content just
    // snapping to new text mid-tour.
    final content = AnimatedSwitcher(
      duration: widget.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: bubble,
    );

    final hMargin = context.rw(16);
    final safeTop = media.padding.top + context.rh(8);
    final safeBottom = media.padding.bottom + context.rh(8);
    final moveDuration =
        widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 260);

    if (hole == null) {
      // Centered card, respecting safe areas and keyboard.
      return AnimatedPositioned(
        duration: moveDuration,
        curve: Curves.easeOutCubic,
        left: hMargin,
        right: hMargin,
        top: safeTop,
        bottom: safeBottom + media.viewInsets.bottom,
        child: Center(child: content),
      );
    }

    // Prefer below the target; flip above when the lower half is too tight.
    final spaceBelow = media.size.height - hole.bottom - safeBottom;
    final placeBelow = spaceBelow > media.size.height * 0.32;

    return AnimatedPositioned(
      duration: moveDuration,
      curve: Curves.easeOutCubic,
      left: hMargin,
      right: hMargin,
      top: placeBelow ? hole.bottom + _gap : null,
      bottom: placeBelow ? null : media.size.height - hole.top + _gap,
      child: content,
    );
  }
}

/// Clips the backdrop-blur layer to everything except the spotlighted hole, so
/// the focused target itself is never blurred — only the world around it.
class _ScrimClipper extends CustomClipper<Path> {
  const _ScrimClipper(this.hole, this.radius);
  final Rect? hole;
  final double radius;

  @override
  Path getClip(Size size) {
    final path = Path()..fillType = PathFillType.evenOdd;
    path.addRect(Offset.zero & size);
    if (hole != null) {
      path.addRRect(RRect.fromRectAndRadius(hole!, Radius.circular(radius)));
    }
    return path;
  }

  @override
  bool shouldReclip(_ScrimClipper old) =>
      old.hole != hole || old.radius != radius;
}

/// Eats taps over the dimmed area so background UI can't be triggered while a
/// step is active. The spotlight cutout is intentionally left uncovered.
class _Absorber extends StatelessWidget {
  const _Absorber();
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
      );
}
