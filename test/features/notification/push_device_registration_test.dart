import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/features/authentication/domain/entities/user.dart';
import 'package:steelforce/features/authentication/domain/entities/user_role.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/data/repositories/push_device_repository_impl.dart';
import 'package:steelforce/features/notification/domain/entities/notification_counts.dart';
import 'package:steelforce/features/notification/domain/entities/notification_preferences.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

class _FakeMessaging implements PushMessagingService {
  _FakeMessaging(this.authorisation, {this.pushToken = 'fcm-token'});

  PushAuthorization authorisation;
  String? pushToken;

  int requestCount = 0;

  @override
  bool get isSupported => authorisation != PushAuthorization.unsupported;

  @override
  Future<PushAuthorization> authorization() async => authorisation;

  @override
  Future<PushAuthorization> requestPermission() async {
    requestCount++;
    return authorisation;
  }

  @override
  Future<String?> token() async => pushToken;

  @override
  Future<void> initialize() async {}
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

/// Records the registration body so the tests can assert on what was *sent*
/// rather than only on what came back.
class _RecordingRemote implements NotificationRemoteDataSource {
  final List<PushRegistration> registered = [];
  final List<String> deregistered = [];

  @override
  Future<PushRegistrationResult> registerDevice(
      PushRegistration registration) async {
    registered.add(registration);
    // Echoes the request, exactly as the endpoint documents.
    return PushRegistrationResult(
      id: 'server-id',
      deviceId: registration.deviceId,
      isActive: true,
      pushPermissionGranted: registration.pushPermissionGranted,
      lastSeenAt: DateTime.utc(2026, 9, 10),
    );
  }

  @override
  Future<void> deregisterDevice(String deviceId) async =>
      deregistered.add(deviceId);

