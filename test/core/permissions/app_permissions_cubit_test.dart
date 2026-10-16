import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/core/permissions/location_permission_service.dart';
import 'package:steelforce/core/permissions/presentation/app_permissions_cubit.dart';

/// A push transport whose authorisation answer is scripted.
class _FakeMessaging implements PushMessagingService {
  _FakeMessaging(this.authorisation);

  PushAuthorization authorisation;

  /// What the OS answers when the prompt is shown. Defaults to no change, which
  /// models a platform that refuses to re-prompt.
  PushAuthorization? promptResult;

  int requestCount = 0;

  @override
  bool get isSupported => authorisation != PushAuthorization.unsupported;

  @override
  Future<PushAuthorization> authorization() async => authorisation;

  @override
  Future<PushAuthorization> requestPermission() async {
    requestCount++;
    authorisation = promptResult ?? authorisation;
    return authorisation;
  }

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
  _FakeLocation(this.current);

  LocationPermissionStatus current;
  LocationPermissionStatus? promptResult;

  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<LocationPermissionStatus> status() async => current;

  @override
  Future<LocationPermissionStatus> request() async {
    requestCount++;
    current = promptResult ?? current;
    return current;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount++;
    return true;
  }
}

void main() {
  setUpAll(() => Hive.init('.dart_tool/test_hive_app_permissions'));

  late Box<dynamic> box;
  late int registrations;
  var now = DateTime.utc(2026, 9, 10, 9);

  setUp(() async {
    now = DateTime.utc(2026, 9, 10, 9);
    registrations = 0;
    box = await Hive.openBox<dynamic>(
      'perm_${DateTime.now().microsecondsSinceEpoch}',
      bytes: Uint8List(0),
    );
  });

  tearDown(() async => box.close());

  AppPermissionsCubit build(
    _FakeMessaging messaging,
    _FakeLocation location, {
    Future<void> Function()? onRegister,
  }) =>
      AppPermissionsCubit(
        messaging: messaging,
        location: location,
        cache: LocalCache(box),
        logger: const ConsoleAppLogger(verbose: false),
        registerPushDevice: onRegister ??
            () async {
              registrations++;
            },
        clock: () => now,
      );

  group('shouldPrompt — §14 gating', () {
    test('never before the rep has seen a route', () async {
      final cubit = build(
        _FakeMessaging(PushAuthorization.notDetermined),
        _FakeLocation(LocationPermissionStatus.notDetermined),
      );
      addTearDown(cubit.close);

      expect(await cubit.shouldPrompt(hasSeenFirstRoute: false), isFalse);
    });

    test('yes when something is unanswered', () async {
      final cubit = build(
        _FakeMessaging(PushAuthorization.notDetermined),
        _FakeLocation(LocationPermissionStatus.notDetermined),
      );
      addTearDown(cubit.close);

      expect(await cubit.shouldPrompt(hasSeenFirstRoute: true), isTrue);
    });

    test('no when both are already granted', () async {
      final cubit = build(
        _FakeMessaging(PushAuthorization.authorized),
        _FakeLocation(LocationPermissionStatus.whileInUse),
      );
      addTearDown(cubit.close);

      expect(await cubit.shouldPrompt(hasSeenFirstRoute: true), isFalse);
    });

    test('no when the only outstanding one is blocked', () async {
      // Settings is the only route left, so a dialog whose primary action asks
      // the OS would offer a button that cannot work. The inbox banner covers
      // this case instead.
      final cubit = build(
        _FakeMessaging(PushAuthorization.deniedPermanently),
        _FakeLocation(LocationPermissionStatus.deniedForever),
      );
      addTearDown(cubit.close);

      expect(await cubit.shouldPrompt(hasSeenFirstRoute: true), isFalse);
    });

    test('respects the 14-day cap after a skip', () async {
      final cubit = build(
        _FakeMessaging(PushAuthorization.notDetermined),
        _FakeLocation(LocationPermissionStatus.notDetermined),
      );
      addTearDown(cubit.close);

      await cubit.skip();

      now = now.add(const Duration(days: 13, hours: 23));
      expect(await cubit.shouldPrompt(hasSeenFirstRoute: true), isFalse);

      now = now.add(const Duration(hours: 2));
      expect(await cubit.shouldPrompt(hasSeenFirstRoute: true), isTrue);
    });
  });

  group('requestAll', () {
    test('asks both, in order, and registers the device', () async {
      final messaging = _FakeMessaging(PushAuthorization.notDetermined)
        ..promptResult = PushAuthorization.authorized;
      final location = _FakeLocation(LocationPermissionStatus.notDetermined)
        ..promptResult = LocationPermissionStatus.whileInUse;
      final cubit = build(messaging, location);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.requestAll();

      expect(messaging.requestCount, 1);
      expect(location.requestCount, 1);
      expect(cubit.state.notifications, PermissionOutcome.granted);
      expect(cubit.state.location, PermissionOutcome.granted);
      expect(cubit.state.settled, isTrue);
      expect(registrations, 1);
    });

    test('registers even when the rep declines the push prompt', () async {
      // §4.2: the registration is kept with `pushPermissionGranted: false`, so
      // the inbox still syncs and the delivery log reads `NO_DEVICE` once
      // instead of a run of failures.
      final messaging = _FakeMessaging(PushAuthorization.notDetermined)
        ..promptResult = PushAuthorization.denied;
      final cubit = build(
        messaging,
        _FakeLocation(LocationPermissionStatus.notDetermined),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.requestAll();

      expect(cubit.state.notifications, PermissionOutcome.declined);
      expect(registrations, 1, reason: 'a decline is still a registration');
    });

    test('does not re-ask a permission already granted', () async {
      final messaging = _FakeMessaging(PushAuthorization.authorized);
      final location = _FakeLocation(LocationPermissionStatus.notDetermined)
        ..promptResult = LocationPermissionStatus.whileInUse;
      final cubit = build(messaging, location);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.requestAll();

      expect(messaging.requestCount, 0, reason: 'already answered');
      expect(location.requestCount, 1);
    });

    test('never asks the OS for a blocked permission', () async {
      // Requesting would return the same refusal without showing anything, and
      // the row already tells the rep to use Settings.
      final messaging = _FakeMessaging(PushAuthorization.deniedPermanently);
      final location = _FakeLocation(LocationPermissionStatus.servicesDisabled);
      final cubit = build(messaging, location);
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.requestAll();

      expect(messaging.requestCount, 0);
      expect(location.requestCount, 0);
      expect(cubit.state.notifications, PermissionOutcome.blocked);
      expect(cubit.state.location, PermissionOutcome.blocked);
    });

    test('a second tap while asking is ignored', () async {
      // Two overlapping system dialogs is undefined on both platforms, and on
      // Android the second silently replaces the first — so the rep answers one
      // question and is recorded as having answered two.
      final messaging = _FakeMessaging(PushAuthorization.notDetermined)
        ..promptResult = PushAuthorization.authorized;
      final cubit = build(
        messaging,
        _FakeLocation(LocationPermissionStatus.notDetermined),
      );
      addTearDown(cubit.close);

      await cubit.load();
      final first = cubit.requestAll();
      final second = cubit.requestAll();
      await Future.wait([first, second]);

      expect(messaging.requestCount, 1);
    });

    test('a registration failure does not break the sequence', () async {
      // A rep who cannot register for push must still reach their inbox, and
      // §4.1's four triggers mean the registration retries on its own.
      final location = _FakeLocation(LocationPermissionStatus.notDetermined)
        ..promptResult = LocationPermissionStatus.whileInUse;
      final cubit = build(
        _FakeMessaging(PushAuthorization.notDetermined)
          ..promptResult = PushAuthorization.authorized,
        location,
        onRegister: () async => throw StateError('offline'),
      );
      addTearDown(cubit.close);

      await cubit.load();
      await cubit.requestAll();

      expect(cubit.state.location, PermissionOutcome.granted,
          reason: 'location was still asked after the failure');
      expect(cubit.state.settled, isTrue);
    });
  });

  group('web / unsupported', () {
    test('an unsupported permission is hidden, not shown as declined',
        () async {
      final cubit = build(
        _FakeMessaging(PushAuthorization.unsupported),
        _FakeLocation(LocationPermissionStatus.notDetermined),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.notifications, PermissionOutcome.unavailable);
      expect(cubit.state.visiblePermissions, [AppPermission.location]);
    });

    test('no dialog at all when nothing is supported', () async {
      final cubit = build(
        _FakeMessaging(PushAuthorization.unsupported),
        _FakeLocation(LocationPermissionStatus.unsupported),
      );
      addTearDown(cubit.close);

      expect(await cubit.shouldPrompt(hasSeenFirstRoute: true), isFalse);
      expect(cubit.state.visiblePermissions, isEmpty);
    });
  });

  group('skip', () {
    test('registers the device and settles without prompting', () async {
      final messaging = _FakeMessaging(PushAuthorization.notDetermined);
      final location = _FakeLocation(LocationPermissionStatus.notDetermined);
      final cubit = build(messaging, location);
      addTearDown(cubit.close);

      await cubit.skip();

      expect(messaging.requestCount, 0);
      expect(location.requestCount, 0);
      expect(registrations, 1);
      expect(cubit.state.settled, isTrue);
    });
  });

  group('status semantics', () {
    test('only foreground and always count as granted', () {
      expect(LocationPermissionStatus.whileInUse.isGranted, isTrue);
      expect(LocationPermissionStatus.always.isGranted, isTrue);
      expect(LocationPermissionStatus.denied.isGranted, isFalse);
      expect(LocationPermissionStatus.servicesDisabled.isGranted, isFalse);
    });

    test('services-disabled needs settings, not another prompt', () {
      // The distinction that matters: granting changes nothing while the
      // device-wide toggle is off.
      expect(LocationPermissionStatus.servicesDisabled.canPrompt, isFalse);
      expect(LocationPermissionStatus.servicesDisabled.needsSystemSettings,
          isTrue);
      expect(LocationPermissionStatus.deniedForever.canPrompt, isFalse);
      expect(LocationPermissionStatus.denied.canPrompt, isTrue);
    });
  });
}
