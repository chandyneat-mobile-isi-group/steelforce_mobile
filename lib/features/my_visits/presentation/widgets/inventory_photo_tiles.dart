import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:steelforce/core/animations/app_animations.dart';
import 'package:steelforce/core/animations/press_scale.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';

/// One chosen photo: pops in when added, numbered "n/max", with a remove
/// badge.
class InventoryPhotoThumb extends StatelessWidget {
  const InventoryPhotoThumb({
    super.key,
    required this.bytes,
    required this.index,
    required this.maxPhotos,
    required this.size,
    required this.onRemove,
  });

  final Uint8List bytes;
  final int index;
  final int maxPhotos;
  final double size;

  /// Null while saving, which hides the remove badge.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final radius = BorderRadius.circular(context.rr(14));
    // Decoded at roughly display size: a full camera frame per thumbnail
    // would hold tens of megabytes for a strip of small squares.
    final cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).round();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduceMotion ? Duration.zero : AppDurations.entrance,
      curve: AppCurves.bounce,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
      ),
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Semantics(
              image: true,
              label: 'my_visits.survey.photo_number'
                  .trParams({'number': index + 1}),
              child: ClipRRect(
                borderRadius: radius,
                child: Image.memory(bytes,
                    fit: BoxFit.cover, cacheWidth: cacheWidth),
              ),
            ),
            Positioned(
              left: context.rw(6),
              bottom: context.rh(6),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: context.rw(7), vertical: context.rh(2)),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(context.rr(10)),
                ),
                child: Text('${index + 1}/$maxPhotos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: context.rsp(11),
                        fontWeight: FontWeight.w700)),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: -context.rr(4),
                right: -context.rr(4),
                child: IconButton(
                  tooltip: 'my_visits.survey.remove'.tr,
                  visualDensity: VisualDensity.compact,
                  onPressed: onRemove,
                  icon: Container(
                    padding: EdgeInsets.all(context.rr(3)),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: context.rr(14), color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The dashed "Add more" tile at the end of the strip, or, with no photos
/// yet, a full-width "Take or upload photos" tile.
class InventoryAddPhotoTile extends StatelessWidget {
  const InventoryAddPhotoTile({
    super.key,
    required this.size,
    required this.wide,
    required this.maxPhotos,
    required this.onTap,
  });

  final double size;
  final bool wide;
  final int maxPhotos;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final label = wide
        ? 'my_visits.survey.add_photos'.tr
        : 'my_visits.survey.add_more'.tr;

    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: 'my_visits.survey.add_photos'.tr,
      onTap: onTap,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        enabled: onTap != null,
        child: CustomPaint(
          painter: _DashedBorder(
            color: scheme.primary.withValues(alpha: 0.45),
            radius: context.rr(14),
          ),
          child: Container(
            width: wide ? double.infinity : size,
            constraints: BoxConstraints(minHeight: size),
            padding: EdgeInsets.all(context.rw(8)),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(context.rr(14)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: context.rr(38),
                  height: context.rr(38),
                  decoration: BoxDecoration(
                      color: scheme.primary, shape: BoxShape.circle),
                  child: Icon(Icons.add_rounded,
                      color: scheme.onPrimary, size: context.rr(24)),
                ),
                SizedBox(height: context.rh(6)),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: context.rsp(12.5),
                        fontWeight: FontWeight.w700,
                        color: scheme.primary)),
                Text(
                  'my_visits.survey.add_more_hint'.trParams({'max': maxPhotos}),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: context.rsp(10.5), color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    const dash = 6.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
