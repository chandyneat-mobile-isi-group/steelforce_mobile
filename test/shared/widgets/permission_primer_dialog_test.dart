import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/localization/localization_services.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/core/permissions/location_permission_service.dart';
import 'package:steelforce/core/permissions/presentation/app_permissions_cubit.dart';
import 'package:steelforce/core/responsive/breakpoints.dart';
import 'package:steelforce/core/theme/app_theme.dart';
import 'package:steelforce/core/theme/app_typography.dart';
import 'package:steelforce/shared/widgets/permission/permission_primer_dialog.dart';

class _FakeMessaging implements PushMessagingService {
  _FakeMessaging(this.authorisation, {this.promptResult});

  PushAuthorization authorisation;
  final PushAuthorization? promptResult;

  @override
  bool get isSupported => authorisation != PushAuthorization.unsupported;

  @override
  Future<PushAuthorization> authorization() async => authorisation;

  @override
  Future<PushAuthorization> requestPermission() async =>
      authorisation = promptResult ?? authorisation;

  @override
  Future<void> initialize() async {}
  @override
  Future<String?> token() async => 'token';
  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();
  @override
  Stream<PushMessage> get onForegroundMessage =>
      const Stream<PushMessage>.empty();
  @override
  Stream<PushMessage> get onMessageOpened => const Stream<PushMessage>.empty();
  @override
  Future<PushMessage?> initialMessage() async => null;
  @override
  Future<void> suppressForegroundAlerts() async {}
  @override
  Future<void> deleteToken() async {}
}

class _FakeLocation implements LocationPermissionService {
  _FakeLocation(this.current, {this.promptResult});

  LocationPermissionStatus current;
  final LocationPermissionStatus? promptResult;
  int openSettingsCount = 0;

  @override
  Future<LocationPermissionStatus> status() async => current;

  @override
  Future<LocationPermissionStatus> request() async =>
      current = promptResult ?? current;

  @override
  Future<bool> openSettings() async {
    openSettingsCount++;
    return true;
  }
}

