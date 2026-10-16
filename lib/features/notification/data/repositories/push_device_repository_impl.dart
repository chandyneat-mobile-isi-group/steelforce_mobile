import 'package:flutter/foundation.dart';
import 'package:steelforce/core/platform/device/device_identity.dart';
import 'package:steelforce/core/error/failures.dart';
import 'package:steelforce/core/localization/active_language.dart';
import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/network/api/api_error.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';
import 'package:steelforce/core/platform/device/device_name.dart';
import 'package:steelforce/core/platform/device/device_os.dart';
import 'package:steelforce/core/session/session_manager.dart';
import 'package:steelforce/core/utils/result.dart';
import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/core/notifications/device_time_zone.dart';
import 'package:steelforce/features/my_visits/domain/services/location_fix_provider.dart';
import 'package:steelforce/features/notification/data/remote/notification_remote_data_source.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';
import 'package:steelforce/features/notification/domain/repositories/push_device_repository.dart';

/// Keeps this installation's push registration current
/// (`docs/feature/notification/README.md` §4).
///
/// ## The `deviceId` is borrowed, not minted here
///
/// [DeviceIdentity] already mints and persists a per-installation UUID in secure
/// storage for `/auth/login` and `/auth/refresh`. Reusing it means one
/// installation has **one** identity across auth and push, so support looking at
/// a session row and a device-registry row sees the same id. Minting a second
/// would give the same handset two identities that drift apart on reinstall.
///
/// §4.2 is emphatic about what this must *not* be: **never the FCM token**.
/// Tokens rotate; installations do not. Using the token as the upsert key means
/// every rotation creates a duplicate registration row and the old one keeps
/// being pushed to until FCM declares it dead.
class PushDeviceRepositoryImpl implements PushDeviceRepository {
  PushDeviceRepositoryImpl({
    required PushMessagingService messaging,
    required NotificationRemoteDataSource remote,
    required DeviceIdentity identity,
    required SessionManager session,
    required AppLogger logger,
    LocationFixProvider? Function()? getFixProvider,
  })  : _messaging = messaging,
        _remote = remote,
        _identity = identity,
        _session = session,
        _logger = logger,
        _getFixProvider = getFixProvider;

  final PushMessagingService _messaging;
  final NotificationRemoteDataSource _remote;
  final DeviceIdentity _identity;
  final SessionManager _session;
  final AppLogger _logger;
  final LocationFixProvider? Function()? _getFixProvider;

  @override
  Future<PushPermissionStatus> permissionStatus() async =>
      _mapAuthorization(await _messaging.authorization());

  @override
  ResultFuture<PushPermissionStatus> requestPermission() async {
    final authorization = await _messaging.requestPermission();
    final status = _mapAuthorization(authorization);

    // Re-register whichever way the rep answered. §14: a decline is registered
    // with `pushPermissionGranted: false` so the inbox keeps syncing and the
    // delivery log reads `NO_DEVICE` rather than a run of failures — which is
    // the difference between "this rep opted out" and "push is broken".
    //
    // §4.1 also lists a permission change as a registration trigger in its own
    // right, so this is not merely opportunistic.
    final registration = await register();
    return registration.when(
      success: (_) => Success(status),
      // The permission answer is still the useful result. A registration that
      // could not be posted is retried on the next launch, and reporting the
      // network failure here would make a granted permission look like it
      // failed.
      failure: (failure) {
        _logger.warning('push.register_after_permission_failed',
            fields: {'status': status.name});
        return Success(status);
      },
    );
  }

