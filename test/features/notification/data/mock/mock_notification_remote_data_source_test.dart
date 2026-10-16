import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/demo/demo_network.dart';
import 'package:steelforce/core/demo/demo_seed.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/notifications/notification_deep_link.dart';
import 'package:steelforce/features/notification/data/mock/demo_notification_fixtures.dart';
import 'package:steelforce/features/notification/data/remote/mock_notification_remote_data_source.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';
import 'package:steelforce/features/order/data/mock/demo_material_book.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_remote_data_source.dart';
import 'package:steelforce/features/order/data/mock/demo_quotation_store.dart';

Matcher _apiError(String code, [int? status]) => throwsA(isA<ApiException>()
    .having((e) => e.code, 'code', code)
    .having((e) => e.statusCode, 'statusCode', status));

PushRegistration _registration() => PushRegistration(
      deviceId: 'device-1',
      pushToken: 'token',
      platform: PushPlatform.android,
      pushPermissionGranted: true,
      latitude: DemoSeed.depots.first.latitude,
      longitude: DemoSeed.depots.first.longitude,
      locationAccuracyMeters: 12,
      locationCapturedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late DemoNetwork network;
  late MockNotificationRemoteDataSource source;

  setUp(() {
    network = DemoNetwork();
    source = MockNotificationRemoteDataSource(network: network);
  });

  test('the default constructor still works without a demo network', () async {
    final page = await MockNotificationRemoteDataSource().fetchPage();
    expect(page.items, isNotEmpty);
  });

  test('the inbox parses, with unread, acknowledgement and history rows',
      () async {
    final page = await source.fetchPage();
    expect(page.items, hasLength(8));
    expect(page.hasMore, isFalse);
    expect(page.syncTimestamp, isNotNull);
    expect(page.items.where((i) => i.requiresAck), hasLength(2));
    expect(page.items.map((i) => i.state),
        contains(NotificationState.resolvedElsewhere));

    final counts = await source.fetchCounts();
    expect(counts.unread,
        page.items.where((i) => i.state == NotificationState.unread).length);
  });

  test('every deep link resolves to a known destination', () async {
    final page = await source.fetchPage();
    for (final item in page.items.where((i) => i.deepLink != null)) {
      expect(NotificationDeepLink.isRoutable(item.deepLink), isTrue,
          reason: item.deepLink);
    }
  });

  test('items name the shared demo route, depots and seeded quotations',
      () async {
    final quotations = DemoQuotationRemoteDataSource(
        network, DemoQuotationStore(DemoMaterialBook()));
    final page = await source.fetchPage();
    for (final item in page.items) {
      final type = item.data['entity_type'];
      final id = item.data['entity_id'];
      if (type == 'route') expect(id, DemoSeed.todayRouteId);
      if (type == 'depot') expect(DemoSeed.depotById('$id'), isNotNull);
      if (type != 'quotation') continue;
      final doc = await quotations.fetchQuotationById('$id');
      expect(item.title, contains(doc.number));
      expect(item.body, contains(doc.depotName));
    }
    final ids = page.items.map((i) => i.data['entity_id']).toSet();
    expect(ids, contains(DemoNotificationFixtures.quotationId(7)));
  });

  test('read, read-all and dismiss persist within the session', () async {
    final unread = (await source.fetchPage())
        .items
        .where((i) => i.state == NotificationState.unread && !i.requiresAck)
        .first;
    await source.markRead(unread.id);
    var item =
        (await source.fetchPage()).items.firstWhere((i) => i.id == unread.id);
    expect(item.state, NotificationState.read);

    await source.dismiss(unread.id);
    item =
        (await source.fetchPage()).items.firstWhere((i) => i.id == unread.id);
    expect(item.state, NotificationState.dismissed);

    await source.markAllRead();
    expect((await source.fetchCounts()).unread, 0);
  });

  test('an item requiring acknowledgement cannot be dismissed', () async {
    final pinned = (await source.fetchPage()).items.firstWhere(
          (i) => i.requiresAck,
        );
    expect(source.dismiss(pinned.id),
        _apiError('Notification.AlreadyResolved', 409));
  });

  test('device registration and preferences work in memory', () async {
    final result = await source.registerDevice(_registration());
    expect(result.isActive, isTrue);
    await source.deregisterDevice('device-1');
    expect(source.deregisterDevice('device-1'),
        _apiError('Notification.DeviceNotFound', 404));

    final prefs = await source.fetchPreferences();
    final muted = NotificationPreferences(
      quietHoursStart: prefs.quietHoursStart,
      quietHoursEnd: prefs.quietHoursEnd,
      quietDays: prefs.quietDays,
      digestTime: prefs.digestTime,
      language: 'en-US',
      categories: prefs.categories,
    );
    await source.savePreferences(muted);
    expect((await source.fetchPreferences()).language, 'en-US');
  });

  test('offline: every call fails as a network error', () {
    network.setOnline(false);
    final offline = _apiError(ApiErrorCodes.network);
    expect(source.fetchPage(), offline);
    expect(source.fetchCounts(), offline);
    expect(source.markRead('demo-ntf-03'), offline);
    expect(source.markAllRead(), offline);
    expect(source.recordAction('demo-ntf-01'), offline);
    expect(source.dismiss('demo-ntf-03'), offline);
    expect(source.invokeAction(endpoint: '/x', method: 'POST'), offline);
    expect(source.registerDevice(_registration()), offline);
    expect(source.deregisterDevice('device-1'), offline);
    expect(source.fetchPreferences(), offline);
  });
}
