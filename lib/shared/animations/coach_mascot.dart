import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

enum CoachMood { idle, cheer, talk }

/// Animated coach mascot — the SteelForce "Let's Go" sticker.
///
/// The animation carries two markers, read from the file rather than
/// hard-coded as frame numbers:
///
/// * `intro` — the pop-in, played once when the mascot appears;
/// * `loop`  — the idle motion, repeated after the intro.
///
/// The sticker has no separate cheer or talk segment, so the moods map onto
/// those two: [CoachMood.cheer] replays the intro (then calls [onCheerFinish]
/// and settles back into the loop); [CoachMood.idle] and [CoachMood.talk]
/// play the loop.
class CoachMascot extends StatefulWidget {
  const CoachMascot({
    super.key,
    this.mood = CoachMood.idle,
    this.size = 160,
    this.onCheerFinish,
    this.animate = true,
    this.loop = true,
    this.animationAsset = asset,
  });

  /// Under `assets/lotties/`, the folder `pubspec.yaml` declares.
  static const asset = 'assets/lotties/coach-letsgo.json';

  /// The same mascot acting out "photo submitted": it snaps a photo, the
  /// photo flies into its speech bubble, an upload bar fills and a green
  /// check lands. Same 480 × 600 frame and the same `intro` / `loop` markers,
  /// so it drops into [animationAsset] unchanged.
  static const inventorySuccessAsset = 'assets/lotties/inventory-success.json';

  /// Shown if [asset] fails to load, so the coach is never left without a
  /// face.
  static const fallbackAsset = 'assets/lotties/Live chatbot.json';

  /// The sticker's frame is 480 × 600 — taller than wide.
  static const aspectRatio = 480 / 600;

  /// False holds a still frame — for reduced motion.
  final bool animate;

  /// False plays the idle motion once after the intro, then holds — for a
  /// one-off moment such as a confirmation screen, where a figure that never
  /// stops moving competes with the text the rep has to read.
  final bool loop;

  /// Which sticker to play — [asset] or [inventorySuccessAsset]. Both share
  /// the frame size and markers this widget reads.
  final String animationAsset;

  final CoachMood mood;

  /// The mascot's height; the width follows [aspectRatio].
  final double size;
  final VoidCallback? onCheerFinish;

  @override
  State<CoachMascot> createState() => _CoachMascotState();
}

/// A marker's span as controller values (0–1 over the whole file).
typedef _Span = ({double start, double end, Duration length});

class _CoachMascotState extends State<CoachMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
  );
  late CoachMood _current = widget.mood;

  _Span? _intro;
  _Span? _loop;

  @override
  void didUpdateWidget(covariant CoachMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood ||
        oldWidget.animate != widget.animate ||
        oldWidget.loop != widget.loop) {
      _current = widget.mood;
      _start();
    }
  }

  void _onLoaded(LottieComposition composition) {
    final first = composition.startFrame;
    final total = composition.endFrame - first;
    final fps = composition.frameRate;

    _Span? span(String name) {
      final m = composition.getMarker(name);
      if (m == null || total <= 0) return null;
      return (
        // Clamped: a marker that runs to the last frame lands a hair past
        // 1.0 (the file's end frame is not inclusive), which the controller
        // rejects.
        start: ((m.startFrame - first) / total).clamp(0.0, 1.0),
        end:
            ((m.startFrame + m.durationFrames - first) / total).clamp(0.0, 1.0),
        length: Duration(
          milliseconds: (m.durationFrames / fps * 1000).round(),
        ),
      );
    }

    _intro = span('intro');
    // No `loop` marker: loop the whole file.
    _loop =
        span('loop') ?? (start: 0.0, end: 1.0, length: composition.duration);
    _start();
  }

  /// Intro once (when there is one), then the loop.
  void _start() {
    final loop = _loop;
    if (loop == null) return; // not loaded yet; [_onLoaded] calls this

    if (!widget.animate) {
      // Hold the end of the intro — the mascot fully in place.
      _controller
        ..stop()
        ..value = loop.start;
      return;
    }

    final intro = _intro;
    if (intro == null) {
      _repeatLoop();
      return;
    }

    _controller.value = intro.start;
    final mood = _current;
    _controller.animateTo(intro.end, duration: intro.length).whenComplete(() {
      if (!mounted || _current != mood) return;
      if (mood == CoachMood.cheer) widget.onCheerFinish?.call();
      _repeatLoop();
    });
  }

  void _repeatLoop() {
    final loop = _loop!;
    if (!widget.loop) {
      _controller
        ..value = loop.start
        ..animateTo(loop.end, duration: loop.length);
      return;
    }
    _controller.repeat(min: loop.start, max: loop.end, period: loop.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.size * CoachMascot.aspectRatio;
    return Lottie.asset(
      widget.animationAsset,
      controller: _controller,
      width: width,
      height: widget.size,
      fit: BoxFit.contain,
      frameRate: FrameRate.max, // smooth on 60/120Hz screens
      onLoaded: _onLoaded,
      errorBuilder: (_, __, ___) => Lottie.asset(
        CoachMascot.fallbackAsset,
        width: width,
        height: widget.size,
        fit: BoxFit.contain,
        animate: widget.animate,
      ),
    );
  }
}
