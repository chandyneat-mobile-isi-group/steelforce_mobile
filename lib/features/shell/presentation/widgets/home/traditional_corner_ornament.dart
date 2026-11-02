/// The faint ring motif tucked into the corners of the steel-framed Home
/// cards (My Work tiles and the Monthly Target card). Restyle the ring here.
library;

import 'package:flutter/material.dart';
import 'package:steelforce/core/responsive/responsive_sizing.dart';

/// Traditional geometric motif corner decoration
class TraditionalCornerOrnament extends StatelessWidget {
  const TraditionalCornerOrnament({
    super.key,
    required this.color,
    required this.size,
  });

  /// Ring opacity and stroke — shared by every card that uses the motif.
  static const double _ringAlpha = 0.12;
  static const double _ringWidth = 2;

  final Color color;

  /// Diameter in design units (scaled with `context.rr`).
  final double size;

  /// The top-left / bottom-right (rotated) pair every card draws, each pushed
  /// [inset] design units outside the corner so only an arc shows. Spread the
  /// result straight into the card's [Stack].
  static List<Widget> corners(
    BuildContext context, {
    required Color color,
    required double size,
    required double inset,
  }) {
    final offset = -context.rr(inset);
    return [
      Positioned(
        top: offset,
        left: offset,
        child: TraditionalCornerOrnament(color: color, size: size),
      ),
      Positioned(
        bottom: offset,
        right: offset,
        child: Transform.rotate(
          angle: 3.14159,
          child: TraditionalCornerOrnament(color: color, size: size),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.rr(size),
      height: context.rr(size),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: _ringAlpha),
          width: _ringWidth,
        ),
      ),
    );
  }
}
