import 'package:flutter/material.dart';

/// Paints the dimming scrim with a rounded-rectangle "hole" punched out around
/// the spotlighted widget, plus a soft layered glow on its edge.
///
/// Purely visual — it never handles hit-testing (the overlay uses separate
/// absorbing panels so taps fall through the hole to the real widget).
class HighlightPainter extends CustomPainter {
  const HighlightPainter({
    required this.hole,
    required this.radius,
    required this.scrimColor,
    required this.glowColor,
    required this.glow,
  });

  /// Cutout bounds in overlay-local coordinates, or null for a full scrim.
  final Rect? hole;
  final double radius;
  final Color scrimColor;
  final Color glowColor;

  /// 0..1 pulse used for the ring width/opacity (0 when reduced-motion).
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrim = Paint()..color = scrimColor;

    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }

    final rrect = RRect.fromRectAndRadius(hole!, Radius.circular(radius));

    // Scrim everywhere except the hole (even-odd punches the rounded rect out).
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(full)
      ..addRRect(rrect);
    canvas.drawPath(path, scrim);

    if (glow <= 0) return;

    // Soft outer bloom — the "premium" depth cue that separates the cutout
    // from the flat scrim behind it.
    final bloom = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 + 6 * glow
      ..color = glowColor.withValues(alpha: 0.10 + 0.10 * glow)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + 4 * glow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        hole!.inflate(6 + 6 * glow),
        Radius.circular(radius + 6),
      ),
      bloom,
    );

    // Crisp mid ring — carries the pulsing color.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 + 1.5 * glow
      ..color = glowColor.withValues(alpha: 0.35 + 0.45 * glow);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        hole!.inflate(2 + 2 * glow),
        Radius.circular(radius + 2),
      ),
      ring,
    );

    // Hairline glass highlight hugging the cutout edge itself.
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.22 * glow);
    canvas.drawRRect(rrect, inner);
  }

  @override
  bool shouldRepaint(HighlightPainter old) =>
      old.hole != hole ||
      old.glow != glow ||
      old.scrimColor != scrimColor ||
      old.glowColor != glowColor ||
      old.radius != radius;
}
