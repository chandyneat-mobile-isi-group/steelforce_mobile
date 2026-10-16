import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/notification_category.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_message.dart';
import 'package:steelforce/features/notification/domain/entities/notification_priority.dart';
import 'package:steelforce/features/notification/domain/entities/notification_query.dart';
import 'package:steelforce/features/notification/domain/entities/notification_state.dart';
import 'package:steelforce/features/notification/domain/entities/notification_sync_result.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';
import 'package:steelforce/features/notification/domain/repositories/notification_inbox_repository.dart';
import 'package:steelforce/features/notification/domain/repositories/push_device_repository.dart';
import 'package:steelforce/features/notification/domain/usecases/inbox_usecases.dart';
import 'package:steelforce/features/notification/domain/usecases/push_device_usecases.dart';
import 'package:steelforce/features/notification/presentation/bloc/notification_inbox_cubit.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';
import 'package:steelforce/features/notification/presentation/screen/notifications_sheet.dart';
import 'package:steelforce/features/notification/presentation/widgets/notification_inbox_view.dart';

/// An in-memory inbox, so the view can be pumped without a database, DI, or a
/// gateway.
class _FakeInboxRepository implements NotificationInboxRepository {
  _FakeInboxRepository(this._items);

  final List<NotificationMessage> _items;
  final _controller = StreamController<List<NotificationMessage>>.broadcast();

