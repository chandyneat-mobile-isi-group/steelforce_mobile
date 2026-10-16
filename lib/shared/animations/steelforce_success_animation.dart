import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SteelForce's success mark — the confirmation shown when an important action
/// lands: a visit completed, a quotation saved, a depot added.
///
/// ## Two modes, one widget
///
/// * **Scene** ([showScene] `true`, the default) — the full celebration from
///   the brand artwork: a lit podium, the skyline and twin towers behind it,
///   the steel the business actually sells stacked either side, the flag, and
///   the glowing check badge as the hero. Sized for a full-screen or
///   dialog-sized moment, roughly 220pt and up.
/// * **Mark** ([showScene] `false`) — badge, ring, check and a small stack of
///   bar ends. This is the previous behaviour of this widget, unchanged, and
///   it is what belongs in a toast or a list row at 60–120pt. The scene's
///   detail turns to mud below about 200pt, so passing `false` there is not a
///   downgrade — it is the correct drawing for the size.
///
/// ## What it draws, and what it deliberately does not
///
/// Everything in the reference render is here except the mascot. A robot
/// approximated in vector shapes reads as a worse drawing rather than a
/// simpler one — it is the one element in that artwork whose appeal is in the
/// rendering, not the silhouette. So it is a *slot* instead: pass the actual
/// cut-out through [mascot] and it is composited into the scene and animated
/// with everything else.
///
/// ```dart
/// SteelForceSuccessAnimation(
///   size: 320,
///   aspect: 4 / 3,
///   mascot: Image.asset('assets/brand/sf_mascot.png'),
/// )
/// ```
///
/// ## Plays once, then breathes
///
/// A celebration that loops stops being one — the third repeat of a burst is
/// noise on a screen the user is trying to read. The sequence runs a single
/// time; afterwards a slow idle keeps the glow, the orbital arcs and the flag
/// alive without asking for attention again. Set [loop] only for a demo
/// surface.
///
/// ## Presentation only
///
/// No business logic, no BLoC dependency. Trigger it from a success state:
///
/// ```dart
/// final _success = GlobalKey<SteelForceSuccessAnimationState>();
/// ...
/// BlocListener<OrderBloc, OrderState>(
///   listener: (context, state) {
///     if (state is OrderSubmitted) _success.currentState?.play();
///   },
///   child: SteelForceSuccessAnimation(key: _success, autoPlay: false),
/// )
/// ```
class SteelForceSuccessAnimation extends StatefulWidget {
  const SteelForceSuccessAnimation({
    super.key,
    this.size = 140,
    this.aspect = 1.0,
    this.autoPlay = true,
    this.duration = const Duration(milliseconds: 2400),
    this.onCompleted,
    this.loop = false,
    this.primaryColor,
    this.checkColor = Colors.white,
    this.showParticles = true,
    this.showGlow = true,
    this.particleCount = 18,
    this.showScene = true,
    this.showFlag = true,
    this.showSkyline = true,
    this.showPodium = true,
    this.flagTitle = 'STEELFORCE',
    this.flagTagline = 'STRONGER TOGETHER',
    this.mascot,
    this.semanticLabel,
  });

  /// The drawing's **width**. Height is derived through [aspect].
  final double size;

  /// Width ÷ height. `1.0` is square; the brand artwork is `4 / 3`. The scene
  /// is laid out in fractions of the box, so both compose correctly — a wider
  /// box simply gives the skyline and the flag more room either side of the
  /// badge.
  final double aspect;

  /// Start on first frame. False when a BLoC state will call [play].
  final bool autoPlay;
  final Duration duration;

  /// Fired once the sequence settles. Not called for each pass when [loop].
  final VoidCallback? onCompleted;
  final bool loop;

  /// Defaults to the app's `colorScheme.primary`, so the mark belongs to
  /// whatever theme hosts it rather than hardcoding a blue that fights it.
  final Color? primaryColor;
  final Color checkColor;
  final bool showParticles;
  final bool showGlow;

  /// Restrained on purpose. Past roughly twenty-four this reads as a party
  /// popper rather than a job done, and every extra piece costs frame budget
  /// on the low-end Androids a field team actually carries.
  final int particleCount;

  /// Draw the full celebration rather than the badge alone. See the class doc.
  final bool showScene;

  /// Individual scene layers, so a host can quiet the composition without
  /// dropping to the bare mark — e.g. a dialog that already carries the
  /// wordmark in its header can set [showFlag] to false.
  final bool showFlag;
  final bool showSkyline;
  final bool showPodium;

