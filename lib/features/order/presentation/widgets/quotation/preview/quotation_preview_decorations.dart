import 'package:flutter/material.dart';
import 'package:steelforce/core/theme/theme_extensions.dart';
import 'package:steelforce/shared/widgets/painters/dashed_rrect.dart';

/// Paints the preview card: a solid rounded background with a dashed border
/// drawn on its edge, like a printed tear-off quote.
class DottedCardBorderPainter extends CustomPainter {
  final Color borderColor;
  final Color backgroundColor;
  final double strokeWidth;
  final double radius;
  final double dashLength;
  final double gap;

  DottedCardBorderPainter({
    required this.borderColor,
    required this.backgroundColor,
    required this.strokeWidth,
    required this.radius,
    required this.dashLength,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      halfWidth,
      halfWidth,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(radius - halfWidth));

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Uses the polyline walker rather than PathMetrics.extractPath, which
    // overflows the stack on web — see drawDashedRRect's doc comment.
    drawDashedRRect(canvas, rrect, borderPaint, dash: dashLength, gap: gap);
  }

  @override
  bool shouldRepaint(covariant DottedCardBorderPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.dashLength != dashLength ||
        oldDelegate.gap != gap;
  }
}

/// A full-width dashed rule between the preview's sections.
class DashedDivider extends StatelessWidget {
  const DashedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.divider),
              ),
            );
          }),
        );
      },
    );
  }
}