  @override
  ResultFuture<PushRegistrationResult?> register() async {
    // Registration is an authenticated call. A guest has no device row to
    // maintain, and firing it would spend a round trip to be told 401.
    if (!_session.canCallProtectedApi) return const Success(null);

    // No transport on this platform (web). Not a failure — the inbox is
    // unaffected, which is the whole design (§1).
    if (!_messaging.isSupported) return const Success(null);

    final token = await _messaging.token();
    if (token == null || token.isEmpty) {
      // Normal on iOS before the permission is granted: APNs has not handed
      // back a device token yet. Posting an empty one answers
      // `400 Notification.PushTokenRequired`, which the error table says to fix
      // by retrying `getToken()` — which is what the next launch does.
      _logger.info('push.register_skipped_no_token');
      return const Success(null);
    }

    try {
      final authorization = await _messaging.authorization();

      double _lastFixLat = 0.0;
      double _lastFixLng = 0.0;
      double _lastFixAcc = 0.0;
      DateTime? _lastFixTime;

      final provider = _getFixProvider?.call();
      if (provider != null) {
        final fix = await provider.currentFix(
          precise: false,
          timeout: const Duration(seconds: 3),
        );
        if (fix != null && (fix.latitude != 0 || fix.longitude != 0)) {
          _lastFixLat = fix.latitude;
          _lastFixLng = fix.longitude;
          _lastFixAcc = fix.accuracyMeters;
          _lastFixTime = fix.timestamp;
        } else {
          // Bad pair fails the registration per docs (422), but if we can't get it,
          // we might just let it fail at backend or return a local failure.
          // Wait, if no fix, the backend rejects it. We must throw an ApiException.
          throw const ApiException(ApiError(
            code: 'Notification.LocationRequired',
            detail: 'A valid location fix is required for push registration.',
            statusCode: 422,
          ));
        }
      }

      // Logged *before* the registration, and separately from it.
      //
      // `push.registered permitted=false` on its own is unreadable: it is the
      // correct, expected state on a fresh Android 13+ install — §14 defers the
      // prompt to the in-app explainer, so nothing has been asked yet — and it
      // is *also* what a hard denial looks like. Those need completely
      // different responses (wait for the explainer vs. send the rep to
      // Settings), and the single boolean the server echoes cannot tell them
      // apart. This line names the actual state.
      _logger.info('push.permission', fields: {
        'status': authorization.name,
        'audience': _allowsPush(authorization),
        // Android reports no `notDetermined` below API 33 — `POST_NOTIFICATIONS`
        // does not exist, so the plugin answers from
        // `areNotificationsEnabled()` and a fresh install is already
        // `authorized`. Recording the platform makes that difference legible
        // instead of looking like an inconsistency between two handsets.
        'platform': _platform().code,
      });

      final registration = PushRegistration(
        deviceId: await _identity.deviceId(),
        pushToken: token,
        platform: _platform(),
        // Deliberately **not** gated on the permission. §4.2: a declined or
        // not-yet-asked installation is still registered, with
        // `pushPermissionGranted: false`, so the inbox keeps syncing and the
        // delivery log records `NO_DEVICE` once rather than a run of failures
        // against a handset that was never going to ring.
        pushPermissionGranted: _allowsPush(authorization),
        deviceName: await readDeviceName(),
        appVersion: DeviceIdentity.appVersion,
        osVersion: readOsVersion(),
        locale: ActiveLanguage.acceptLanguageTag,
        // The IANA zone, not the abbreviation. Quiet hours and digests are
        // wall-clock facts; without this the backend assumes UTC and a rep's
        // 22:00 quiet window starts at 05:00 local (§4.2).
        timeZone: await readIanaTimeZone(),
        latitude: _lastFixLat,
        longitude: _lastFixLng,
        locationAccuracyMeters: _lastFixAcc,
        locationCapturedAt: _lastFixTime ?? DateTime.now(),
      );

      final result = await _remote.registerDevice(registration);
      _logger.info('push.registered', fields: {
        'active': result.isActive,
        'permitted': result.pushPermissionGranted,
        // Surfaces a server/client disagreement. The endpoint echoes what it
        // stored, so if these two ever differ the request was rejected or
        // normalised and the handset's belief about its own push audience is
        // wrong.
        'sentPermitted': registration.pushPermissionGranted,
      });
      return Success(result);
    } on ApiException catch (e) {
      _logger.warning('push.register_failed', fields: {
        'code': e.error.code,
        'status': e.error.statusCode,
      });
      if (e.error.code == ApiErrorCodes.network) {
        return const Failed(NetworkFailure());
      }
      return Failed(ServerFailure(
        message: e.error.message ?? 'Could not register this device.',
        statusCode: e.error.statusCode,
      ));
    }
  }

  @override
  ResultFuture<void> deregister() async {
    // Deliberately does **not** gate on `canCallProtectedApi`.
    //
    // Sign-out clears the session, and the order in `AuthBloc._onLogout` puts
    // token disposal first. If this waited for an "authenticated" session it
    // would refuse to run at exactly the moment it is needed. The bearer token
    // is still attached by the interceptor at this point, which is why §4.4
    // insists this be called *before* the token is discarded.
    final deviceId = await _identity.deviceId();

    // Drop the local token first. Even if the server call fails, this handset
    // stops being able to receive — which is the outcome that matters when a
    // phone changes hands.
    await _messaging.deleteToken();

    try {
      await _remote.deregisterDevice(deviceId);
      _logger.info('push.deregistered');
      return const Success(null);
    } on ApiException catch (e) {
      // `404 Notification.DeviceNotFound` means the registration is already
      // gone. §15: treat sign-out as done.
      if (e.error.code == _deviceNotFound || e.error.statusCode == 404) {
        return const Success(null);
      }
      // Everything else is logged and swallowed. Sign-out must never fail
      // because a deregistration did — a rep who cannot sign out is worse than
      // a stale registration, and the server deactivates a dead token on its own
      // once FCM reports it.
      _logger.warning('push.deregister_failed', fields: {
        'code': e.error.code,
        'status': e.error.statusCode,
      });
      return const Success(null);
    }
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.tokenRefreshes;

  /// §4.2 accepts `Android`, `IOS` or `Web` and stores anything else as
  /// `Unknown` rather than rejecting it, so this is a display hint on the device
  /// registry and never a gate.
  ///
  /// Reads `defaultTargetPlatform` rather than `Platform.operatingSystem`, for
  /// the same reason `DeviceIdentity` does: `dart:io` is unavailable on web, and
  /// this file compiles for every target.
  PushPlatform _platform() => switch (defaultTargetPlatform) {
        TargetPlatform.android => PushPlatform.android,
        TargetPlatform.iOS => PushPlatform.ios,
        // Desktop has no push transport in this build, so the value is only ever
        // seen on a registration that `register()` has already skipped.
        _ => PushPlatform.web,
      };

  PushPermissionStatus _mapAuthorization(PushAuthorization authorization) =>
      switch (authorization) {
        PushAuthorization.notDetermined => PushPermissionStatus.notDetermined,
        PushAuthorization.authorized => PushPermissionStatus.granted,
        PushAuthorization.provisional => PushPermissionStatus.provisional,
        PushAuthorization.denied => PushPermissionStatus.denied,
        PushAuthorization.deniedPermanently =>
          PushPermissionStatus.deniedPermanently,
        PushAuthorization.unsupported => PushPermissionStatus.unsupported,
      };

  bool _allowsPush(PushAuthorization authorization) =>
      authorization == PushAuthorization.authorized ||
      authorization == PushAuthorization.provisional;

  /// §15. Not one of yours.
  static const String _deviceNotFound = 'Notification.DeviceNotFound';
}
