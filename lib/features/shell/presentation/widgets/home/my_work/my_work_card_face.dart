/// The inner surface of a My Work tile: tinted background, corner ornaments,
/// the animated work icon and the label. The steel frame lives in my_work_card.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';
import 'package:steelforce/features/shell/presentation/widgets/home/traditional_corner_ornament.dart';
import 'package:steelforce/shared/animations/work_icons.dart';

class MyWorkCardFace extends StatelessWidget {
  const MyWorkCardFace({
    super.key,
    required this.label,
    required this.accent,
    required this.kind,
    this.tileHeight,
  });

  // Style constants (design units).
  static const double _radius = 18;
  static const double _surfaceTint = 0.05;
  static const double _ornamentSize = 36;
  static const double _ornamentInset = 12;
  static const double _defaultIconSize = 66;
  static const double _iconToLabelGap = 10;
  static const double _labelPadH = 8;
  static const double _labelFontSize = 13.5;

  final String label;
  final Color accent;
  final WorkIconKind kind;
  final double? tileHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(context.rr(_radius));

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        color: scheme.surface,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            Color.lerp(scheme.surface, accent, _surfaceTint)!,
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Traditional Corner Ornaments
            ...TraditionalCornerOrnament.corners(
              context,
              color: accent,
              size: _ornamentSize,
              inset: _ornamentInset,
            ),

            // Card Content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  WorkIcon(
                    kind: kind,
                    accent: accent,
                    size: tileHeight ?? context.rr(_defaultIconSize),
                  ),
                  SizedBox(height: context.rh(_iconToLabelGap)),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.rw(_labelPadH)),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.rsp(_labelFontSize),
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
