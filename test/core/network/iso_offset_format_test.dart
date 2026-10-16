import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/network/api/api_envelope.dart';

void main() {
  group('formatIsoOffset', () {
    test('writes a UTC instant with the Z designator', () {
      expect(formatIsoOffset(DateTime.utc(2026, 8, 20, 9, 15)),
          '2026-08-20T09:15:00Z');
    });

    test('pads every component to a fixed width', () {
      expect(formatIsoOffset(DateTime.utc(2026, 1, 2, 3, 4, 5)),
          '2026-01-02T03:04:05Z');
    });

    test('drops sub-second precision rather than emitting it', () {
      expect(formatIsoOffset(DateTime.utc(2026, 8, 20, 9, 15, 30, 456)),
          '2026-08-20T09:15:30Z');
    });

    test('writes a local instant with an explicit offset, never bare', () {
      // The zone the suite runs in is not fixed, so assert the *shape*: a
      // bare `2026-08-20T09:15:00` with no offset is the failure this guards
      // against — a server would have to guess the zone, and guessing wrong
      // moves a Cambodian morning check-in into the previous night.
      final formatted = formatIsoOffset(DateTime(2026, 8, 20, 9, 15));

      expect(formatted, startsWith('2026-08-20T09:15:00'));
      expect(
        formatted,
        matches(RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}([+-]\d{2}:\d{2}|Z)$')),
        reason: 'must always carry an offset',
      );
    });

    test('round-trips back to the same instant through parseUtc', () {
      final local = DateTime(2026, 8, 20, 9, 15, 30);

      expect(parseUtc(formatIsoOffset(local)), local.toUtc());
    });

    test('a UTC instant round-trips unchanged', () {
      final utc = DateTime.utc(2026, 12, 31, 23, 59, 59);

      expect(parseUtc(formatIsoOffset(utc)), utc);
    });
  });
}
