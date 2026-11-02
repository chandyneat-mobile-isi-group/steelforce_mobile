import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:steelforce/core/theme/app_colors.dart';

/// Softened Apex Blue with a faint steel chevron — the backdrop of the launch,
/// sign-in and password-reset screens, so the flow in and out of the app reads
/// as one surface.
///
/// Fills its parent: use it as `Positioned.fill` under a screen's content, or
/// pass [child] to layer content on top. The pattern is painted once into its
/// own layer ([RepaintBoundary]), so an animation above it never repaints it.
///
/// It asks for status-bar icons that read on [color]: light on the navy
/// default (launch), dark on a white pattern (sign-in, password reset).
class BrandPatternBackground extends StatelessWidget {
  const BrandPatternBackground({
    super.key,
    this.color = AppColors.brandPattern,
    this.lineColor = const Color(0x0AFFFFFF), // white, 4%
    this.child,
  });

  final Color color;

  /// The chevron and seam lines. Keep it faint: the pattern is texture, and
  /// text has to read over it everywhere.
  final Color lineColor;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final pattern = RepaintBoundary(
      child: CustomPaint(
        painter: _ChevronPainter(color: color, lineColor: lineColor),
        child: const SizedBox.expand(),
      ),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: color.computeLuminance() > 0.5
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: child == null
          ? pattern
          : Stack(
              fit: StackFit.expand,
              children: [pattern, child!],
            ),
    );
  }
}

/// The brand chevron — rows of V-shaped lines with a vertical seam every
/// four arms, like the joins between steel sheets — drawn in [lineColor]
/// over whatever is already on [canvas]. Shared by this backdrop and the
/// app wallpaper (`BrandWallpaperBackground`), so both carry one pattern.
void paintBrandChevrons(Canvas canvas, Size size, Color lineColor) {
  const arm = _ChevronPainter._arm;
  const row = _ChevronPainter._row;
  const rise = _ChevronPainter._rise;

  final line = Paint()
    ..color = lineColor
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  // Even vertices are the bottoms of the V. Shift the rows so one lands on
  // the centre line, where the seam runs through it (approved artwork).
  final centre = size.width / 2;
  final start = centre - (centre / (2 * arm)).ceil() * 2 * arm;
  final arms = ((size.width - start) / arm).ceil() + 1;

  // Points rather than a Path: one polyline per row, nothing for the web
  // engine to build lazily (see `drawDashedRRect`).
  for (var y = -rise; y < size.height + rise; y += row) {
    final points = [
      for (var i = 0; i <= arms; i++)
        Offset(start + i * arm, i.isEven ? y + rise : y),
    ];
    canvas.drawPoints(ui.PointMode.polygon, points, line);
  }

  // Same weight as the chevrons: in the artwork the seam reads as part of
  // the pattern, not as a divider.
  const seamGap = arm * _ChevronPainter._armsPerSeam;
  final first = centre - (centre / seamGap).floor() * seamGap;
  for (var x = first; x <= size.width; x += seamGap) {
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color, required this.lineColor});

  final Color color;
  final Color lineColor;

  /// Horizontal run of one chevron arm, in logical pixels.
  static const double _arm = 64;

  /// Vertical gap between rows.
  static const double _row = 30;

  /// How far an arm climbs over its run.
  static const double _rise = 22;

  /// A vertical seam every this many arms, like the joins between steel
  /// sheets. One sits at the centre, so a phone shows exactly one.
  static const int _armsPerSeam = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    paintBrandChevrons(canvas, size, lineColor);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.lineColor != lineColor;
}
