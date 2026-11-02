import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/domain/entities/notification_action.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// Bundled notification fixtures, for demos and for widget tests that must not
/// depend on a reachable gateway.
///
/// Selected by `DataSourceMode` (`--dart-define=USE_MOCK_DATA=true`); live is
/// the default. Every other feature in this app ships a `Mock*RemoteDataSource`
/// beside its real one, and the notification feature is where fixtures matter
/// most in practice: `docs/feature/notification/README.md` §18 records that the
/// business events (`ROUTE.ASSIGNED`, `QUOTE.APPROVED`, …) are **Phase 2+** and
/// nothing raises them yet. Against a live backend today the inbox is correctly,
/// permanently empty — which makes the whole surface impossible to review.
///
/// The fixtures deliberately cover the cases that are easy to get wrong:
/// an item requiring acknowledgement (pinned, not swipeable), a P4 that would
/// never arrive as a push, an `api_call` action beside a `deeplink` one, and a
/// `resolved_elsewhere` row that belongs in history with an explanation.
class MockNotificationRemoteDataSource implements NotificationRemoteDataSource {
  MockNotificationRemoteDataSource();

  /// Mutated in place so a marked-read fixture stays read across a re-sync
  /// within one session — otherwise every pull-to-refresh in a demo undoes what
  /// the reviewer just did, which reads as a bug in the real code.
  late final List<NotificationMessage> _items = _seed();

