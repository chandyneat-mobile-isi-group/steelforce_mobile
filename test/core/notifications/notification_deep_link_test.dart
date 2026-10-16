import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/routes/app_routes.dart';

/// The §11 deep-link table.
///
/// Worth testing precisely because the failure is invisible: a notification that
/// opens the wrong screen looks like a working app until a rep reports it, and
/// nothing in the build catches it. Every URI the spec publishes is asserted
/// here, including the ones this build cannot open yet.
void main() {
  group('resolve', () {
    test('routes the published URI table', () {
      expect(
        NotificationDeepLink.resolve('app://routes/r-1')!.route,
        Static.myVisits,
      );
      expect(
        NotificationDeepLink.resolve('app://routes/r-1/stops/s-2')!.route,
        Static.myVisits,
      );
      expect(
          NotificationDeepLink.resolve('app://today')!.route, Static.myVisits);
      expect(
        NotificationDeepLink.resolve('app://quotations/q-1')!.route,
        Static.order,
      );
      expect(
        NotificationDeepLink.resolve('app://orders/o-1')!.route,
        Static.order,
      );
      expect(
        NotificationDeepLink.resolve('app://depots/c-1')!.route,
        Static.depot,
      );
      expect(
        NotificationDeepLink.resolve('app://dashboard')!.route,
        Static.main,
      );
      expect(
        NotificationDeepLink.resolve('app://notifications')!.route,
        NotificationDeepLink.inboxRoute,
      );
      expect(
        NotificationDeepLink.resolve('app://settings/notifications')!.route,
        NotificationDeepLink.notificationSettingsRoute,
      );
    });

    test('carries the entity ids the target screen needs', () {
      expect(
        NotificationDeepLink.resolve('app://routes/r-1')!.arguments,
        {'routeId': 'r-1'},
      );
      expect(
        NotificationDeepLink.resolve('app://routes/r-1/stops/s-2')!.arguments,
        {'routeId': 'r-1', 'stopId': 's-2'},
      );
      expect(
        NotificationDeepLink.resolve('app://depots/c-1')!.arguments,
        'c-1',
      );
    });

    test('keeps the query so a screen can honour a tab or filter hint', () {
      // `app://orders/{id}?tab=credit` for a credit hold, per §11.
      expect(
        NotificationDeepLink.resolve('app://orders/o-1?tab=credit')!.query,
        {'tab': 'credit'},
      );
      expect(
        NotificationDeepLink.resolve('app://dashboard?period=yesterday')!.query,
        {'period': 'yesterday'},
      );
    });

    test('parses the path form as well as the authority form', () {
      // `app://routes/{id}` puts `routes` in the *host*; the web links use the
      // path form. One table has to cover both or half the links dead-end.
      expect(
        NotificationDeepLink.resolve('/routes/r-1')!.route,
        Static.myVisits,
      );
      expect(
        NotificationDeepLink.resolve('/routes/r-1')!.arguments,
        {'routeId': 'r-1'},
      );
    });

    test('falls back to the inbox for a screen this build lacks', () {
      // §11: an event that points at no single record, and any URI naming a
      // screen that does not exist yet, must land somewhere that can explain
      // itself rather than nowhere.
      expect(
        NotificationDeepLink.resolve('app://approvals?filter=quote')!.route,
        NotificationDeepLink.inboxRoute,
      );
      expect(
        NotificationDeepLink.resolve('app://some-future-screen/x')!.route,
        NotificationDeepLink.inboxRoute,
      );
      expect(NotificationDeepLink.resolve('app://')!.route,
          NotificationDeepLink.inboxRoute);
    });

    test('returns null rather than the inbox for a non-link', () {
      // The distinction matters: "nothing to route to" must not steal focus
      // from whatever the rep was already doing.
      expect(NotificationDeepLink.resolve(null), isNull);
      expect(NotificationDeepLink.resolve(''), isNull);
      expect(
          NotificationDeepLink.resolve('https://example.com/routes/1'), isNull);
    });

    test('isRoutable separates a real destination from the fallback', () {
      expect(NotificationDeepLink.isRoutable('app://routes/r-1'), isTrue);
      expect(NotificationDeepLink.isRoutable('app://approvals'), isFalse);
      expect(NotificationDeepLink.isRoutable(null), isFalse);
    });
  });

  group('PendingNotificationLink', () {
    test('take is destructive so a link cannot be opened twice', () {
      final pending = PendingNotificationLink()..set('app://routes/r-1');

      expect(pending.hasLink, isTrue);
      expect(pending.take(), 'app://routes/r-1');
      expect(pending.take(), isNull);
    });

    test('last write wins', () {
      // Two notifications tapped before either is handled: the second is the one
      // the rep just chose, and honouring the first would open a screen they had
      // already moved past.
      final pending = PendingNotificationLink()
        ..set('app://routes/r-1')
        ..set('app://orders/o-1');

      expect(pending.take(), 'app://orders/o-1');
    });

    test('an empty link is not stored', () {
      final pending = PendingNotificationLink()
        ..set(null)
        ..set('');

      expect(pending.hasLink, isFalse);
    });

    test('clear drops a link without opening it', () {
      // Sign-out: one rep's deep link must not open for whoever signs in next.
      final pending = PendingNotificationLink()..set('app://routes/r-1');

      pending.clear();

      expect(pending.hasLink, isFalse);
    });
  });
}
