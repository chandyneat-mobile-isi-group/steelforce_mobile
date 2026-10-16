import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/features/notification/data/models/notification_api_mapper.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// `NotificationApiMapper` against the payloads §5, §7, §9 and §13 publish.
///
/// The fixture below is the §5 example verbatim, so a change to the published
/// contract shows up here as a failing test rather than as a field that quietly
/// stops parsing.
void main() {
  /// The §5 notification object, copied field for field.
  Map<String, dynamic> specNotification() => {
        'notification_id': '0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5b',
        'event_code': 'ROUTE.ASSIGNED',
        'category': 'ASSIGNMENT',
        'priority': 'P2',
        'title': 'New route assigned — Wed, 26 Aug',
        'body': 'North Phnom Penh R3: 12 stops from 08:00.',
        'image_url': null,
        'deep_link': 'app://routes/0198f2b0-1111-7000-8000-000000000001',
        'web_link': '/routes/0198f2b0-1111-7000-8000-000000000001',
        'requires_ack': true,
        'expires_at': null,
        'group_key': 'Assignment:0198f2b0-1111-7000-8000-000000000001',
        'badge': 3,
        'actions': [
          {
            'id': 'view',
            'label': 'View Route',
            'type': 'deeplink',
            'endpoint': null,
            'method': null,
            'destructive': false,
          },
          {
            'id': 'ack',
            'label': 'Acknowledge',
            'type': 'api_call',
            'endpoint': '/api/v1/routes/0198f2b0/acknowledge',
            'method': 'POST',
            'destructive': false,
          },
        ],
        'data': {
          'entity_type': 'route',
          'entity_id': '0198f2b0-1111-7000-8000-000000000001',
          'route_date': '2026-08-26',
          'stop_count': '12',
        },
        'state': 'unread',
        'created_at': '2026-08-25T08:12:04Z',
        'delivered_at': '2026-08-25T08:12:04Z',
        'read_at': null,
        'actioned_at': null,
      };

  group('inbox object', () {
    test('parses the §5 example', () {
      final message = NotificationApiMapper.fromJson(specNotification())!;

      expect(message.id, '0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5b');
      expect(message.eventCode, 'ROUTE.ASSIGNED');
      expect(message.category, NotificationCategory.assignment);
      expect(message.priority, NotificationPriority.p2);
      expect(message.state, NotificationState.unread);
      expect(message.requiresAck, isTrue);
      expect(message.badge, 3);
      expect(message.deepLink,
          'app://routes/0198f2b0-1111-7000-8000-000000000001');
      expect(message.entityType, 'route');
      expect(message.createdAt, DateTime.utc(2026, 8, 25, 8, 12, 4));
      expect(message.createdAt.isUtc, isTrue);
    });

    test('an item requiring acknowledgement is outstanding and undismissable',
        () {
      final message = NotificationApiMapper.fromJson(specNotification())!;

      expect(message.isOutstandingAction, isTrue);
      // §5.4: `DELETE` answers 409 for these, so the client must agree.
      expect(message.isDismissible, isFalse);
    });

    test('reading does not close an item that needs acknowledgement', () {
      // §8.3 in one assertion: this is the whole supervisor escalation chain.
      final read = NotificationApiMapper.fromJson(specNotification())!
          .markedRead(DateTime.utc(2026, 8, 25, 9));

      expect(read.state, NotificationState.read);
      expect(read.isOutstandingAction, isTrue);
    });

    test('the first read timestamp wins on replay', () {
      final first = DateTime.utc(2026, 8, 25, 9);
      final message = NotificationApiMapper.fromJson(specNotification())!
          .markedRead(first)
          .markedRead(DateTime.utc(2026, 8, 25, 11));

      expect(message.readAt, first);
    });

    test('data values are strings even when the JSON sends numbers', () {
      // §9.1: every FCM `data` value is a string. The inbox response is real
      // JSON and may send a number for the same field; one notification must not
      // parse differently depending on which path delivered it.
      final json = specNotification()..['data'] = {'stop_count': 12};

      expect(NotificationApiMapper.fromJson(json)!.data['stop_count'], '12');
    });

    test('drops a row with no id rather than storing an unkeyable one', () {
      final json = specNotification()..remove('notification_id');

      expect(NotificationApiMapper.fromJson(json), isNull);
    });

    test('an unknown category degrades instead of dropping the row', () {
      final json = specNotification()..['category'] = 'CREDIT_HOLD';
      final message = NotificationApiMapper.fromJson(json)!;

      expect(message.category, NotificationCategory.unknown);
      expect(message.title, isNotEmpty);
    });

    test('an unknown state stays visible and actionable', () {
      final json = specNotification()..['state'] = 'quarantined';

      expect(
        NotificationApiMapper.fromJson(json)!.state,
        NotificationState.unread,
      );
    });
  });

  group('actions (§12)', () {
    test('parses both types and their destructive flag', () {
      final actions =
          NotificationApiMapper.fromJson(specNotification())!.actions;

      expect(actions, hasLength(2));
      expect(actions.first.type, NotificationActionType.deeplink);
      expect(actions.last.type, NotificationActionType.apiCall);
      expect(actions.last.endpoint, '/api/v1/routes/0198f2b0/acknowledge');
      expect(actions.last.destructive, isFalse);
    });

    test('caps at three', () {
      final json = specNotification()
        ..['actions'] = [
          for (var i = 0; i < 6; i++)
            {'id': 'a$i', 'label': 'A$i', 'type': 'deeplink'},
        ];

      expect(
        NotificationApiMapper.fromJson(json)!.actions,
        hasLength(NotificationAction.maxButtons),
      );
    });

    test('drops an api_call with no endpoint', () {
      // An unrunnable button that silently does nothing is worse than none.
      final json = specNotification()
        ..['actions'] = [
          {'id': 'ack', 'label': 'Acknowledge', 'type': 'api_call'},
        ];

      expect(NotificationApiMapper.fromJson(json)!.actions, isEmpty);
    });

    test('drops an action whose type this build cannot execute', () {
      final json = specNotification()
        ..['actions'] = [
          {'id': 'x', 'label': 'Do it', 'type': 'quantum_entangle'},
        ];

      expect(NotificationApiMapper.fromJson(json)!.actions, isEmpty);
    });
  });

  group('push payload (§9)', () {
    test('normalises the shorthand event code back to the canonical form', () {
      // §9.1 ships `event_code` and `type` — the same fact in two conventions —
      // and §18 records that the duplication is unresolved. Neither may be the
      // one this client depends on.
      const shorthandOnly = PushMessage(data: {'type': 'ROUTE_ASSIGNED'});
      const canonical = PushMessage(
        data: {'event_code': 'ROUTE.ASSIGNED', 'type': 'ROUTE_ASSIGNED'},
      );

      expect(shorthandOnly.eventCode, 'ROUTE.ASSIGNED');
      expect(canonical.eventCode, 'ROUTE.ASSIGNED');
    });

    test('reads the deep link from either the canonical field or the alias',
        () {
      const alias = PushMessage(data: {'action': 'app://routes/r-1'});
      expect(alias.deepLink, 'app://routes/r-1');
    });

    test('a push-built row is never marked as requiring acknowledgement', () {
      // The payload carries no `requires_ack`. Guessing true would pin a routine
      // update to the top of Action needed and refuse to let the rep clear it.
      const push = PushMessage(
        data: {'notification_id': 'n1', 'category': 'ASSIGNMENT'},
        title: 'New route assigned',
        body: 'Tap to review.',
      );

      final message = NotificationApiMapper.fromPush(
        push,
        receivedAt: DateTime.utc(2026, 8, 25, 9),
      )!;

      expect(message.requiresAck, isFalse);
      expect(message.actions, isEmpty);
      expect(message.state, NotificationState.unread);
    });

    test('a push with no notification id yields nothing to store', () {
      const push = PushMessage(data: {'category': 'SYSTEM'}, title: 'Hi');

      expect(
        NotificationApiMapper.fromPush(push, receivedAt: DateTime.utc(2026)),
        isNull,
      );
    });

    test('a data-only push is recognised as silent', () {
      const push = PushMessage(data: {'notification_id': 'n1'});
      expect(push.isSilent, isTrue);
    });

    test('toString carries no title, body or data values', () {
      // A push body can name a depot; `docs/skills/security.md` §10 keeps depot
      // information out of logs.
      const push = PushMessage(
        data: {'event_code': 'ORDER.CREDIT_HOLD', 'entity_id': 'secret-id'},
        title: 'Sok Heng Hardware is on credit hold',
        body: 'Limit exceeded by \$4,200',
      );

      final rendered = push.toString();
      expect(rendered, contains('ORDER.CREDIT_HOLD'));
      expect(rendered, isNot(contains('Sok Heng')));
      expect(rendered, isNot(contains('4,200')));
      expect(rendered, isNot(contains('secret-id')));
    });
  });

  group('counts (§7)', () {
    test('parses the published shape', () {
      final counts = NotificationApiMapper.countsFromJson({
        'unread': 12,
        'action_required': 3,
        'by_category': {'ASSIGNMENT': 2, 'ORDER': 7, 'KPI': 3},
        'sync_timestamp': '2026-08-25T08:12:04.512Z',
      });

      expect(counts.unread, 12);
      expect(counts.actionRequired, 3);
      expect(counts.forCategory(NotificationCategory.order), 7);
      expect(counts.syncTimestamp, isNotNull);
    });

    test('sums unknown categories rather than dropping them', () {
      final counts = NotificationApiMapper.countsFromJson({
        'unread': 5,
        'by_category': {'FUTURE_ONE': 2, 'FUTURE_TWO': 3},
      });

      expect(counts.forCategory(NotificationCategory.unknown), 5);
    });

    test('the optimistic decrement clamps at zero', () {
      const counts = NotificationCounts(unread: 1);
      expect(counts.withUnread(-3).unread, 0);
    });
  });

  group('preferences (§13)', () {
    Map<String, dynamic> specPreferences() => {
          'quietHoursStart': '20:00:00',
          'quietHoursEnd': '07:00:00',
          'quietDays': <String>[],
          'digestTime': '18:00:00',
          'language': 'km-KH',
          'categories': [
            {
              'category': 'ASSIGNMENT',
              'displayName': 'Assignments & Schedule',
              'isEnabled': true,
              'pushEnabled': true,
              'isLocked': true,
            },
            {
              'category': 'KPI',
              'displayName': 'Performance & KPI',
              'isEnabled': true,
              'pushEnabled': false,
              'isLocked': false,
            },
          ],
        };

    test('parses the §13 example', () {
      final preferences =
          NotificationApiMapper.preferencesFromJson(specPreferences());

      expect(preferences.hasQuietHours, isTrue);
      expect(preferences.quietHoursWrapMidnight, isTrue);
      // `quietDays: []` means **every day**, not "no days".
      expect(preferences.quietEveryDay, isTrue);
      expect(preferences.categories, hasLength(2));
      expect(preferences.categoryPreference('KPI')!.pushEnabled, isFalse);
    });

    test('a missing category flag defaults to on, not off', () {
      // §13: absence of a record means "everything", not "nothing". Defaulting
      // to false would render a fresh account as having muted itself.
      final preferences = NotificationApiMapper.preferencesFromJson({
        'categories': [
          {'category': 'ORDER', 'displayName': 'Orders'},
        ],
      });

      final order = preferences.categoryPreference('ORDER')!;
      expect(order.isEnabled, isTrue);
      expect(order.pushEnabled, isTrue);
    });

    test('renders a category this build has never heard of', () {
      final preferences = NotificationApiMapper.preferencesFromJson({
        'categories': [
          {'category': 'CREDIT_HOLD', 'displayName': 'Credit holds'},
        ],
      });

      expect(preferences.categoryPreference('CREDIT_HOLD'), isNotNull);
      expect(
        preferences.categoryPreference('CREDIT_HOLD')!.displayName,
        'Credit holds',
      );
    });

    test('a locked category cannot be flipped locally', () {
      // The server answers 422 rather than ignoring it, so a toggle that moves
      // and snaps back reads as a bug even when the refusal is correct.
      final preferences =
          NotificationApiMapper.preferencesFromJson(specPreferences())
              .withCategory('ASSIGNMENT', isEnabled: false);

      expect(preferences.categoryPreference('ASSIGNMENT')!.isEnabled, isTrue);
    });

    test('the save payload omits locked categories', () {
      final json = NotificationApiMapper.preferencesToJson(
        NotificationApiMapper.preferencesFromJson(specPreferences()),
      );

      final categories = (json['categories'] as List).cast<Map>();
      expect(categories.map((c) => c['category']), ['KPI']);
    });

    test('quiet-hours start and end are sent together or not at all', () {
      // §13: one without the other answers
      // `400 Notification.QuietHoursIncomplete`.
      final halfSet = NotificationApiMapper.preferencesToJson(
        const NotificationPreferences(quietHoursStart: '20:00:00'),
      );
      expect(halfSet.containsKey('quietHoursStart'), isFalse);
      expect(halfSet.containsKey('quietHoursEnd'), isFalse);

      final complete = NotificationApiMapper.preferencesToJson(
        const NotificationPreferences(
          quietHoursStart: '20:00:00',
          quietHoursEnd: '07:00:00',
        ),
      );
      expect(complete['quietHoursStart'], '20:00:00');
      expect(complete['quietHoursEnd'], '07:00:00');
    });

    test('an empty quietDays list is still sent', () {
      // Dropping it would be read server-side as "leave alone", not as
      // "every day" — which is what an empty list means.
      final json = NotificationApiMapper.preferencesToJson(
        const NotificationPreferences(quietDays: []),
      );

      expect(json['quietDays'], isEmpty);
      expect(json.containsKey('quietDays'), isTrue);
    });
  });

  group('device registration (§4.2)', () {
    test('sends the documented body, including a declined permission', () {
      final json = NotificationApiMapper.registrationToJson(
        PushRegistration(
          deviceId: 'installation-1',
          pushToken: 'fEo7x:APA91bH',
          platform: PushPlatform.android,
          pushPermissionGranted: false,
          deviceName: 'Pixel 8',
          timeZone: 'Asia/Phnom_Penh',
          latitude: 11.5564,
          longitude: 104.9282,
          locationAccuracyMeters: 10.0,
          locationCapturedAt: DateTime.utc(2026, 8, 25),
        ),
      );

      expect(json['deviceId'], 'installation-1');
      expect(json['platform'], 'Android');
      expect(json['timeZone'], 'Asia/Phnom_Penh');
      // Always sent, including false: a declined registration is kept and
      // excluded from the push audience, so the delivery log reads `NO_DEVICE`
      // rather than a run of failures.
      expect(json['pushPermissionGranted'], isFalse);
    });

    test('omits an absent optional field rather than sending it empty', () {
      final json = NotificationApiMapper.registrationToJson(
        PushRegistration(
          deviceId: 'installation-1',
          pushToken: 't',
          platform: PushPlatform.ios,
          pushPermissionGranted: true,
          latitude: 11.5564,
          longitude: 104.9282,
          locationAccuracyMeters: 10.0,
          locationCapturedAt: DateTime.utc(2026, 8, 25),
        ),
      );

      expect(json.containsKey('deviceName'), isFalse);
      expect(json.containsKey('timeZone'), isFalse);
    });

    test('treats a 2xx with no isActive as an active registration', () {
      // A 2xx from this endpoint means the registration is live — a deactivated
      // one is *revived* by the call (§4.3). Defaulting to false would report a
      // working registration as dead.
      final result = NotificationApiMapper.registrationFromJson({
        'id': 'r1',
        'deviceId': 'installation-1',
      });

      expect(result.isActive, isTrue);
    });
  });
}
