import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The ISI Steel chevron ribbon — the solid zigzag of the brand pattern
/// artwork in `assets/partterns/` — drawn as vector rather than shipped as a
/// bitmap, so it stays sharp at any width and takes theme colours.
///
/// The proportions are measured from that artwork: over one period (valley to
/// valley) the ribbon climbs [riseRatio] of the period and is
/// [thicknessRatio] of it thick, measured vertically.
///
/// Each colour in [layers] is one ribbon, stacked straight down by its own
/// thickness — ribbons with the same edge tile with no gap between them. With
/// [fillToBottom] the last layer runs down to the bottom of the canvas.
class GuestChevronPainter extends CustomPainter {
  const GuestChevronPainter({
    required this.period,
    required this.layers,
    this.valleyAt = 0,
    this.fillToBottom = false,
    this.bandThickness,
  });

  static const riseRatio = 0.289;
  static const thicknessRatio = 0.230;

  /// Horizontal distance between two valleys, in logical pixels.
  final double period;

  /// Ribbon colours, top first.
  final List<Color> layers;

  /// The x of one valley — the rest follow every [period] either side.
  final double valleyAt;

  final bool fillToBottom;

  /// Overrides the artwork's ribbon thickness — a thin band rather than the
  /// full ribbon, as along the guest landing's photo edge.
  final double? bandThickness;

  double get rise => period * riseRatio;
  double get thickness => bandThickness ?? period * thicknessRatio;

  /// The top edge of a ribbon [dy] below the first, from just left of the
  /// canvas to just past its right edge.
  List<Offset> _edge(double width, double dy) {
    final half = period / 2;
    // The first valley at or left of x = 0.
    final start = valleyAt - (valleyAt / period).ceil() * period;
    return [
      for (var k = 0; start + (k - 1) * half <= width; k++)
        Offset(start + k * half, dy + (k.isEven ? rise : 0)),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (var i = 0; i < layers.length; i++) {
      final top = _edge(size.width, i * thickness);
      final last = i == layers.length - 1;
      final outline = last && fillToBottom
          ? [
              ...top,
              Offset(top.last.dx, size.height),
              Offset(top.first.dx, size.height),
            ]
          : [
              ...top,
              for (final p in top.reversed) p.translate(0, thickness),
            ];
      canvas.drawPath(
        Path()..addPolygon(outline, true),
        Paint()..color = layers[i],
      );
    }
  }

  @override
  bool shouldRepaint(GuestChevronPainter old) =>
      old.period != period ||
      old.valleyAt != valleyAt ||
      old.fillToBottom != fillToBottom ||
      old.bandThickness != bandThickness ||
      !listEquals(old.layers, layers);
}
