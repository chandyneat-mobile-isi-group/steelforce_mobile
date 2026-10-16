import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:steelforce/core/database/hive/local_cache.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';
import 'package:steelforce/features/notification/domain/repositories/push_device_repository.dart';
import 'package:steelforce/features/notification/domain/usecases/push_device_usecases.dart';
import 'package:steelforce/features/notification/presentation/bloc/push_permission_cubit.dart';

/// A push-device repository whose permission answer is scripted.
class _FakeDevices implements PushDeviceRepository {
  _FakeDevices(this.status);

  PushPermissionStatus status;

  /// What the OS answers when the prompt is actually shown. Defaults to
  /// whatever [status] already is, which models the platforms that refuse to
  /// re-prompt.
  PushPermissionStatus? promptResult;

  int requestCount = 0;

  @override
  Future<PushPermissionStatus> permissionStatus() async => status;

  @override
  ResultFuture<PushPermissionStatus> requestPermission() async {
    requestCount++;
    status = promptResult ?? status;
    return Success(status);
  }

  @override
  ResultFuture<PushRegistrationResult?> register() async => const Success(null);

  @override
  ResultFuture<void> deregister() async => const Success(null);

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();
}

void main() {
  setUpAll(() => Hive.init('.dart_tool/test_hive_push_permission'));

  late Box<dynamic> box;
  var now = DateTime.utc(2026, 9, 9, 9);

  setUp(() async {
    now = DateTime.utc(2026, 9, 9, 9);
    box = await Hive.openBox<dynamic>(
      'push_perm_${DateTime.now().microsecondsSinceEpoch}',
      bytes: Uint8List(0),
    );
  });

  tearDown(() async => box.close());

  PushPermissionCubit build(_FakeDevices devices) => PushPermissionCubit(
        getStatus: GetPushPermissionStatus(devices),
        requestPermission: RequestPushPermission(devices),
        cache: LocalCache(box),
        clock: () => now,
      );

  group('§14 — the prompt is never spent on a cold user', () {
    test('no explainer before the rep has seen their first route', () async {
      // The single most consequential rule in the feature. iOS gives one prompt
      // ever; spending it on somebody who has just installed the app and has no
      // idea what it does is unrecoverable except by a support call.
      final devices = _FakeDevices(PushPermissionStatus.notDetermined);
      final cubit = build(devices);
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: false);

      expect(cubit.state.showExplainer, isFalse);
      expect(devices.requestCount, 0, reason: 'the OS must not be asked');
    });

    test('explainer appears once the rep has seen a route', () async {
      final cubit = build(_FakeDevices(PushPermissionStatus.notDetermined));
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);

      expect(cubit.state.showExplainer, isTrue);
    });

    test('accept() is the only path to the OS prompt', () async {
      final devices = _FakeDevices(PushPermissionStatus.notDetermined)
        ..promptResult = PushPermissionStatus.granted;
      final cubit = build(devices);
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);
      expect(devices.requestCount, 0);

      await cubit.accept();

      expect(devices.requestCount, 1);
      expect(cubit.state.status, PushPermissionStatus.granted);
      expect(cubit.state.showExplainer, isFalse);
    });
  });

  group('already answered', () {
    test('granted shows neither card nor banner', () async {
      final cubit = build(_FakeDevices(PushPermissionStatus.granted));
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);

      expect(cubit.state.showExplainer, isFalse);
      expect(cubit.state.showDeclinedBanner, isFalse);
    });

    test('provisional counts as answered', () async {
      final cubit = build(_FakeDevices(PushPermissionStatus.provisional));
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);

      expect(cubit.state.showExplainer, isFalse);
      expect(cubit.state.showDeclinedBanner, isFalse);
    });

    test('unsupported (web) shows nothing at all', () async {
      // Not a denial. Pointing a browser user at iOS system settings would be
      // nonsense, so the banner must stay away too.
      final cubit = build(_FakeDevices(PushPermissionStatus.unsupported));
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);

      expect(cubit.state.showExplainer, isFalse);
      expect(cubit.state.showDeclinedBanner, isFalse);
    });
  });

  group('the 14-day re-offer cap', () {
    test('"Not now" suppresses the card until 14 days have passed', () async {
      final cubit = build(_FakeDevices(PushPermissionStatus.notDetermined));
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);
      await cubit.defer();
      expect(cubit.state.showExplainer, isFalse);

      now = now.add(const Duration(days: 13, hours: 23));
      await cubit.evaluate(hasSeenFirstRoute: true);
      expect(cubit.state.showExplainer, isFalse,
          reason: 'still inside 14 days');

      now = now.add(const Duration(hours: 2));
      await cubit.evaluate(hasSeenFirstRoute: true);
      expect(cubit.state.showExplainer, isTrue, reason: '14 days elapsed');
    });

    test('accept() starts the clock even if the prompt is dismissed', () async {
      // A rep who taps outside the system dialog leaves the status
      // `notDetermined`. Without stamping the clock the card returns on the very
      // next evaluate, which is the nagging §14 caps.
      final devices = _FakeDevices(PushPermissionStatus.notDetermined);
      final cubit = build(devices);
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);
      await cubit.accept();

      now = now.add(const Duration(days: 1));
      await cubit.evaluate(hasSeenFirstRoute: true);

      expect(cubit.state.showExplainer, isFalse);
    });
  });

  group('declined', () {
    test('denied shows the settings banner and may be re-offered', () async {
      final cubit = build(_FakeDevices(PushPermissionStatus.denied));
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);

      // First reach: the explainer is still allowed, because on Android a
      // dismissed prompt can be shown again.
      expect(cubit.state.showExplainer, isTrue);

      await cubit.defer();
      expect(cubit.state.showDeclinedBanner, isTrue);
    });

    test('deniedPermanently never offers the explainer', () async {
      // The regression this pins. `firebase_messaging` 16 reports Android 13+
      // hard denials separately, and the OS will not prompt again — so the
      // card's "Enable" button would call `requestPermission()`, get the same
      // denial back, and show the rep nothing. A control that silently fails is
      // worse than no control.
      final devices = _FakeDevices(PushPermissionStatus.deniedPermanently);
      final cubit = build(devices);
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);

      expect(cubit.state.showExplainer, isFalse);
      expect(cubit.state.showDeclinedBanner, isTrue,
          reason: 'settings is the only route left, so say so');
      expect(devices.requestCount, 0);
    });

    test('deniedPermanently is not re-offered even after 14 days', () async {
      final cubit = build(_FakeDevices(PushPermissionStatus.deniedPermanently));
      addTearDown(cubit.close);

      await cubit.evaluate(hasSeenFirstRoute: true);
      now = now.add(const Duration(days: 30));
      await cubit.evaluate(hasSeenFirstRoute: true);

      expect(cubit.state.showExplainer, isFalse);
      expect(cubit.state.showDeclinedBanner, isTrue);
    });

    test('the explainer and the banner are never both on screen', () async {
      // Two surfaces asking about the same thing at once reads as nagging, and
      // §14 asks for one or the other.
      for (final status in PushPermissionStatus.values) {
        final cubit = build(_FakeDevices(status));
        await cubit.evaluate(hasSeenFirstRoute: true);

        expect(
          cubit.state.showExplainer && cubit.state.showDeclinedBanner,
          isFalse,
          reason: 'both visible for $status',
        );
        await cubit.close();
      }
    });
  });

  group('status semantics', () {
    test('only granted and provisional join the push audience', () {
      // Drives `pushPermissionGranted` on the device registration (§4.2). A
      // declined device is still registered — it just must not be counted as
      // reachable, or the delivery log fills with failures instead of reading
      // `NO_DEVICE`.
      expect(PushPermissionStatus.granted.allowsPush, isTrue);
      expect(PushPermissionStatus.provisional.allowsPush, isTrue);
      expect(PushPermissionStatus.denied.allowsPush, isFalse);
      expect(PushPermissionStatus.deniedPermanently.allowsPush, isFalse);
      expect(PushPermissionStatus.notDetermined.allowsPush, isFalse);
      expect(PushPermissionStatus.unsupported.allowsPush, isFalse);
    });

    test('canPrompt excludes the states where asking cannot help', () {
      expect(PushPermissionStatus.notDetermined.canPrompt, isTrue);
      expect(PushPermissionStatus.denied.canPrompt, isTrue);
      expect(PushPermissionStatus.deniedPermanently.canPrompt, isFalse);
      expect(PushPermissionStatus.granted.canPrompt, isFalse);
      expect(PushPermissionStatus.unsupported.canPrompt, isFalse);
    });

    test('only deniedPermanently needs the settings app', () {
      expect(
          PushPermissionStatus.deniedPermanently.needsSystemSettings, isTrue);
      expect(PushPermissionStatus.denied.needsSystemSettings, isFalse);
      expect(PushPermissionStatus.unsupported.needsSystemSettings, isFalse);
    });
  });
}
