import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
///
/// A **non-blocking** step ([CoachStep.blocking] false — every lesson step)
/// draws no scrim, no blur and no absorbers: the rep is filling a real form,
/// so the whole screen stays live and the coach only rings the target and
/// explains.
///
/// Every step's target can appear late and move — on a first sign-in the
/// tour starts while the shell is still sliding in and Home is still filling;
/// a lesson's form scrolls; autoplay scrolls the target into view — so its
/// position is followed every frame while it moves, then checked a few times
/// a second until it moves again.
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
    this.lessonTitleKey,
    this.failureKey,
    this.onMinimize,
    this.autoplay,
    this.onToggleAutoplay,
  });

  final CoachStep step;

  /// Practice lessons: whether the coach is performing the steps itself.
  /// Null for the tour, which has no autoplay.
  final bool? autoplay;
  final VoidCallback? onToggleAutoplay;

  /// The lesson's name, shown above the step title. Null for the tour.
  final String? lessonTitleKey;

  /// Retry guidance after the step's operation failed.
  final String? failureKey;

  /// Collapses a non-blocking guide to a chip so it covers nothing.
  final VoidCallback? onMinimize;
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
    with TickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  Rect? _rect;
  final GlobalKey _bubbleKey = GlobalKey();
  Offset? _bubblePosition;
  Size _bubbleSize = Size.zero;

  /// Captured from the [CoachAnchorScope] above the shell, so `_syncRect` can
  /// read anchor bounds from post-frame callbacks (where an inherited-widget
  /// lookup isn't valid).
  CoachAnchorRegistry? _registry;

  static const double _pad = 8; // spotlight breathing room
  static const double _gap = 12; // space between target and bubble
  static const double _holeRadius = 20; // shared with the backdrop clip

  /// Follows the target every frame while it moves; stops once it has held
  /// still for [_settledFrames].
  late final Ticker _follow = createTicker((_) => _onFrame());
  int _stillFrames = 0;
  static const int _settledFrames = 20;

  /// While [_follow] is stopped, notices the target moving again.
  Timer? _watch;

  bool get _blocking => widget.step.blocking;

  void _startBubbleDrag(DragStartDetails _) {
    final renderObject = _bubbleKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    _bubbleSize = renderObject.size;
    setState(() => _bubblePosition = renderObject.localToGlobal(Offset.zero));
  }

  void _moveBubble(DragUpdateDetails details, MediaQueryData media) {
    final current = _bubblePosition;
    if (current == null) return;

    const edge = 4.0;
    final maxLeft = math.max(edge, media.size.width - _bubbleSize.width - edge);
    final minTop = media.padding.top + edge;
    final maxTop = math.max(
      minTop,
      media.size.height -
          media.padding.bottom -
          media.viewInsets.bottom -
          _bubbleSize.height -
          edge,
    );
    setState(() {
      _bubblePosition = Offset(
        (current.dx + details.delta.dx).clamp(edge, maxLeft).toDouble(),
        (current.dy + details.delta.dy).clamp(minTop, maxTop).toDouble(),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _glow.repeat(reverse: true);
    _startTracking();
  }

  void _startTracking() {
    _follow.stop();
    _watch?.cancel();
    if (widget.step.targetKeyId == null) return;
    _stillFrames = 0;
    _follow.start();
    _watch = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _follow.isActive || !_readRect()) return;
      _stillFrames = 0;
      _follow.start();
    });
  }

  void _onFrame() {
    if (!mounted) return;
    if (_readRect()) {
      _stillFrames = 0;
    } else if (++_stillFrames >= _settledFrames) {
      _follow.stop();
    }
  }

  /// Re-reads the target's bounds; true when they changed.
  bool _readRect() {
    final id = widget.step.targetKeyId;
    final latest = id == null ? null : _registry?.rectFor(id);
    if (latest == _rect) return false;
    setState(() => _rect = latest);
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registry = CoachAnchorScope.maybeOf(context);
    // First rect read happens here (not initState) because it needs the scope.
    _readRect();
  }

  @override
  void didUpdateWidget(AssistantOverlay old) {
    super.didUpdateWidget(old);
    if (old.step.id != widget.step.id) {
      _readRect();
      _startTracking();
    }
  }

  @override
  void dispose() {
    _watch?.cancel();
    _follow.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final scrim =
        _blocking ? Colors.black.withValues(alpha: 0.62) : Colors.transparent;

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
        if (_blocking)
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

        // 3. Touch handling: absorb everywhere except the cutout. A
        // non-blocking guide absorbs nothing.
        if (_blocking) ..._buildAbsorbers(hole),

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
      lessonTitleKey: widget.lessonTitleKey,
      failureKey: widget.failureKey,
      onMinimize: widget.onMinimize,
      autoplay: widget.autoplay,
      onToggleAutoplay: widget.onToggleAutoplay,
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
    final draggableContent = GestureDetector(
      key: _bubbleKey,
      onPanStart: _startBubbleDrag,
      onPanUpdate: (details) => _moveBubble(details, media),
      child: content,
    );

    final hMargin = context.rw(16);
    final safeTop = media.padding.top + context.rh(8);
    final safeBottom = media.padding.bottom + context.rh(8);
    final moveDuration =
        widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 260);

    final dragged = _bubblePosition;
    if (dragged != null) {
      return Positioned(
        left: dragged.dx,
        top: dragged.dy,
        width: media.size.width - hMargin * 2,
        child: draggableContent,
      );
    }

    if (hole == null && !_blocking) {
      // Docked at the bottom, clear of the keyboard: a centred card would sit
      // on the middle of the form the rep is filling in.
      return AnimatedPositioned(
        duration: moveDuration,
        curve: Curves.easeOutCubic,
        left: hMargin,
        right: hMargin,
        bottom: safeBottom + media.viewInsets.bottom,
        child: draggableContent,
      );
    }

    if (hole == null) {
      // Centered card, respecting safe areas and keyboard.
      return AnimatedPositioned(
        duration: moveDuration,
        curve: Curves.easeOutCubic,
        left: hMargin,
        right: hMargin,
        top: safeTop,
        bottom: safeBottom + media.viewInsets.bottom,
        child: Center(child: draggableContent),
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
      child: draggableContent,
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
