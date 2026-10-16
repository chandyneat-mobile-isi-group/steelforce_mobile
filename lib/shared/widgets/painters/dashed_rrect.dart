import 'dart:math' as math;
import 'dart:ui';

/// Strokes [rrect] as a dashed outline, without touching `PathMetrics`.
///
/// ## Why this exists
///
/// The obvious implementation is `path.computeMetrics()` and then
/// `metric.extractPath(a, b)` once per dash. On Android and iOS that is fine.
/// On **web** it blows the stack: Flutter's HTML/CanvasKit engine builds paths
/// lazily (`lib/_engine/engine/lazy_path.dart`), and extracting a sub-path from
/// a metric of a lazily-built path re-enters the builder, so a border with a
/// few dozen dashes recurses through
/// `builtPath → apply → builtPath → buildIterator → builtMetricAtIndex → …`
/// until it overflows. The failure is a wall of identical frames with no line
/// of app code in it, which is why it is worth never producing.
///
/// So the outline is flattened to a polyline once — straight edges plus sampled
/// corner arcs — and then walked arithmetically, emitting one `drawLine` per
/// dash. No `Path`, no metrics, nothing lazy, and it is cheaper besides.
///
/// [dash] and [gap] are in logical pixels along the perimeter. Corner arcs are
/// sampled at [arcSegments] segments per 90°, which is indistinguishable from a
/// true arc at the radii used in this app.
void drawDashedRRect(
  Canvas canvas,
  RRect rrect,
  Paint paint, {
  double dash = 6.0,
  double gap = 4.0,
  int arcSegments = 8,
}) {
  assert(dash > 0 && gap >= 0, 'a non-positive dash would loop forever');
  final points = flattenRRect(rrect, arcSegments: arcSegments);
  if (points.length < 2) return;

  // Walk the polyline, carrying leftover distance across vertices so a dash
  // spans a corner instead of restarting at it — restarting is what makes a
  // hand-rolled dashed border look subtly wrong at the corners.
  var remaining = dash;
  var drawing = true;

  for (var i = 0; i < points.length - 1; i++) {
    var from = points[i];
    final to = points[i + 1];
    var segment = (to - from).distance;

    while (segment > 0) {
      final step = math.min(remaining, segment);
      final t = step / segment;
      final next = Offset(
        from.dx + (to.dx - from.dx) * t,
        from.dy + (to.dy - from.dy) * t,
      );
      if (drawing) canvas.drawLine(from, next, paint);

      from = next;
      segment -= step;
      remaining -= step;

      if (remaining <= 0) {
        drawing = !drawing;
        remaining = drawing ? dash : gap;
      }
    }
  }
}

/// The outline of [rrect] as a closed polyline: four edges and four sampled
/// corner arcs. Exposed for tests — a dashed border is hard to assert on, a
/// point list is not.
List<Offset> flattenRRect(RRect rrect, {int arcSegments = 8}) {
  final points = <Offset>[];

  void arc(Offset centre, double rx, double ry, double startDeg) {
    for (var i = 0; i <= arcSegments; i++) {
      final a = (startDeg + 90.0 * i / arcSegments) * math.pi / 180.0;
      points.add(
          Offset(centre.dx + rx * math.cos(a), centre.dy + ry * math.sin(a)));
    }
  }

  final l = rrect.left, t = rrect.top, r = rrect.right, b = rrect.bottom;

  points.add(Offset(l + rrect.tlRadiusX, t));
  points.add(Offset(r - rrect.trRadiusX, t));
  arc(Offset(r - rrect.trRadiusX, t + rrect.trRadiusY), rrect.trRadiusX,
      rrect.trRadiusY, -90);

  points.add(Offset(r, b - rrect.brRadiusY));
  arc(Offset(r - rrect.brRadiusX, b - rrect.brRadiusY), rrect.brRadiusX,
      rrect.brRadiusY, 0);

  points.add(Offset(l + rrect.blRadiusX, b));
  arc(Offset(l + rrect.blRadiusX, b - rrect.blRadiusY), rrect.blRadiusX,
      rrect.blRadiusY, 90);

  points.add(Offset(l, t + rrect.tlRadiusY));
  arc(Offset(l + rrect.tlRadiusX, t + rrect.tlRadiusY), rrect.tlRadiusX,
      rrect.tlRadiusY, 180);

  points.add(points.first); // close
  return points;
}
