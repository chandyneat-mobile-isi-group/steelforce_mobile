part of '../check_in_confirmation_dialog.dart';

class _LocatorBeacon extends StatefulWidget {
  const _LocatorBeacon({required this.phase, required this.accent});

  final CheckInGpsPhase phase;
  final Color accent;

  @override
  State<_LocatorBeacon> createState() => _LocatorBeaconState();
}

class _LocatorBeaconState extends State<_LocatorBeacon>
    with TickerProviderStateMixin {
  late final AnimationController _radar = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  bool get _searching => widget.phase == CheckInGpsPhase.searching;

  @override
  void initState() {
    super.initState();
    if (_searching) {
      _radar.repeat();
    } else {
      // Parked at the end: no rings, same as arriving here from a search.
      _radar.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant _LocatorBeacon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searching && !_radar.isAnimating) {
      _radar.repeat();
    } else if (!_searching && _radar.isAnimating) {
      // Let the current ring finish rather than snapping it away.
      _radar.animateTo(1, duration: const Duration(milliseconds: 400));
    }
    if (widget.phase != oldWidget.phase &&
        (widget.phase == CheckInGpsPhase.within ||
            widget.phase == CheckInGpsPhase.noOutlet)) {
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _radar.dispose();
    _burst.dispose();
    super.dispose();
  }

  IconData get _icon => switch (widget.phase) {
        CheckInGpsPhase.searching => Icons.gps_not_fixed_rounded,
        CheckInGpsPhase.within => Icons.where_to_vote_rounded,
        CheckInGpsPhase.noOutlet => Icons.add_location_alt_rounded,
        CheckInGpsPhase.weakSignal => Icons.gps_not_fixed_rounded,
        CheckInGpsPhase.outside => Icons.wrong_location_rounded,
        CheckInGpsPhase.servicesDisabled => Icons.location_disabled_rounded,
        CheckInGpsPhase.permissionDenied ||
        CheckInGpsPhase.permissionDeniedForever =>
          Icons.lock_outline_rounded,
        CheckInGpsPhase.unavailable => Icons.gps_off_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final size = context.rr(96);
    final core = context.rr(58);
    final accent = widget.accent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rings are painted, not rebuilt: `repaint:` drives the painter
          // straight off the controller, so the widget tree is untouched at
          // 60 fps.
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _BeaconPainter(
                  radar: _radar,
                  burst: _burst,
                  color: accent,
                  coreRadius: core / 2,
                ),
              ),
            ),
          ),
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: accent),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, color, child) {
              final c = color ?? accent;
              return Container(
                width: core,
                height: core,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.withValues(alpha: 0.22),
                      c.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(color: c.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: child,
              );
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.elasticOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.4, end: 1).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: _searching
                  // A slow turn of the crosshair while searching: motion that
                  // says "working" without the urgency of a spinner.
                  ? RotationTransition(
                      key: const ValueKey('searching'),
                      turns: _radar,
                      child: Icon(_icon, color: accent, size: context.rr(28)),
                    )
                  : Icon(
                      _icon,
                      key: ValueKey(_icon),
                      color: accent,
                      size: context.rr(28),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BeaconPainter extends CustomPainter {
  _BeaconPainter({
    required this.radar,
    required this.burst,
    required this.color,
    required this.coreRadius,
  }) : super(repaint: Listenable.merge([radar, burst]));

  final Animation<double> radar;
  final Animation<double> burst;
  final Color color;
  final double coreRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Three staggered rings, each easing outward and fading as it goes.
    if (radar.isAnimating || radar.value < 1) {
      for (var i = 0; i < 3; i++) {
        final t = (radar.value + i / 3) % 1.0;
        final eased = Curves.easeOut.transform(t);
        final r = coreRadius + (maxRadius - coreRadius) * eased;
        final alpha = (1 - t) * (radar.isAnimating ? 1 : 0.4);
        canvas.drawCircle(
            center, r, fill..color = color.withValues(alpha: 0.10 * alpha));
        canvas.drawCircle(
            center, r, stroke..color = color.withValues(alpha: 0.30 * alpha));
      }
    }

    // A single celebratory ring when the rep lands inside the area.
    if (burst.value > 0 && burst.value < 1) {
      final t = Curves.easeOutCubic.transform(burst.value);
      final r = coreRadius + (maxRadius - coreRadius) * t;
      canvas.drawCircle(
        center,
        r,
        stroke
          ..strokeWidth = 2.4 * (1 - t) + 0.6
          ..color = color.withValues(alpha: 0.55 * (1 - t)),
      );
    }
  }

  @override
  bool shouldRepaint(_BeaconPainter old) =>
      old.color != color || old.coreRadius != coreRadius;
}

// ═════════════════════════════════════════════════════════════════════════════
// Searching — progress, elapsed time, rotating tips
// ═════════════════════════════════════════════════════════════════════════════