  /// Filters exactly as the DAO does, so the tabs and chips are exercised
  /// against the same rules production uses rather than against a stub that
  /// always returns everything.
  List<NotificationMessage> _slice(NotificationQuery query) {
    final states = query.states;
    return _items.where((item) {
      if (!states.contains(item.state)) return false;
      if (query.requiresAckOnly && !item.requiresAck) return false;
      if (query.category != null && item.category != query.category) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Stream<List<NotificationMessage>> watch(NotificationQuery query) async* {
    yield _slice(query);
    yield* _controller.stream.map((_) => _slice(query));
  }

  @override
  Future<NotificationMessage?> findById(String id) async => null;

  @override
  Stream<NotificationCounts> watchCounts() =>
      Stream.value(const NotificationCounts());

  @override
  ResultFuture<NotificationSyncResult> catchUp({bool full = false}) async =>
      const Success(NotificationSyncResult());

  @override
  ResultFuture<NotificationCounts> refreshCounts() async =>
      const Success(NotificationCounts.empty);

  @override
  ResultFuture<void> markRead(String notificationId) async {
    final index = _items.indexWhere((i) => i.id == notificationId);
    if (index >= 0) {
      _items[index] = _items[index].markedRead(DateTime.utc(2026, 8, 25));
      _controller.add(_items);
    }
    return const Success(null);
  }

  @override
  ResultFuture<int> markAllRead({String? categoryCode}) async =>
      const Success(0);

  @override
  ResultFuture<void> recordAction(String notificationId,
          {String? actionId}) async =>
      const Success(null);

  @override
  ResultFuture<void> dismiss(String notificationId) async =>
      const Success(null);

  @override
  ResultFuture<void> upsertFromPush(Map<String, String> data,
          {String? title, String? body}) async =>
      const Success(null);

  @override
  ResultFuture<List<String>> drainActionQueue() async => const Success([]);

  @override
  Future<void> clear() async {}
}

/// Reports the permission as already granted, so neither the §14 explainer nor
/// the declined banner is on screen for the list assertions below. Both have
/// their own coverage in `push_permission_cubit_test.dart`.
class _GrantedPushDevices implements PushDeviceRepository {
  @override
  Future<PushPermissionStatus> permissionStatus() async =>
      PushPermissionStatus.granted;

  @override
  ResultFuture<PushPermissionStatus> requestPermission() async =>
      const Success(PushPermissionStatus.granted);

  @override
  ResultFuture<PushRegistrationResult?> register() async => const Success(null);

  @override
  ResultFuture<void> deregister() async => const Success(null);

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();
}

NotificationMessage _message(
  String id, {
  NotificationCategory category = NotificationCategory.finance,
  NotificationState state = NotificationState.unread,
  bool requiresAck = false,
  String title = 'Credit approved',
}) =>
    NotificationMessage(
      id: id,
      eventCode: 'FINANCE.CREDIT_APPROVED',
      category: category,
      priority: NotificationPriority.p2,
      title: title,
      body: 'The credit limit for ISI Steel Co. was approved.',
      requiresAck: requiresAck,
      state: state,
      createdAt: DateTime.utc(2026, 8, 12),
    );

void main() {
  // Localization is loaded from setUp/setUpAll, never from inside a
  // `testWidgets` body. `LocalizationService.load` awaits
  // `rootBundle.loadString` — real I/O, with no early-return even when the
  // requested language is already current — and a `testWidgets` body runs
  // against a fake clock that never lets that future complete. Awaiting it
  // there does not fail fast; it hangs until the 10-minute test timeout, which
  // is exactly how this file was failing in CI.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
    // `NotificationTile` formats dates older than a week with
    // `DateFormat.MMMd(<locale>)`, and the explicit-locale constructors throw
    // `LocaleDataException` without this. `AppBootstrapService` calls it for the
    // real app; a widget test has to do the same rather than have the tile
    // defend itself, which would only hide a genuinely broken boot.
    await initializeDateFormatting();
    // `PushPermissionCubit` reads and writes the explainer timestamp through
    // Hive. An in-memory box keeps the widget tests off disk.
    Hive.init('.dart_tool/test_hive_notifications');
  });

  const phone = Size(390, 844);
  const tablet = Size(834, 1112); // iPad Air portrait — `medium`

  late Box<dynamic> box;

  setUp(() async {
    box = await Hive.openBox<dynamic>(
      'notif_test_${DateTime.now().microsecondsSinceEpoch}',
      bytes: Uint8List(0),
    );
  });

  tearDown(() async => box.close());

  Future<void> pumpAt(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: Breakpoints.fromWidth(size.width).isCompact ? phone : size,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: child,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Opens the real sheet, so the test exercises `showNotificationsSheet`'s
  /// chrome (via `showAppBottomSheet`) rather than the private widget alone.
  ///
  /// Guest only: the signed-in branch resolves its cubits from `GetIt`, and the
  /// list assertions below pump [NotificationInboxView] with locally-built ones
  /// instead of standing up the whole container.
  Future<void> openGuestSheet(WidgetTester tester, {required Size size}) async {
    // Tear the previous tree down first. A test that opens the sheet twice —
    // once per viewport — otherwise leaves the first modal route on screen
    // covering the trigger button, and the second `tap` hit-tests the sheet
    // instead. It only surfaces as a `warnIfMissed` warning, so the assertion
    // still passes while measuring the wrong sheet.
    await tester.pumpWidget(const SizedBox.shrink());

    await pumpAt(
      tester,
      size,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showNotificationsSheet(
                context: context,
                isGuest: true,
                onLogin: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // Explicit pumps rather than pumpAndSettle: the modal route keeps a ticker
    // alive long enough that settling is unreliable here, and a fixed advance
    // past the sheet's entrance animation is all this test needs.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Pumps the inbox body with a scripted set of notifications.
  /// Returns the inbox cubit.
  ///
  /// The Inbox / Action needed / History tabs were removed from the view, so
  /// scope can no longer be selected by tapping. It is still a real feature of
  /// the cubit and the query, and the content rules below (§5.4 pinning,
  /// history's resolution note) are worth keeping under test — so the tests
  /// drive scope directly instead of losing the coverage with the tabs.
  Future<NotificationInboxCubit> openInbox(
    WidgetTester tester, {
    required Size size,
    required List<NotificationMessage> items,
  }) async {
    final repository = _FakeInboxRepository(List.of(items));
    final inbox = NotificationInboxCubit(
      watchNotifications: WatchNotifications(repository),
      syncNotifications: SyncNotifications(repository),
      markRead: MarkNotificationRead(repository),
      markAllRead: MarkAllNotificationsRead(repository),
      recordAction: RecordNotificationAction(repository),
      dismissNotification: DismissNotification(repository),
      invokeAction: ({required endpoint, required method}) async {},
    )..start();
    final permission = PushPermissionCubit(
      getStatus: GetPushPermissionStatus(_GrantedPushDevices()),
      requestPermission: RequestPushPermission(_GrantedPushDevices()),
      cache: LocalCache(box),
    );
    addTearDown(inbox.close);
    addTearDown(permission.close);

    await pumpAt(
      tester,
      size,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: inbox),
          BlocProvider.value(value: permission),
        ],
        child: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: NotificationInboxView(),
          ),
        ),
      ),
    );
    return inbox;
  }