  @override
  Future<NotificationPage> fetchPage({
    String? cursor,
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    await MockLatency.tick();
    // One page, no cursor: the keyset paging is exercised against the real API
    // and by its own tests; faking it here would only test the fake.
    if (cursor != null) return const NotificationPage(items: []);
    return NotificationPage(
      items: [
        for (final item in _items)
          if (!unreadOnly || item.isUnread) item,
      ],
    );
  }

  @override
  Future<NotificationCounts> fetchCounts() async {
    await MockLatency.tick();
    final unread =
        _items.where((i) => i.state == NotificationState.unread).length;
    final outstanding = _items.where((i) => i.isOutstandingAction).length;
    final byCategory = <NotificationCategory, int>{};
    for (final item in _items) {
      if (!item.state.isCurrent) continue;
      byCategory[item.category] = (byCategory[item.category] ?? 0) + 1;
    }
    return NotificationCounts(
      unread: unread,
      actionRequired: outstanding,
      byCategory: byCategory,
      syncTimestamp: DateTime.utc(2026, 8, 25, 8, 12, 4),
    );
  }

  @override
  Future<void> markRead(String id) async {
    await MockLatency.tick();
    _replace(id, (item) => item.markedRead(DateTime.now().toUtc()));
  }

  @override
  Future<int> markAllRead({String? categoryCode}) async {
    await MockLatency.tick();
    var cleared = 0;
    final at = DateTime.now().toUtc();
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.state != NotificationState.unread) continue;
      if (categoryCode != null && item.category.code != categoryCode) continue;
      _items[i] = item.markedRead(at);
      cleared++;
    }
    return cleared;
  }

  @override
  Future<void> recordAction(
    String id, {
    String? actionId,
    DateTime? occurredAt,
  }) async {
    await MockLatency.tick();
    _replace(id, (item) => item.markedActioned(DateTime.now().toUtc()));
  }

  @override
  Future<void> dismiss(String id) async {
    await MockLatency.tick();
    _replace(id, (item) => item.markedDismissed(DateTime.now().toUtc()));
  }

  @override
  Future<void> invokeAction({
    required String endpoint,
    required String method,
  }) async {
    await MockLatency.tick();
  }

  @override
  Future<PushRegistrationResult> registerDevice(
      PushRegistration registration) async {
    await MockLatency.tick();
    return PushRegistrationResult(
      id: 'mock-registration',
      deviceId: registration.deviceId,
      isActive: true,
      pushPermissionGranted: registration.pushPermissionGranted,
      lastSeenAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> deregisterDevice(String deviceId) async {
    await MockLatency.tick();
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    await MockLatency.tick();
    return _preferences;
  }

  @override
  Future<NotificationPreferences> savePreferences(
      NotificationPreferences preferences) async {
    await MockLatency.tick();
    _preferences = preferences;
    return preferences;
  }

  /// The seven locked categories of §13, plus the three the rep may mute — so a
  /// reviewer can see both a disabled toggle with an explanation and a working
  /// one on the same screen.
  NotificationPreferences _preferences = const NotificationPreferences(
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

  void _replace(
    String id,
    NotificationMessage Function(NotificationMessage item) transform,
  ) {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].id != id) continue;
      _items[i] = transform(_items[i]);
      return;
    }
  }

  /// Timestamps are anchored to a fixed instant rather than `DateTime.now()`:
  /// a relative fixture set drifts as the demo device's clock moves and the
  /// "3 days ago" grouping silently changes between two runs.
  static List<NotificationMessage> _seed() {
    final base = DateTime.utc(2026, 8, 25, 8, 12, 4);

    return [
      // Requires acknowledgement: pinned, not swipeable, and it stays
      // outstanding after being read (§5.4, §8.3).
      NotificationMessage(
        id: '0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5b',
        eventCode: 'ROUTE.ASSIGNED',
        category: NotificationCategory.assignment,
        priority: NotificationPriority.p2,
        title: 'New route assigned — Wed, 26 Aug',
        body: 'North Phnom Penh R3: 12 stops from 08:00. '
            'Tap to review and confirm.',
        deepLink: 'app://routes/0198f2b0-1111-7000-8000-000000000001',
        requiresAck: true,
        groupKey: 'Assignment:0198f2b0-1111-7000-8000-000000000001',
        badge: 3,
        actions: [
          const NotificationAction(
            id: 'view',
            label: 'View Route',
            type: NotificationActionType.deeplink,
          ),
          const NotificationAction(
            id: 'ack',
            label: 'Acknowledge',
            type: NotificationActionType.apiCall,
            endpoint:
                '/api/v1/routes/0198f2b0-1111-7000-8000-000000000001/acknowledge',
            method: 'POST',
          ),
        ],
        data: const {
          'entity_type': 'route',
          'entity_id': '0198f2b0-1111-7000-8000-000000000001',
          'route_date': '2026-08-26',
          // A string, not a number — §9.1.
          'stop_count': '12',
        },
        state: NotificationState.unread,
        createdAt: base,
        deliveredAt: base,
      ),

      // P1: bypasses quiet hours and the rep's own opt-out.
      NotificationMessage(
        id: '0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5c',
        eventCode: 'ROUTE.CANCELLED',
        category: NotificationCategory.assignment,
        priority: NotificationPriority.p1,
        title: 'Route cancelled — today',
        body: 'South Phnom Penh R1 was cancelled. Do not travel.',
        deepLink: 'app://today',
        requiresAck: true,
        actions: [
          const NotificationAction(
            id: 'ack',
            label: 'Acknowledge',
            type: NotificationActionType.apiCall,
            endpoint: '/api/v1/routes/0198f2b0-2222/acknowledge',
            method: 'POST',
          ),
        ],
        data: const {'entity_type': 'route', 'entity_id': '0198f2b0-2222'},
        state: NotificationState.unread,
        createdAt: base.subtract(const Duration(hours: 2)),
        deliveredAt: base.subtract(const Duration(hours: 2)),
      ),

      // A destructive action, which §12 requires be confirmed before firing.
      NotificationMessage(
        id: '0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5d',
        eventCode: 'QUOTE.PENDING_APPROVAL',
        category: NotificationCategory.approval,
        priority: NotificationPriority.p2,
        title: 'Quotation awaiting your approval',
        body: 'Q-2026-0412 for Sok Heng Hardware needs a decision.',
        deepLink: 'app://quotations/0198f2b0-3333',
        requiresAck: true,
        actions: [
          const NotificationAction(
            id: 'approve',
            label: 'Approve',
            type: NotificationActionType.apiCall,
            endpoint: '/api/v1/quotations/0198f2b0-3333/approve',
            method: 'POST',
          ),
          const NotificationAction(
            id: 'reject',
            label: 'Reject',
            type: NotificationActionType.apiCall,
            endpoint: '/api/v1/quotations/0198f2b0-3333/reject',
            method: 'POST',
            destructive: true,
          ),
        ],
        data: const {
          'entity_type': 'quotation',
          'entity_id': '0198f2b0-3333',
        },
        state: NotificationState.read,
        createdAt: base.subtract(const Duration(days: 1)),
        deliveredAt: base.subtract(const Duration(days: 1)),
        readAt: base.subtract(const Duration(hours: 20)),
      ),

      // P4 — inbox only, never pushed. Present precisely so a reviewer notices
      // it appears without any push ever arriving.
      NotificationMessage(
        id: '0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5e',
        eventCode: 'KPI.DAILY_DIGEST',
        category: NotificationCategory.kpi,
        priority: NotificationPriority.p4,
        title: 'Yesterday: 9 of 12 stops completed',
        body: 'Three stops were not visited. Tap for the breakdown.',
        deepLink: 'app://dashboard?period=yesterday',
        data: const {'entity_type': 'dashboard'},
        state: NotificationState.read,
        createdAt: base.subtract(const Duration(days: 1, hours: 14)),
        deliveredAt: base.subtract(const Duration(days: 1, hours: 14)),
        readAt: base.subtract(const Duration(days: 1, hours: 13)),
      ),

      // History: somebody else decided first. Greyed, with an explanation —
      // never silently absent (§5.1).
      NotificationMessage(
        id: '0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5f',
        eventCode: 'ORDER.CREDIT_HOLD',
        category: NotificationCategory.finance,
        priority: NotificationPriority.p2,
        title: 'Order on credit hold',
        body: 'SO-2026-0331 exceeded the depot credit limit.',
        deepLink: 'app://orders/0198f2b0-4444?tab=credit',
        data: const {'entity_type': 'order', 'entity_id': '0198f2b0-4444'},
        state: NotificationState.resolvedElsewhere,
        createdAt: base.subtract(const Duration(days: 3)),
        deliveredAt: base.subtract(const Duration(days: 3)),
        readAt: base.subtract(const Duration(days: 3)),
      ),
    ];
  }
}
