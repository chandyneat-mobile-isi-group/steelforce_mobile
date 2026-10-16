import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';

/// The demo rep's inbox and notification settings.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// Every item names something the demo actually holds: today's route
/// ([DemoSeed.todayRouteId]), the shared [DemoSeed] depots, and quotations
/// seeded by the order feature's demo backend. That feature's data layer may
/// not be imported from here, so its stable ids (`dq-seed-NN`) and numbers
/// (`Q-<year>-04NN`) are repeated below; `mock_notification_remote_data_source_test`
/// fails if the two drift apart.
///
/// The set still covers the cases that are easy to get wrong: an item that
/// requires acknowledgement (pinned, not swipeable), a P1, a P4 that never
/// arrives as a push, an `api_call` action beside a `deeplink` one, and a
/// `resolved_elsewhere` row that belongs in history with an explanation.
abstract final class DemoNotificationFixtures {
  static String quotationNumber(DateTime now, int seed) =>
      'Q-${now.year}-${(400 + seed).toString().padLeft(4, '0')}';

  static String quotationId(int seed) =>
      'dq-seed-${seed.toString().padLeft(2, '0')}';

  static List<NotificationMessage> inbox(DateTime now) {
    final today = DateTime(now.year, now.month, now.day).toUtc();
    final route = DemoSeed.todayRouteId;
    final stops = DemoSeed.todayStops;
    final routeAck = '/api/v1/routes/$route/acknowledge';

    NotificationMessage quote(String id, String event, int seed, String depot,
        String title, String body, DateTime at,
        {NotificationPriority priority = NotificationPriority.p3,
        NotificationState state = NotificationState.unread}) {
      return NotificationMessage(
        id: id,
        eventCode: event,
        category: NotificationCategory.quote,
        priority: priority,
        title: title.replaceAll('#', quotationNumber(now, seed)),
        body: '$body — $depot.',
        deepLink: 'app://quotations/${quotationId(seed)}',
        groupKey: 'Quote:${quotationId(seed)}',
        data: {'entity_type': 'quotation', 'entity_id': quotationId(seed)},
        state: state,
        createdAt: at,
        deliveredAt: at,
        readAt: state == NotificationState.unread ? null : at,
      );
    }

    return [
      NotificationMessage(
        id: 'demo-ntf-01',
        eventCode: 'ROUTE.ASSIGNED',
        category: NotificationCategory.assignment,
        priority: NotificationPriority.p2,
        title: "Today's route assigned — ${stops.length} stops",
        body: 'First stop ${stops.first.name} at 08:00. '
            'Tap to review and confirm.',
        deepLink: 'app://routes/$route',
        requiresAck: true,
        groupKey: 'Assignment:$route',
        badge: 3,
        actions: [
          const NotificationAction(
            id: 'view',
            label: 'View Route',
            type: NotificationActionType.deeplink,
          ),
          NotificationAction(
            id: 'ack',
            label: 'Acknowledge',
            type: NotificationActionType.apiCall,
            endpoint: routeAck,
            method: 'POST',
          ),
        ],
        data: {
          'entity_type': 'route',
          'entity_id': route,
          'stop_count': '${stops.length}',
        },
        state: NotificationState.unread,
        createdAt: today.add(const Duration(hours: 6, minutes: 30)),
        deliveredAt: today.add(const Duration(hours: 6, minutes: 30)),
      ),
      NotificationMessage(
        id: 'demo-ntf-02',
        eventCode: 'ROUTE.UPDATED',
        category: NotificationCategory.assignment,
        priority: NotificationPriority.p1,
        title: "Today's route changed",
        body: '${stops.last.name} moved to the end of the day. '
            'Do not travel there before 15:00.',
        deepLink: 'app://routes/$route',
        requiresAck: true,
        actions: [
          NotificationAction(
            id: 'ack',
            label: 'Acknowledge',
            type: NotificationActionType.apiCall,
            endpoint: routeAck,
            method: 'POST',
          ),
        ],
        data: {'entity_type': 'route', 'entity_id': route},
        state: NotificationState.unread,
        createdAt: today.add(const Duration(hours: 7, minutes: 5)),
        deliveredAt: today.add(const Duration(hours: 7, minutes: 5)),
      ),
      quote(
          'demo-ntf-03',
          'QUOTE.APPROVED',
          7,
          DemoSeed.depots[6].name,
          'Quotation # approved',
          'Released by your manager',
          today.subtract(const Duration(days: 3, hours: -10))),
      quote(
          'demo-ntf-04',
          'QUOTE.RETURNED',
          3,
          DemoSeed.depots[4].name,
          'Quotation # returned for changes',
          'Reduce the manual discount',
          today.subtract(const Duration(days: 5, hours: -11)),
          priority: NotificationPriority.p2),
      quote(
          'demo-ntf-05',
          'QUOTE.REJECTED',
          13,
          DemoSeed.depots[10].name,
          'Quotation # rejected',
          'Over credit limit',
          today.subtract(const Duration(days: 8, hours: -11)),
          state: NotificationState.read),
      NotificationMessage(
        id: 'demo-ntf-06',
        eventCode: 'ORDER.CREDIT_HOLD',
        category: NotificationCategory.finance,
        priority: NotificationPriority.p2,
        title: 'Depot on credit hold',
        body: '${DemoSeed.depots[10].name} exceeded its credit limit.',
        deepLink: 'app://depots/${DemoSeed.depots[10].id}',
        data: {'entity_type': 'depot', 'entity_id': DemoSeed.depots[10].id},
        state: NotificationState.resolvedElsewhere,
        createdAt: today.subtract(const Duration(days: 9)),
        deliveredAt: today.subtract(const Duration(days: 9)),
        readAt: today.subtract(const Duration(days: 9)),
      ),
      NotificationMessage(
        id: 'demo-ntf-07',
        eventCode: 'KPI.DAILY_DIGEST',
        category: NotificationCategory.kpi,
        priority: NotificationPriority.p4,
        title: 'Yesterday: 5 of 6 stops completed',
        body: 'One stop was not visited. Tap for the breakdown.',
        deepLink: 'app://dashboard?period=yesterday',
        data: const {'entity_type': 'dashboard'},
        state: NotificationState.read,
        createdAt: today.subtract(const Duration(hours: 6)),
        deliveredAt: today.subtract(const Duration(hours: 6)),
        readAt: today.subtract(const Duration(hours: 5)),
      ),
      NotificationMessage(
        id: 'demo-ntf-08',
        eventCode: 'ANNOUNCE.PROMOTION',
        category: NotificationCategory.announce,
        priority: NotificationPriority.p3,
        title: 'Palm Roofing free goods this week',
        body: 'Buy 300 M of Palm profile, get 15 M free. Ends in 6 days.',
        data: const {'entity_type': 'promotion', 'entity_id': 'fg-palm'},
        state: NotificationState.unread,
        createdAt: today.subtract(const Duration(days: 1, hours: -8)),
        deliveredAt: today.subtract(const Duration(days: 1, hours: -8)),
      ),
    ];
  }

