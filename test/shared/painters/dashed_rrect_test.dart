import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/shared/widgets/painters/dashed_rrect.dart';
import 'package:mocktail/mocktail.dart';

class _RecordingCanvas extends Mock implements Canvas {}

void main() {
  // mocktail needs a prototype for every argument type matched with any().
  setUpAll(() {
    registerFallbackValue(Offset.zero);
    registerFallbackValue(Paint());
  });

  final rrect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(0, 0, 200, 100),
    const Radius.circular(12),
  );

  group('flattenRRect', () {
    test('returns a closed outline that stays inside the rect', () {
      final points = flattenRRect(rrect);

      expect(points.first, points.last, reason: 'the outline must close');
      expect(points.length, greaterThan(8), reason: 'corners must be sampled');

      for (final p in points) {
        expect(p.dx, inInclusiveRange(rrect.left - 0.01, rrect.right + 0.01));
        expect(p.dy, inInclusiveRange(rrect.top - 0.01, rrect.bottom + 0.01));
      }
    });

    test('a zero radius degenerates to a plain rectangle outline', () {
      final square = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 10, 10),
        Radius.zero,
      );
      final corners = flattenRRect(square).toSet();

      for (final c in [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 10),
        const Offset(0, 10),
      ]) {
        expect(corners.contains(c), isTrue,
            reason: '$c must be on the outline');
      }
    });
  });

  group('drawDashedRRect', () {
    test('emits many short lines rather than one path', () {
      // The regression this guards: the previous implementation called
      // PathMetrics.extractPath once per dash, which recurses through Flutter
      // web's lazy path builder until the stack overflows. Nothing here builds
      // a Path at all.
      final canvas = _RecordingCanvas();
      drawDashedRRect(canvas, rrect, Paint(), dash: 6, gap: 4);

      // perimeter ≈ 2*(200+100) minus corner shortening, one dash per 10px
      verify(() => canvas.drawLine(any(), any(), any()))
          .called(greaterThan(20));
    });

    test('gap larger than the perimeter still terminates', () {
      final canvas = _RecordingCanvas();
      expect(
        () => drawDashedRRect(canvas, rrect, Paint(), dash: 4, gap: 100000),
        returnsNormally,
      );
    });
  });
}