  final String flagTitle;
  final String flagTagline;

  /// Optional mascot artwork, composited over the scene and animated in with
  /// it. Give it a transparent background; it is laid into the gap the scene
  /// leaves at centre-right, between the badge and the flagpole.
  final Widget? mascot;

  final String? semanticLabel;

  @override
  State<SteelForceSuccessAnimation> createState() =>
      SteelForceSuccessAnimationState();
}

class SteelForceSuccessAnimationState extends State<SteelForceSuccessAnimation>
    with TickerProviderStateMixin {
  /// The one-shot arrival: backdrop, podium, steel, flag, badge, burst.
  late final AnimationController _sequence;

  /// The idle afterwards — glow, orbital drift, flag in the wind. Kept
  /// separate so it can run forever without the arrival restarting with it.
  late final AnimationController _breathe;

  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _sequence = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onStatus);
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Scheduled rather than started inline so the first painted frame is frame
    // zero of the arrival, not a frame of the finished state.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _breathe.repeat(reverse: true);
      if (widget.autoPlay) play();
    });
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (widget.loop) {
      _sequence.forward(from: 0);
      return;
    }
    // Once only: a rebuild must not re-fire the caller's completion handler.
    if (_notified) return;
    _notified = true;
    widget.onCompleted?.call();
  }

  /// Restarts the sequence from the beginning.
  void play() {
    _notified = false;
    _sequence.forward(from: 0);
  }

  /// Returns to the empty state without animating.
  void reset() {
    _notified = false;
    _sequence.value = 0;
  }

  @override
  void dispose() {
    _sequence
      ..removeStatusListener(_onStatus)
      ..dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final accent = widget.primaryColor ?? Theme.of(context).colorScheme.primary;

    // Guard the divide: an aspect of 0 from a caller's arithmetic would
    // otherwise produce an infinite height and a layout assertion.
    final aspect = widget.aspect > 0 ? widget.aspect : 1.0;

    return Semantics(
      label: widget.semanticLabel,
      // Decorative unless labelled: a screen reader should hear the heading
      // that follows this, not "image" ahead of it.
      excludeSemantics: widget.semanticLabel == null,
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size / aspect,
          child: AnimatedBuilder(
            animation: Listenable.merge([_sequence, _breathe]),
            builder: (context, _) {
              // Reduced motion gets the settled scene: everything built and
              // the check drawn, no burst and no shockwave. The picture
              // carries the meaning; only the movement is optional.
              final t = reduceMotion ? _settledFrame : _sequence.value;
              final breath = reduceMotion ? 0.5 : _breathe.value;

              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _SuccessPainter(
                      t: t,
                      breath: breath,
                      accent: accent,
                      checkColor: widget.checkColor,
                      showGlow: widget.showGlow,
                      showScene: widget.showScene,
                      showFlag: widget.showScene && widget.showFlag,
                      showSkyline: widget.showScene && widget.showSkyline,
                      showPodium: widget.showScene && widget.showPodium,
                      flagTitle: widget.flagTitle,
                      flagTagline: widget.flagTagline,
                      particleCount: (reduceMotion || !widget.showParticles)
                          ? 0
                          : widget.particleCount,
                    ),
                  ),
                  if (widget.mascot != null && widget.showScene)
                    _MascotSlot(t: t, child: widget.mascot!),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Past every arrival beat and after the particles have cleared.
  static const double _settledFrame = 0.88;
}

/// Lands the mascot in the scene's reserved gap.
///
/// It arrives *after* the podium and steel and *before* the check completes,
/// so the eye reads: stage built → figure steps up → result confirmed. Scaling
/// from 0.86 rather than 0 keeps a photographic cut-out from passing through a
/// thumbnail-sized frame on its way in, which looks like a glitch.
class _MascotSlot extends StatelessWidget {
  const _MascotSlot({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rise = _phase(t, 0.22, 0.52, Curves.easeOutBack);
    if (rise <= 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Align(
        // Centre-right: clear of the badge at lower-left and inboard of the
        // flagpole. Slightly above centre because the podium eats the bottom.
        alignment: const Alignment(0.30, -0.06),
        child: FractionallySizedBox(
          widthFactor: 0.40,
          heightFactor: 0.62,
          child: Opacity(
            opacity: _u(rise),
            child: Transform.translate(
              offset: Offset(0, (1 - rise) * 10),
              child: Transform.scale(
                scale: 0.86 + 0.14 * rise,
                child: FittedBox(fit: BoxFit.contain, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Palette for the secondary industrial elements ───────────────────────────
//
// Only the neutrals are constants. Every blue in the scene is derived from the
// caller's accent, so the celebration re-tints wholesale with the theme rather
// than drifting away from it one hardcoded hex at a time.
const _steel = Color(0xFF94A3B8);
const _steelDark = Color(0xFF64748B);
const _steelDeep = Color(0xFF475569);
const _tubeBore = Color(0xFF334155);

double _u(double v) => v.isNaN ? 0.0 : v.clamp(0.0, 1.0);

double _phase(double t, double a, double b, [Curve c = Curves.easeOutCubic]) =>
    b <= a ? 0 : c.transform(_u((t - a) / (b - a)));

/// Text is laid out once per string+size+colour and reused.
///
/// `paint` runs sixty times a second; a `TextPainter.layout` per frame for the
/// wordmark is measurable work to produce a pixel-identical result every time.
final Map<String, TextPainter> _textCache = {};

TextPainter _label(
    String text, double size, Color color, double spacing, FontWeight weight) {
  final key = '$text|$size|${color.toARGB32()}|$spacing|${weight.value}';
  return _textCache.putIfAbsent(key, () {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  });
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter({
    required this.t,
    required this.breath,
    required this.accent,
    required this.checkColor,
    required this.showGlow,
    required this.showScene,
    required this.showFlag,
    required this.showSkyline,
    required this.showPodium,
    required this.flagTitle,
    required this.flagTagline,
    required this.particleCount,
  });

  final double t;
  final double breath;
  final Color accent;
  final Color checkColor;
  final bool showGlow;
  final bool showScene;
  final bool showFlag;
  final bool showSkyline;
  final bool showPodium;
  final String flagTitle;
  final String flagTagline;
  final int particleCount;

  // ── Timeline ──────────────────────────────────────────────────────────────
  //
  // One table, read top to bottom as the order the eye receives things:
  // the world builds, the figure's stage lights, then the result lands. Every
  // phase below is a window into the same 0–1 `t`, so re-timing the whole
  // celebration is editing numbers here, not renegotiating six methods.
  static const _backdropIn = [0.00, 0.24];
  static const _skylineIn = [0.04, 0.34];
  static const _towersIn = [0.08, 0.40];
  static const _podiumIn = [0.06, 0.30];
  static const _steelIn = [0.14, 0.44];
  static const _flagIn = [0.18, 0.48];
  static const _badgeIn = [0.30, 0.62];
  static const _ringIn = [0.40, 0.78];
  static const _arcsIn = [0.44, 0.80];
  static const _checkIn = [0.52, 0.82];
  static const _impact = [0.78, 0.94];
  static const _shockwave = [0.80, 1.00];
  static const _burst = [0.76, 1.00];

  // Deep end of the accent — the flag body, the tower faces in shadow.
  Color get _accentDeep => Color.lerp(accent, const Color(0xFF0B2A5B), 0.45)!;

  // Light end — the badge's inner lift and the map wash behind the skyline.
  Color get _accentLift => Color.lerp(accent, Colors.white, 0.42)!;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final s = size.width / 100.0;

    if (!showScene) {
      // The compact mark, unchanged: badge on a small stack of bar ends.
      final c = Offset(size.width * 0.5, size.height * 0.46);
      _paintBarEnds(canvas, s, size);
      _paintRipple(canvas, s, c, 21 * s);
      _paintArcs(canvas, s, c, 21 * s);
      _paintBadge(canvas, s, c, 21 * s);
      _paintShockwave(canvas, s, c, 21 * s);
      _paintParticles(canvas, s, size, c, 21 * s);
      return;
    }

    // The badge sits left of centre and low, where the artwork puts it: the
    // flag occupies the upper right, and a hero centred between the two would
    // read as a diagram rather than a photograph of a moment.
    final badge = Offset(size.width * 0.40, size.height * 0.62);
    final badgeR = math.min(size.width, size.height) * 0.155;
    final ground = size.height * 0.845;

    _paintBackdrop(canvas, size);
    if (showSkyline) {
      _paintSkyline(canvas, s, size);
      _paintTowers(canvas, s, size);
    }
    if (showFlag) _paintFlag(canvas, s, size);
    if (showPodium) _paintPodium(canvas, s, size, ground);
    _paintTubeBundle(canvas, s, size, ground);
    _paintPlates(canvas, s, size, ground);
    _paintRipple(canvas, s, badge, badgeR);
    _paintArcs(canvas, s, badge, badgeR);
    _paintBadge(canvas, s, badge, badgeR);
    _paintShockwave(canvas, s, badge, badgeR);
    // Confetti last so the burst passes *in front of* the badge. Painted
    // underneath, its first third is hidden behind the very thing it is
    // celebrating, and the pieces only appear once already clear of it — which
    // reads as debris drifting in rather than as a burst.
    _paintParticles(canvas, s, size, badge, badgeR);
  }

  /// Scale bump at impact: 1.0 → 1.08 → 1.0.
  double get _impactScale {
    final k = _phase(t, _impact[0], _impact[1], Curves.linear);
    return k <= 0 || k >= 1 ? 1.0 : 1 + 0.08 * math.sin(k * math.pi);
  }

  // ── Backdrop ──────────────────────────────────────────────────────────────

  /// The soft field of light the whole scene stands in.
  ///
  /// In the artwork this is a territory silhouette. Drawn as a real map it
  /// would be a claim about coverage that no data here supports — and a
  /// recognisable border is a political object, not a decoration. A wash of
  /// the same shape family carries the glow without asserting anything.
  void _paintBackdrop(Canvas canvas, Size size) {
    final rise = _phase(t, _backdropIn[0], _backdropIn[1]);
    if (rise <= 0) return;

    final centre = Offset(size.width * 0.5, size.height * 0.46);
    final rect = Rect.fromCenter(
      center: centre,
      width: size.width * 0.94,
      height: size.height * 0.84,
    );

    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _accentLift.withValues(alpha: 0.26 * rise),
            accent.withValues(alpha: 0.10 * rise),
            accent.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(rect),
    );
  }

  // ── City ──────────────────────────────────────────────────────────────────

  /// Blocks rising in a stagger, back to front.
  ///
  /// Heights come from a fixed table rather than a `Random`: the skyline must
  /// be pixel-identical on every play, or a golden test of any screen hosting
  /// this widget is unstable.
  void _paintSkyline(Canvas canvas, double s, Size size) {
    const heights = [
      0.30,
      0.46,
      0.22,
      0.54,
      0.34,
      0.62,
      0.26,
      0.42,
      0.58,
      0.30,
      0.48,
      0.24,
      0.38,
      0.28,
    ];
    final base = size.height * 0.815;
    final slot = size.width / heights.length;

    for (var i = 0; i < heights.length; i++) {
      // Staggered from the outside in, so the city assembles toward the hero.
      final offset = (i - heights.length / 2).abs() / heights.length;
      final start = _skylineIn[0] + offset * 0.10;
      final grow = _phase(t, start, start + 0.16, Curves.easeOutCubic);
      if (grow <= 0) continue;

      final h = size.height * 0.34 * heights[i] * grow;
      final w = slot * 0.74;
      final rect = Rect.fromLTWH(i * slot + (slot - w) / 2, base - h, w, h);

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(1.6 * s),
          topRight: Radius.circular(1.6 * s),
        ),
        Paint()..color = accent.withValues(alpha: 0.13 * grow),
      );
    }
  }

  /// The two spired towers — the one piece of the skyline with a silhouette
  /// worth reading, so they get faces, a seam and a spire while the blocks
  /// behind stay flat.
  void _paintTowers(Canvas canvas, double s, Size size) {
    final base = size.height * 0.815;

    for (var i = 0; i < 2; i++) {
      final grow = _phase(t, _towersIn[0] + i * 0.05, _towersIn[1] + i * 0.05,
          Curves.easeOutCubic);
      if (grow <= 0) continue;

      final cx = size.width * (i == 0 ? 0.215 : 0.305);
      final w = size.width * 0.052;
      final h = size.height * (i == 0 ? 0.50 : 0.44) * grow;
      final top = base - h;

      // Slight taper: the body narrows toward the crown.
      final body = Path()
        ..moveTo(cx - w / 2, base)
        ..lineTo(cx - w * 0.36, top)
        ..lineTo(cx + w * 0.36, top)
        ..lineTo(cx + w / 2, base)
        ..close();

      canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _steel.withValues(alpha: 0.92 * grow),
              _steelDeep.withValues(alpha: 0.92 * grow),
            ],
          ).createShader(Rect.fromLTWH(cx - w, top, w * 2, h)),
      );

      // Lit edge down the left face — what makes it metal rather than a bar.
      canvas.drawLine(
        Offset(cx - w * 0.20, top + 2 * s),
        Offset(cx - w * 0.26, base - 2 * s),
        Paint()
          ..strokeWidth = 1.1 * s
          ..color = Colors.white.withValues(alpha: 0.35 * grow),
      );

      final spire = _phase(t, _towersIn[1] - 0.06, _towersIn[1] + 0.08);
      if (spire <= 0) continue;
      canvas.drawLine(
        Offset(cx, top),
        Offset(cx, top - size.height * 0.075 * spire),
        Paint()
          ..strokeWidth = 1.6 * s
          ..strokeCap = StrokeCap.round
          ..color = _steelDark.withValues(alpha: 0.9 * spire),
      );
    }
  }

  // ── Flag ──────────────────────────────────────────────────────────────────

  /// Pole, then fabric wiping out from it, then the wordmark.
  ///
  /// The fabric keeps a slow wave forever off the idle controller. A flag that
  /// freezes solid is the tell that a celebration has ended and left a
  /// screenshot behind.
  void _paintFlag(Canvas canvas, double s, Size size) {
    final raise = _phase(t, _flagIn[0], _flagIn[0] + 0.18, Curves.easeOutCubic);
    if (raise <= 0) return;

    final px = size.width * 0.665;
    final topY = size.height * 0.045;
    final baseY = size.height * 0.80;

    canvas.drawLine(
      Offset(px, baseY),
      Offset(px, baseY - (baseY - topY) * raise),
      Paint()
        ..strokeWidth = 2.4 * s
        ..strokeCap = StrokeCap.round
        ..color = _steelDeep,
    );

    // Finial, so the pole ends deliberately instead of just stopping.
    if (raise >= 0.98) {
      canvas.drawCircle(Offset(px, topY), 2.2 * s, Paint()..color = _steelDark);
    }

    final unfurl =
        _phase(t, _flagIn[0] + 0.10, _flagIn[1], Curves.easeOutCubic);
    if (unfurl <= 0) return;

    final w = size.width * 0.30;
    final h = size.height * 0.20;
    final top = topY + 3 * s;
    // Amplitude scales with the flag, so the wave reads the same at any size.
    final wave = math.sin(breath * math.pi * 2) * h * 0.09;

    final fabric = Path()
      ..moveTo(px, top)
      ..cubicTo(px + w * 0.34, top - wave, px + w * 0.68, top + wave * 1.5,
          px + w, top + wave * 0.5)
      ..lineTo(px + w, top + h + wave * 0.5)
      ..cubicTo(px + w * 0.68, top + h + wave * 1.5, px + w * 0.34,
          top + h - wave, px, top + h)
      ..close();

    canvas.save();
    // Unfurls away from the pole rather than fading up as a whole sheet.
    canvas.clipRect(Rect.fromLTWH(px, top - h, w * unfurl, h * 3));

    canvas.drawPath(
      fabric,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, _accentDeep],
        ).createShader(Rect.fromLTWH(px, top, w, h)),
    );

    _paintFlagMark(canvas, s, px, top, w, h);
    canvas.restore();
  }

  /// The wordmark: three tower bars, the name, the tagline beneath a rule.
  void _paintFlagMark(
      Canvas canvas, double s, double px, double top, double w, double h) {
    final inset = w * 0.09;
    final markW = w * 0.16;
    final markBase = top + h * 0.62;

    // Three bars echoing the towers behind — the logo mark, at flag scale.
    const bars = [0.52, 0.78, 0.62];
    for (var i = 0; i < 3; i++) {
      final bw = markW / 4.4;
      final bh = h * 0.42 * bars[i];
      canvas.drawRect(
        Rect.fromLTWH(px + inset + i * (bw * 1.45), markBase - bh, bw, bh),
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
    }

    final textLeft = px + inset + markW + w * 0.05;
    final available = w - (textLeft - px) - inset * 0.6;
    if (available <= 0) return;

    final title =
        _label(flagTitle, h * 0.26, Colors.white, h * 0.012, FontWeight.w900);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(textLeft, top, available, h));
    // Scale down rather than clip when a longer name is passed in.
    final fit = math.min(1.0, available / math.max(title.width, 0.01));
    canvas.translate(textLeft, markBase - h * 0.34);
    canvas.scale(fit);
    title.paint(canvas, Offset.zero);
    canvas.restore();

    final ruleY = markBase + h * 0.05;
    canvas.drawLine(
      Offset(textLeft, ruleY),
      Offset(textLeft + available * 0.9, ruleY),
      Paint()
        ..strokeWidth = 0.8 * s
        ..color = Colors.white.withValues(alpha: 0.55),
    );

    if (flagTagline.isEmpty) return;
    final tag = _label(flagTagline, h * 0.105,
        Colors.white.withValues(alpha: 0.85), h * 0.02, FontWeight.w600);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(textLeft, ruleY, available, h * 0.3));
    canvas.translate(textLeft, ruleY + h * 0.04);
    canvas.scale(math.min(1.0, available / math.max(tag.width, 0.01)));
    tag.paint(canvas, Offset.zero);
    canvas.restore();
  }

  // ── Stage ─────────────────────────────────────────────────────────────────

  /// The lit dais everything stands on.
  ///
  /// Drawn as top ellipse + rim + shadow rather than a rectangle: the ellipse
  /// is what gives the scene a floor, and without a floor the steel and the
  /// badge read as stickers at different depths.
  void _paintPodium(Canvas canvas, double s, Size size, double ground) {
    final settle = _phase(t, _podiumIn[0], _podiumIn[1], Curves.easeOutBack);
    if (settle <= 0) return;

    final rx = size.width * 0.44 * settle;
    final ry = size.height * 0.048 * settle;
    final depth = size.height * 0.052;
    final top = Rect.fromCenter(
        center: Offset(size.width * 0.5, ground),
        width: rx * 2,
        height: ry * 2);

    // Contact shadow first, so the dais sits *on* something.
    canvas.drawOval(
      top.translate(0, depth * 0.9).inflate(2 * s),
      Paint()
        ..color = _steelDeep.withValues(alpha: 0.16 * settle)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * s),
    );

    // Side wall between the two ellipses.
    final wall = Path()
      ..moveTo(top.left, ground)
      ..lineTo(top.left, ground + depth)
      ..arcTo(top.translate(0, depth), math.pi, -math.pi, false)
      ..lineTo(top.right, ground)
      ..arcTo(top, 0, -math.pi, false)
      ..close();
    canvas.drawPath(
      wall,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [_accentDeep, accent, _accentDeep],
        ).createShader(Rect.fromLTWH(top.left, ground, top.width, depth)),
    );

    canvas.drawOval(top, Paint()..color = _accentLift);
    canvas.drawOval(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s
        ..color = Colors.white.withValues(alpha: 0.75),
    );

    // Rim light, breathing with the badge glow.
    if (!showGlow) return;
    canvas.drawOval(
      top.inflate(1.5 * s),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 * s
        ..color = accent.withValues(alpha: (0.22 + 0.14 * breath) * settle)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * s),
    );
  }

  // ── The product ───────────────────────────────────────────────────────────

  /// The bundle of hollow section — bar *ends*, seen down the bore. This is
  /// the thing the company sells, so it gets the detail: a lit outer ring, a
  /// dark bore, and a highlight on the upper left of each tube.
  void _paintTubeBundle(Canvas canvas, double s, Size size, double ground) {
    final rise = _phase(t, _steelIn[0], _steelIn[1]);
    if (rise <= 0) return;

    final r = size.width * 0.026;
    final cx = size.width * 0.135;
    final baseY = ground - size.height * 0.015;

    canvas.save();
    canvas.translate(0, (1 - rise) * size.height * 0.06);

    // Rows of 3 then 2, stacked as they would actually nest on a truck bed.
    for (var row = 0; row < 2; row++) {
      final count = row == 0 ? 3 : 2;
      final y = baseY - r - row * (r * 1.78);
      final startX = cx - (count - 1) * r * 1.05;
      for (var i = 0; i < count; i++) {
        final c = Offset(startX + i * r * 2.1, y);
        canvas.drawCircle(
            c, r, Paint()..color = _steel.withValues(alpha: 0.95 * rise));
        canvas.drawCircle(c, r * 0.62,
            Paint()..color = _tubeBore.withValues(alpha: 0.95 * rise));
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r * 0.82),
          math.pi * 1.05,
          math.pi * 0.7,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 * s
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.55 * rise),
        );
      }
    }
    canvas.restore();
  }

  /// Flat sheet, stacked to the right of the badge — the second product line,
  /// drawn in perspective so it agrees with the dais rather than floating.
  void _paintPlates(Canvas canvas, double s, Size size, double ground) {
    final rise = _phase(t, _steelIn[0] + 0.06, _steelIn[1] + 0.06);
    if (rise <= 0) return;

    final left = size.width * 0.60;
    final w = size.width * 0.20;
    final skew = size.height * 0.026;
    final thick = size.height * 0.016;

    canvas.save();
    canvas.translate(0, (1 - rise) * size.height * 0.06);

    for (var i = 0; i < 3; i++) {
      final y = ground - size.height * 0.012 - i * thick * 1.25;
      final face = Path()
        ..moveTo(left, y)
        ..lineTo(left + w, y - skew)
        ..lineTo(left + w, y - skew + thick)
        ..lineTo(left, y + thick)
        ..close();
      canvas.drawPath(
        face,
        Paint()
          ..color =
              (i.isEven ? _steel : _steelDark).withValues(alpha: 0.95 * rise),
      );
      // Top edge catches the light — the difference between a stack of sheets
      // and a stack of grey bars.
      canvas.drawLine(
        Offset(left, y),
        Offset(left + w, y - skew),
        Paint()
          ..strokeWidth = 0.9 * s
          ..color = Colors.white.withValues(alpha: 0.5 * rise),
      );
    }
    canvas.restore();
  }

  /// The compact mark's small stack of bar ends. Unchanged from the original
  /// widget, and used only when [showScene] is false.
  void _paintBarEnds(Canvas canvas, double s, Size size) {
    final rise = _phase(t, 0.10, 0.40);
    if (rise <= 0) return;

    canvas.save();
    canvas.translate(0, (1 - rise) * 14 * s);
    final baseY = size.height * 0.90;
    final cx = size.width * 0.5;

    for (var row = 0; row < 2; row++) {
      final count = row == 0 ? 4 : 3;
      final w = 11.0 * s, h = 7.0 * s;
      final y = baseY - row * (h + 1.4 * s);
      final startX = cx - (count * w + (count - 1) * 1.6 * s) / 2;
      for (var i = 0; i < count; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(startX + i * (w + 1.6 * s), y - h, w, h),
            Radius.circular(1.8 * s),
          ),
          Paint()
            ..color =
                (row == 0 ? _steelDark : _steel).withValues(alpha: 0.55 * rise),
        );
      }
    }
    canvas.restore();
  }

  // ── The hero ──────────────────────────────────────────────────────────────

  /// Soft radial ripple on arrival — the energy expanding outward.
  void _paintRipple(Canvas canvas, double s, Offset c, double r0) {
    final r = _phase(t, _badgeIn[0] - 0.06, _badgeIn[1]);
    if (r <= 0 || r >= 1) return;
    canvas.drawCircle(
      c,
      r0 * (0.85 + 1.5 * r),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * s
        ..color = accent.withValues(alpha: 0.30 * (1 - r)),
    );
  }

  /// The energy swooshes: two orbital arcs that sweep in and then drift
  /// forever, kept thin so they never compete with the check.
  void _paintArcs(Canvas canvas, double s, Offset c, double r0) {
    final show = _phase(t, _arcsIn[0], _arcsIn[1]);
    if (show <= 0) return;
    final spin = breath * math.pi * 0.5;

    for (var i = 0; i < 3; i++) {
      final radius = r0 * (1.55 + i * 0.26);
      final start = spin + i * math.pi * 0.72;
      final sweep = math.pi * (0.62 - i * 0.12) * show;
      final rect = Rect.fromCircle(center: c, radius: radius);

      // The sweep gradient is what makes an arc read as a *swoosh*: it has a
      // leading edge and a tail, so the eye infers a direction of travel.
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.2 - i * 0.5) * s
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: start,
            endAngle: start + math.max(sweep, 0.01),
            colors: [
              accent.withValues(alpha: 0.0),
              accent.withValues(alpha: 0.55 * show),
              _accentLift.withValues(alpha: 0.85 * show),
            ],
            transform: GradientRotation(start),
          ).createShader(rect),
      );
    }
  }

  void _paintBadge(Canvas canvas, double s, Offset c, double r0) {
    // 0.5 → 1.1 → 1.0, via easeOutBack's own overshoot.
    final pop = _phase(t, _badgeIn[0], _badgeIn[1], Curves.easeOutBack);
    if (pop <= 0) return;
    final r = r0 * (0.5 + 0.5 * pop) * _impactScale;

    if (showGlow) {
      // Brightens at impact, then settles into a slow breath.
      final impact = _phase(t, _impact[0], _impact[0] + 0.10, Curves.linear);
      final glow = 0.20 + 0.10 * breath + 0.24 * math.sin(impact * math.pi);
      canvas.drawCircle(
        c,
        r * 1.6,
        Paint()
          ..color = accent.withValues(alpha: (glow * pop).clamp(0.0, 1.0))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.55),
      );
    }

    // Disc: lit from upper-left, matching the towers and the tube highlights.
    // A flat fill here would be the one element in the scene without a light
    // source, and it is the element the eye lands on first.
    final disc = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.05,
          colors: [_accentLift, accent, _accentDeep],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(disc),
    );

    // Inner hairline, then the outer ring drawing itself round.
    canvas.drawCircle(
      c,
      r * 0.93,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * s
        ..color = Colors.white.withValues(alpha: 0.28),
    );

    final ring = _phase(t, _ringIn[0], _ringIn[1]);
    if (ring > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r + r0 * 0.30),
        -math.pi / 2,
        math.pi * 2 * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r0 * 0.12
          ..strokeCap = StrokeCap.round
          ..color = accent.withValues(alpha: 0.55),
      );
    }

    _paintCheck(canvas, s, c, r);
  }

  /// Drawn with `PathMetric`, not faded in — the stroke travelling left to
  /// right is what makes it read as confirmation rather than a stamp.
  void _paintCheck(Canvas canvas, double s, Offset c, double r) {
    final tick = _phase(t, _checkIn[0], _checkIn[1]);
    if (tick <= 0) return;

    final path = Path()
      ..moveTo(c.dx - r * 0.44, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.10, c.dy + r * 0.34)
      ..lineTo(c.dx + r * 0.46, c.dy - r * 0.30);

    final segs = path.computeMetrics().toList();
    final total = segs.fold<double>(0, (a, b) => a + b.length);
    final drawn = Path();
    var left = tick * total;
    for (final seg in segs) {
      if (left <= 0) break;
      drawn.addPath(
          seg.extractPath(0, math.min(left, seg.length)), Offset.zero);
      left -= seg.length;
    }

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.20
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = checkColor;

    // A faint dark pass under the tick keeps it legible on the lit side of the
    // disc, where white on `_accentLift` is close to failing contrast.
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _accentDeep.withValues(alpha: 0.22),
    );
    canvas.drawPath(drawn, stroke);
  }

  /// A single expanding ring at the moment the check completes.
  void _paintShockwave(Canvas canvas, double s, Offset c, double r0) {
    final w = _phase(t, _shockwave[0], _shockwave[1]);
    if (w <= 0 || w >= 1) return;
    canvas.drawCircle(
      c,
      r0 * (1.15 + 1.9 * w),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r0 * 0.14 * (1 - w)
        ..color = accent.withValues(alpha: 0.45 * (1 - w)),
    );
  }

  /// Deterministic burst: angles and speeds come from the index, not a
  /// `Random`, so the animation is identical on every run and a golden of a
  /// screen containing it is stable.
  void _paintParticles(
      Canvas canvas, double s, Size size, Offset c, double r0) {
    if (particleCount == 0) return;
    final launch = _phase(t, _burst[0], _burst[1], Curves.linear);
    if (launch <= 0) return;

    // Ribbons, not dots: the reference confetti is flat stock catching the
    // light, which is also what the product is.
    final palette = [
      accent,
      _accentLift,
      Colors.white,
      _steel,
    ];

    for (var i = 0; i < particleCount; i++) {
      // Nudged per index so the spread does not read as a clock face.
      final angle = (i / particleCount) * math.pi * 2 + (i % 3) * 0.22;
      final speed = r0 * (2.5 + (i % 5) * 0.52);

      // Launched from the badge rim: a particle starting inside the badge has
      // to travel through it before it exists.
      final out = r0 * 1.05 + Curves.easeOutCubic.transform(launch) * speed;
      // Eased travel against squared gravity — that mismatch is what makes it
      // read as thrown rather than scaled.
      final drop = launch * launch * r0 * 2.7;

      final p = Offset(
        c.dx + math.cos(angle) * out,
        c.dy + math.sin(angle) * out * 0.75 + drop,
      );
      if (p.dy > size.height + 8 * s) continue;

      // Gone well before the end, so the settled screen is the scene alone.
      final fade = 1 - _phase(t, _burst[0] + 0.10, 0.98, Curves.easeIn);
      if (fade <= 0) continue;

      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(angle + launch * 5.5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: r0 * 0.17, height: r0 * 0.26),
          Radius.circular(0.8 * s),
        ),
        Paint()..color = palette[i % palette.length].withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SuccessPainter old) =>
      old.t != t ||
      old.breath != breath ||
      old.accent != accent ||
      old.checkColor != checkColor ||
      old.particleCount != particleCount ||
      old.showGlow != showGlow ||
      old.showScene != showScene ||
      old.showFlag != showFlag ||
      old.showSkyline != showSkyline ||
      old.showPodium != showPodium ||
      old.flagTitle != flagTitle ||
      old.flagTagline != flagTagline;
}
