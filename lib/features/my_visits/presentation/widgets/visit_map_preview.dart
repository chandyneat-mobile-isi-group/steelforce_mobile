import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Static placeholder "map" preview — same decorative-grid-plus-pin design as
/// `GpsLocationCard` (lead feature), reused here so the visit card/detail
/// screens feel consistent with the rest of the app. No maps package involved;
/// this is intentionally a UI stand-in over real coordinates.
class VisitMapPreview extends StatelessWidget {
  const VisitMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 120,
    this.borderRadius = 14,
    this.showCoordinates = true,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double borderRadius;
  final bool showCoordinates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withValues(alpha: 0.22),
              colors.info.withValues(alpha: 0.16)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size.infinite, painter: _GridPainter()),
            Icon(Icons.location_on_rounded,
                color: scheme.secondary, size: height > 100 ? 34 : 26),
            if (showCoordinates)
              Positioned(
                left: 10,
                right: 10,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.scrim.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white, fontSize: context.rsp(11.5)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    const step = 24.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