  /// The seven locked categories, plus the three the rep may mute — so a
  /// reviewer sees a disabled toggle with an explanation beside a working one.
  static const NotificationPreferences preferences = NotificationPreferences(
    quietHoursStart: '20:00:00',
    quietHoursEnd: '07:00:00',
    quietDays: [],
    digestTime: '18:00:00',
    language: 'km-KH',
    categories: [
      NotificationCategoryPreference(
          category: 'ASSIGNMENT',
          displayName: 'Assignments & Schedule',
          isEnabled: true,
          pushEnabled: true,
          isLocked: true),
      NotificationCategoryPreference(
          category: 'QUOTE',
          displayName: 'Quotations',
          isEnabled: true,
          pushEnabled: true,
          isLocked: true),
      NotificationCategoryPreference(
          category: 'ORDER',
          displayName: 'Orders',
          isEnabled: true,
          pushEnabled: true,
          isLocked: true),
      NotificationCategoryPreference(
          category: 'FINANCE',
          displayName: 'Finance & Credit',
          isEnabled: true,
          pushEnabled: true,
          isLocked: true),
      NotificationCategoryPreference(
          category: 'APPROVAL',
          displayName: 'Approvals',
          isEnabled: true,
          pushEnabled: true,
          isLocked: true),
      NotificationCategoryPreference(
          category: 'SYSTEM',
          displayName: 'System',
          isEnabled: true,
          pushEnabled: true,
          isLocked: true),
      NotificationCategoryPreference(
          category: 'SECURITY',
          displayName: 'Security',
          isEnabled: true,
          pushEnabled: true,
          isLocked: true),
      NotificationCategoryPreference(
          category: 'KPI',
          displayName: 'Performance & KPI',
          isEnabled: true,
          pushEnabled: false,
          isLocked: false),
      NotificationCategoryPreference(
          category: 'ACCOUNT',
          displayName: 'Account',
          isEnabled: true,
          pushEnabled: true,
          isLocked: false),
      NotificationCategoryPreference(
          category: 'ANNOUNCE',
          displayName: 'Announcements',
          isEnabled: true,
          pushEnabled: true,
          isLocked: false),
    ],
  );
}
