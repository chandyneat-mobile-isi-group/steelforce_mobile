import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/utils/mock_latency.dart';
import 'package:steelforce/features/notification/data/mock/demo_notification_fixtures.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// Bundled notification fixtures, for demos and for widget tests that must not
/// depend on a reachable gateway.
///
/// TODO(release-gate): demo-only, selected only when `DataSourceMode.useMocks`.
///
/// `docs/feature/notification/README.md` §18 records that the business events
/// (`ROUTE.ASSIGNED`, `QUOTE.APPROVED`, …) are **Phase 2+** and nothing raises
/// them yet, so against a live backend the inbox is correctly, permanently
/// empty — which makes the whole surface impossible to review. The fixtures
/// live in [DemoNotificationFixtures].
///
/// Given a [DemoNetwork], every call first spends one simulated round trip on
/// it, so a demo switched offline fails like a dropped connection: reads keep
/// the local mirror, and read/dismiss/action writes queue in the outbox and
/// drain when the demo comes back online. Without one it only waits
/// [MockLatency], as before.
class MockNotificationRemoteDataSource implements NotificationRemoteDataSource {
  MockNotificationRemoteDataSource({DemoNetwork? network, DateTime? now})
      : _network = network,
        _items = DemoNotificationFixtures.inbox(now ?? DateTime.now());

  final DemoNetwork? _network;

  /// Mutated in place so a marked-read fixture stays read across a re-sync
  /// within one session — otherwise every pull-to-refresh in a demo undoes what
  /// the reviewer just did, which reads as a bug in the real code.
  final List<NotificationMessage> _items;

  NotificationPreferences _preferences = DemoNotificationFixtures.preferences;

  /// Device ids registered for push, as the device registry would hold them.
  final Set<String> _devices = {};

  Future<void> _roundTrip() => _network?.roundTrip() ?? MockLatency.tick();

  @override
  Future<NotificationPage> fetchPage({
    DateTime? since,
    int pageNumber = 1,
    int pageSize = 100,
  }) async {
    await _roundTrip();
    // Deliberately ignores `since` and always answers one full page. The
    // catch-up loop's paging and cursor handling is exercised against the real
    // API and by its own tests; faking a delta here would only test the fake.
    // The stamp is "server" time — in a demo the device is the server.
    return NotificationPage(
      items: pageNumber == 1 ? List.of(_items) : const [],
      hasMore: false,
      syncTimestamp: DateTime.now().toUtc(),
    );
  }

  @override
  Future<NotificationCounts> fetchCounts() async {
    await _roundTrip();
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
      syncTimestamp: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> markRead(String id) async {
    await _roundTrip();
    _replace(id, (item) => item.markedRead(DateTime.now().toUtc()));
  }

  @override
  Future<int> markAllRead({String? categoryCode}) async {
    await _roundTrip();
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
    await _roundTrip();
    _replace(id, (item) => item.markedActioned(DateTime.now().toUtc()));
  }

  /// `409` for an item that requires acknowledgement, as the server answers:
  /// it may be actioned, never swiped away.
  @override
  Future<void> dismiss(String id) async {
    await _roundTrip();
    final item = _find(id);
    if (item == null) {
      throw const ApiException(
          ApiError(code: 'Notification.NotFound', statusCode: 404));
    }
    if (item.requiresAck) {
      throw const ApiException(
          ApiError(code: 'Notification.AlreadyResolved', statusCode: 409));
    }
    _replace(id, (item) => item.markedDismissed(DateTime.now().toUtc()));
  }

  @override
  Future<void> invokeAction({
    required String endpoint,
    required String method,
  }) =>
      _roundTrip();

  @override
  Future<PushRegistrationResult> registerDevice(
      PushRegistration registration) async {
    await _roundTrip();
    _devices.add(registration.deviceId);
    return PushRegistrationResult(
      id: 'demo-registration-${registration.deviceId}',
      deviceId: registration.deviceId,
      isActive: true,
      pushPermissionGranted: registration.pushPermissionGranted,
      lastSeenAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> deregisterDevice(String deviceId) async {
    await _roundTrip();
    if (!_devices.remove(deviceId)) {
      throw const ApiException(
          ApiError(code: 'Notification.DeviceNotFound', statusCode: 404));
    }
  }

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    await _roundTrip();
    return _preferences;
  }

  @override
  Future<NotificationPreferences> savePreferences(
      NotificationPreferences preferences) async {
    await _roundTrip();
    final locked = {
      for (final c in _preferences.categories)
        if (c.isLocked) c.category,
    };
    if (preferences.categories
        .any((c) => locked.contains(c.category) && !c.isEnabled)) {
      throw const ApiException(
          ApiError(code: 'Notification.CategoryNotMutable', statusCode: 422));
    }
    _preferences = preferences;
    return preferences;
  }

  NotificationMessage? _find(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

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
}