  double fontSizeOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style!.fontSize!;

  group('guest state', () {
    group('in Khmer', () {
      setUp(() => LocalizationService.instance.load('km'));
      tearDown(() => LocalizationService.instance.load('en'));

      testWidgets('renders translated Khmer copy, not raw keys',
          (tester) async {
        // The regression this pins: the guest branch read the `notification.*`
        // (singular) namespace, which existed only in en.json — so in Khmer
        // every string here rendered as its own key. `translate()` returns the
        // key on a miss, so nothing failed loudly.
        await openGuestSheet(tester, size: phone);

        expect(find.text('notifications.welcome_title'), findsNothing);
        expect(find.text('notifications.welcome_body'), findsNothing);
        expect(find.text('notifications.login'), findsNothing);
        expect(find.text('សូមស្វាគមន៍!'), findsOneWidget);
      });
    });

    testWidgets('type is larger on a tablet than on a phone', (tester) async {
      await openGuestSheet(tester, size: phone);
      final phoneTitle = fontSizeOf(tester, 'Welcome!');

      await openGuestSheet(tester, size: tablet);
      expect(fontSizeOf(tester, 'Welcome!'), greaterThan(phoneTitle));
    });
  });

  group('inbox', () {
    final items = [
      _message('1'),
      _message('2', category: NotificationCategory.assignment),
    ];

    testWidgets('filters and rows render without overflow', (tester) async {
      await openInbox(tester, size: phone, items: items);

      // The Inbox / Action needed / History tabs were removed; the filter row
      // is now the only chrome above the list.
      expect(find.text('Inbox'), findsNothing);
      expect(find.text('History'), findsNothing);

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Credit approved'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('row type scales up on a tablet', (tester) async {
      await openInbox(tester, size: phone, items: items);
      final phoneRowTitle = tester
          .widgetList<Text>(find.text('Credit approved'))
          .first
          .style!
          .fontSize!;

      await openInbox(tester, size: tablet, items: items);
      final tabletRowTitle = tester
          .widgetList<Text>(find.text('Credit approved'))
          .first
          .style!
          .fontSize!;

      expect(tabletRowTitle, greaterThan(phoneRowTitle));
    });

    testWidgets('an empty category filter shows translated copy',
        (tester) async {
      await openInbox(tester, size: phone, items: [_message('1')]);

      // The chips are now two buckets rather than one per category, and both
      // fit on screen — no scrolling needed to build them. The fixture's
      // notification is `finance`, which belongs to Admin, so filtering to
      // System must empty the list.
      await tester.tap(find.text('System'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No new notifications'), findsOneWidget);
      expect(find.text('notifications.empty'), findsNothing);
    });

    testWidgets('the Action needed tab shows only outstanding items',
        (tester) async {
      // §5.4: `requires_ack` items are the tab's whole content, and §8.3 means a
      // *read* one still belongs here.
      final cubit = await openInbox(tester, size: phone, items: [
        _message('1', title: 'Routine update'),
        _message('2',
            title: 'Acknowledge route',
            requiresAck: true,
            state: NotificationState.read),
      ]);

      cubit.setScope(NotificationScope.actionNeeded);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Acknowledge route'), findsOneWidget);
      expect(find.text('Routine update'), findsNothing);
    });

    testWidgets('an empty Action needed tab reads as good news',
        (tester) async {
      final cubit =
          await openInbox(tester, size: phone, items: [_message('1')]);

      cubit.setScope(NotificationScope.actionNeeded);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Nothing needs your acknowledgement right now.'),
        findsOneWidget,
      );
    });

    testWidgets('history shows a resolved item with its explanation',
        (tester) async {
      // §5.1: nothing is ever deleted, and a greyed row without a reason reads
      // as a bug rather than as information.
      final cubit = await openInbox(tester, size: phone, items: [
        _message('1',
            title: 'Order on credit hold',
            state: NotificationState.resolvedElsewhere),
      ]);

      cubit.setScope(NotificationScope.history);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Order on credit hold'), findsOneWidget);
      expect(find.text('Already actioned by someone else.'), findsOneWidget);
    });
  });
}