void main() {
  // See `notifications_sheet_test.dart` for why the bundle is loaded from
  // setUpAll and never from inside a `testWidgets` body.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await LocalizationService.instance.load('en');
    Hive.init('.dart_tool/test_hive_primer_widget');
  });

  const phone = Size(390, 844);
  late Box<dynamic> box;

  setUp(() async {
    box = await Hive.openBox<dynamic>(
      'primer_${DateTime.now().microsecondsSinceEpoch}',
      bytes: Uint8List(0),
    );
  });

  tearDown(() async => box.close());

  AppPermissionsCubit buildCubit(
    _FakeMessaging messaging,
    _FakeLocation location,
  ) =>
      AppPermissionsCubit(
        messaging: messaging,
        location: location,
        cache: LocalCache(box),
        logger: const ConsoleAppLogger(verbose: false),
        registerPushDevice: () async {},
      );

  /// Opens the real dialog through `showPermissionPrimerDialog`, so the
  /// transition and barrier behaviour are exercised rather than the body alone.
  Future<void> open(
    WidgetTester tester,
    AppPermissionsCubit cubit, {
    Size size = phone,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await cubit.load();

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: Breakpoints.fromWidth(size.width).isCompact ? phone : size,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light(AppTypography.latinFontFamily),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPermissionPrimerDialog(
                      context: context, cubit: cubit),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // Fixed advances rather than pumpAndSettle: the dialog's staggered
    // entrance keeps a ticker alive long enough that settling is unreliable.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  testWidgets('renders a row per permission, with reasons', (tester) async {
    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.notDetermined),
      _FakeLocation(LocationPermissionStatus.notDetermined),
    );
    addTearDown(cubit.close);

    await open(tester, cubit);

    expect(find.text('Two quick permissions'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    // The *reason* is the whole point of priming — a bare permission name gives
    // the rep nothing to evaluate.
    expect(
      find.textContaining('Know the moment a route'),
      findsOneWidget,
    );
    expect(
      find.textContaining("Saves a shop's exact coordinates"),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no raw localisation keys leak through', (tester) async {
    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.notDetermined),
      _FakeLocation(LocationPermissionStatus.notDetermined),
    );
    addTearDown(cubit.close);

    await open(tester, cubit);

    // `translate()` returns the key on a miss rather than throwing, so a typo is
    // silent — this is the only thing that catches it.
    final leaked = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((s) => s.startsWith('permissions.'))
        .toList();
    expect(leaked, isEmpty, reason: 'unresolved keys: $leaked');
  });

  testWidgets('Enable grants both and closes the dialog', (tester) async {
    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.notDetermined,
          promptResult: PushAuthorization.authorized),
      _FakeLocation(LocationPermissionStatus.notDetermined,
          promptResult: LocationPermissionStatus.whileInUse),
    );
    addTearDown(cubit.close);

    await open(tester, cubit);
    await tester.tap(find.text('Enable both'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(cubit.state.notifications, PermissionOutcome.granted);
    expect(cubit.state.location, PermissionOutcome.granted);
    // Closed from the settled listener, so every exit path goes through one
    // place.
    expect(find.text('Two quick permissions'), findsNothing);
  });

  testWidgets('"Not now" closes without prompting', (tester) async {
    // §14 treats declining as a first-class answer, so the control must be
    // real and equally reachable — not a faint link.
    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.notDetermined),
      _FakeLocation(LocationPermissionStatus.notDetermined),
    );
    addTearDown(cubit.close);

    await open(tester, cubit);
    await tester.tap(find.text('Not now'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Two quick permissions'), findsNothing);
    expect(cubit.state.notifications, PermissionOutcome.pending);
  });

  testWidgets('a blocked permission offers Settings, not Enable',
      (tester) async {
    // The regression that matters: an "Enable" button here would fire a request
    // the OS refuses to show, and the rep would tap it to no visible effect.
    final location = _FakeLocation(LocationPermissionStatus.deniedForever);
    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.deniedPermanently),
      location,
    );
    addTearDown(cubit.close);

    await open(tester, cubit);

    expect(find.text('Open Settings'), findsOneWidget);
    expect(find.text('Enable both'), findsNothing);
    expect(find.textContaining('device Settings'), findsOneWidget);

    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(location.openSettingsCount, 1);
  });

  testWidgets('an unsupported permission is omitted entirely', (tester) async {
    // Web has no push transport. A "not supported" row teaches the rep nothing
    // and makes the dialog look broken.
    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.unsupported),
      _FakeLocation(LocationPermissionStatus.notDetermined),
    );
    addTearDown(cubit.close);

    await open(tester, cubit);

    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
  });

  testWidgets('tapping the barrier does not dismiss it', (tester) async {
    // A dismissal that is neither accept nor decline leaves the app unable to
    // tell whether to re-offer — and the dialog is capped at once every 14 days.
    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.notDetermined),
      _FakeLocation(LocationPermissionStatus.notDetermined),
    );
    addTearDown(cubit.close);

    await open(tester, cubit);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Two quick permissions'), findsOneWidget);
  });

  testWidgets('renders without overflow on a phone and a tablet',
      (tester) async {
    for (final size in [phone, const Size(834, 1112)]) {
      final cubit = buildCubit(
        _FakeMessaging(PushAuthorization.notDetermined),
        _FakeLocation(LocationPermissionStatus.notDetermined),
      );
      await open(tester, cubit, size: size);

      expect(tester.takeException(), isNull, reason: 'overflowed at $size');
      await cubit.close();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('honours reduce-motion', (tester) async {
    // feature-ui-standard §14 requires it, and a permission dialog is exactly
    // the surface a motion-sensitive user should not have thrown at them.
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cubit = buildCubit(
      _FakeMessaging(PushAuthorization.notDetermined),
      _FakeLocation(LocationPermissionStatus.notDetermined),
    );
    addTearDown(cubit.close);
    await cubit.load();

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: phone,
        builder: (context, _) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AppTheme.light(AppTypography.latinFontFamily),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showPermissionPrimerDialog(
                        context: context, cubit: cubit),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // One pump. With animations disabled the dialog must be fully present
    // immediately rather than mid-transition.
    await tester.pump();

    expect(find.text('Two quick permissions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
