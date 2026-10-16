import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/shared/widgets/promotions/promo_view.dart';

PromoView _promo({required DateTime endsOn, PromoStatus? status}) => PromoView(
      id: 'x',
      title: 'x',
      kind: PromoKind.onInvoice,
      value: const PromoPercent(2),
      status: status ?? PromoStatus.active,
      endsOn: endsOn,
    );

void main() {
  // A fixed clock, mid-morning: the time of day is what makes naive
  // `Duration.inDays` arithmetic wrong, so a test pinned to midnight would
  // pass on code that misbehaves in the field.
  final now = DateTime(2026, 3, 10, 9, 30);

  group('daysLeft', () {
    test('counts whole calendar days regardless of time of day', () {
      expect(_promo(endsOn: DateTime(2026, 3, 20, 23, 59)).daysLeft(now), 10);
      expect(_promo(endsOn: DateTime(2026, 3, 20, 0, 1)).daysLeft(now), 10);
    });

    test('is zero on the last day and negative afterwards', () {
      expect(_promo(endsOn: DateTime(2026, 3, 10, 18)).daysLeft(now), 0);
      expect(_promo(endsOn: DateTime(2026, 3, 9)).daysLeft(now), -1);
    });

    test('survives a daylight-saving boundary', () {
      // The reason `daysLeft` rounds from hours instead of reading
      // `Duration.inDays`: across a spring-forward boundary the difference
      // between two local midnights is 23 hours, which truncates to one day
      // short and would tell a rep a promotion ends the day before it does.
      final beforeDst = DateTime(2026, 3, 7, 9);
      final afterDst = DateTime(2026, 3, 14);
      expect(_promo(endsOn: afterDst).daysLeft(beforeDst), 7);
    });
  });

  group('urgency', () {
    test('a week or less is urgent', () {
      expect(_promo(endsOn: DateTime(2026, 3, 17)).urgency(now),
          PromoUrgency.urgent);
      expect(_promo(endsOn: DateTime(2026, 3, 18)).urgency(now),
          PromoUrgency.soon);
    });

    test('a month or less is soon, beyond that is normal', () {
      expect(
          _promo(endsOn: DateTime(2026, 4, 9)).urgency(now), PromoUrgency.soon);
      expect(_promo(endsOn: DateTime(2026, 4, 11)).urgency(now),
          PromoUrgency.normal);
    });

    test('a past end date is expired even when the status still says active',
        () {
      // The two can disagree: a promotion stays ACTIVE in the BRD's
      // `promotion` table until something deactivates it, while its validity
      // period (FR-14) has already lapsed. The date wins, because quoting a
      // lapsed rate commits a price the company then has to retract.
      expect(_promo(endsOn: DateTime(2026, 3, 1)).urgency(now),
          PromoUrgency.expired);
      expect(_promo(endsOn: DateTime(2026, 3, 1)).isQuotable(now), isFalse);
    });

    test('an explicitly expired status is expired even with a future date', () {
      final promo =
          _promo(endsOn: DateTime(2026, 6, 1), status: PromoStatus.expired);
      expect(promo.urgency(now), PromoUrgency.expired);
      expect(promo.isQuotable(now), isFalse);
    });
  });

  test('only an active, in-date promotion is quotable', () {
    expect(_promo(endsOn: DateTime(2026, 4, 1)).isQuotable(now), isTrue);
    expect(
      _promo(endsOn: DateTime(2026, 4, 1), status: PromoStatus.pending)
          .isQuotable(now),
      isFalse,
      reason: 'a request still in the approval chain is not a rate to quote',
    );
  });
}