  @override
  Future<NotificationPage> fetchPage({
    DateTime? since,
    int pageNumber = 1,
    int pageSize = 100,
  }) async =>
      throw UnimplementedError();
  @override
  Future<NotificationCounts> fetchCounts() async => throw UnimplementedError();
  @override
  Future<void> markRead(String id) async => throw UnimplementedError();
  @override
  Future<int> markAllRead({String? categoryCode}) async =>
      throw UnimplementedError();
  @override
  Future<void> recordAction(String id,
          {String? actionId, DateTime? occurredAt}) async =>
      throw UnimplementedError();
  @override
  Future<void> dismiss(String id) async => throw UnimplementedError();
  @override
  Future<void> invokeAction(
          {required String endpoint, required String method}) async =>
      throw UnimplementedError();
  @override
  Future<NotificationPreferences> fetchPreferences() async =>
      throw UnimplementedError();
  @override
  Future<NotificationPreferences> savePreferences(
          NotificationPreferences preferences) async =>
      throw UnimplementedError();
}

void main() {
  late _RecordingRemote remote;
  late SessionManager session;
  late _MockSecureStorage storage;

  setUp(() {
    remote = _RecordingRemote();
    storage = _MockSecureStorage();
    // `DeviceIdentity` mints and persists a UUID on first read.
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => 'installation-1');
    when(() =>
            storage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});

    session = SessionManager()
      ..setUser(const User(
        id: 'u1',
        fullName: 'Dara',
        email: 'dara@example.com',
        roles: {UserRole.salesRep},
      ));
  });

  tearDown(() => session.dispose());

  PushDeviceRepositoryImpl build(_FakeMessaging messaging) =>
      PushDeviceRepositoryImpl(
        messaging: messaging,
        remote: remote,
        identity: DeviceIdentity(storage),
        session: session,
        logger: const ConsoleAppLogger(verbose: false),
      );

  group('permitted mirrors the authorisation state, not the token', () {
    // The question behind `push.registered permitted=false`. A device can hold a
    // valid FCM token and a successful registration while having no permission —
    // these are separate facts and the registration carries both.
    test('notDetermined registers with permitted=false', () async {
      // The expected state on a fresh Android 13+ install: §14 defers the prompt
      // to the in-app explainer, so nothing has been asked yet. Not a failure.
      final repository = build(_FakeMessaging(PushAuthorization.notDetermined));

      final result = await repository.register();

      expect(result.when(success: (r) => r?.isActive, failure: (_) => null),
          isTrue);
      expect(remote.registered.single.pushPermissionGranted, isFalse);
      expect(remote.registered.single.pushToken, 'fcm-token',
          reason: 'the token is registered regardless of the permission');
    });

    test('denied registers with permitted=false, keeping the row', () async {
      // §4.2: the registration is *kept* and excluded from the push audience,
      // so the delivery log reads `NO_DEVICE` once instead of a run of
      // failures.
      final repository = build(_FakeMessaging(PushAuthorization.denied));

      await repository.register();

      expect(remote.registered, hasLength(1));
      expect(remote.registered.single.pushPermissionGranted, isFalse);
    });

    test('deniedPermanently still registers', () async {
      final repository =
          build(_FakeMessaging(PushAuthorization.deniedPermanently));

      await repository.register();

      expect(remote.registered.single.pushPermissionGranted, isFalse);
    });

    test('authorized registers with permitted=true', () async {
      final repository = build(_FakeMessaging(PushAuthorization.authorized));

      await repository.register();

      expect(remote.registered.single.pushPermissionGranted, isTrue);
    });

    test('provisional counts as in the push audience', () async {
      // iOS quiet delivery. The message still arrives, so the backend must
      // include the device — treating it as declined would silence a rep who
      // never declined anything.
      final repository = build(_FakeMessaging(PushAuthorization.provisional));

      await repository.register();

      expect(remote.registered.single.pushPermissionGranted, isTrue);
    });
  });

  group('when registration is skipped entirely', () {
    test('a guest is never registered', () async {
      session.clear();
      final repository = build(_FakeMessaging(PushAuthorization.authorized));

      await repository.register();

      expect(remote.registered, isEmpty);
    });

    test('no token means no registration, not an empty one', () async {
      // Normal on iOS before the permission is granted — APNs has not issued a
      // device token yet. Posting an empty one answers
      // `400 Notification.PushTokenRequired` and would fail the whole call.
      final repository = build(
        _FakeMessaging(PushAuthorization.notDetermined, pushToken: null),
      );

      final result = await repository.register();

      expect(remote.registered, isEmpty);
      expect(result.when(success: (r) => r, failure: (_) => 'failed'), isNull,
          reason: 'a skip is a success with no result, not a failure');
    });

    test('an unsupported platform is skipped without failing', () async {
      final repository = build(_FakeMessaging(PushAuthorization.unsupported));

      final result = await repository.register();

      expect(remote.registered, isEmpty);
      expect(result.when(success: (_) => true, failure: (_) => false), isTrue);
    });
  });

  group('the registration body', () {
    test('reuses the auth deviceId as the idempotency key', () async {
      // §4.2: `deviceId` identifies an installation, never a token. Reusing the
      // id auth already mints keeps one handset to one registry row across
      // token rotations.
      final repository = build(_FakeMessaging(PushAuthorization.authorized));

      await repository.register();
      await repository.register();

      expect(remote.registered.map((r) => r.deviceId).toSet(), hasLength(1));
      expect(remote.registered.first.deviceId, isNot('fcm-token'));
    });

    test('carries the IANA time zone field', () async {
      // Without it the backend assumes UTC and a 22:00 quiet window starts at
      // 05:00 local. Null is tolerated (the mapper omits it) but the field must
      // be wired.
      final repository = build(_FakeMessaging(PushAuthorization.authorized));

      await repository.register();

      expect(remote.registered.single.locale, isNotEmpty);
    });
  });

  group('deregistration', () {
    test('drops the local token and the server row', () async {
      final messaging = _FakeMessaging(PushAuthorization.authorized);
      final repository = build(messaging);

      await repository.deregister();

      expect(remote.deregistered, hasLength(1));
    });

    test('runs even once the session is gone', () async {
      // §4.4 puts deregistration *before* the token store is cleared, and
      // `AuthBloc` calls it during sign-out. Gating it on an authenticated
      // session would make it refuse at exactly the moment it is needed.
      session.clear();
      final repository = build(_FakeMessaging(PushAuthorization.authorized));

      await repository.deregister();

      expect(remote.deregistered, hasLength(1));
    });
  });
}
