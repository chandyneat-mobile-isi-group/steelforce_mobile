import 'package:steelforce/core/utils/typedefs.dart';
import 'package:steelforce/features/notification/domain/entities/push_registration.dart';

/// This installation's standing with the push service
/// (`docs/feature/notification/README.md` §4).
///
/// ## Register more often than feels necessary
///
/// §4.1 lists four triggers: after every successful login, on **every** app
/// launch (not only the first — FCM rotates tokens silently), from
/// `onTokenRefresh`, and whenever the OS permission changes. The endpoint is
/// idempotent on `deviceId`, so calling it too often costs one cheap round trip.
/// Calling it too rarely is how a rep silently stops receiving anything, with no
/// symptom until somebody notices they missed a route.
abstract interface class PushDeviceRepository {
  /// The OS notification permission as it stands right now.
  ///
  /// Read rather than remembered: the rep can revoke it in system settings at
  /// any time, and a cached "granted" is how a device stays in the push audience
  /// long after it stopped being able to show anything.
  Future<PushPermissionStatus> permissionStatus();

  /// Shows the OS permission prompt and returns the outcome.
  ///
  /// **Never call this on first launch.** iOS gives exactly one prompt ever, and
  /// spending it on a rep who has not yet seen a route is how an app ends up
  /// permanently silent (§14). The explainer card gates this.
  ///
  /// Re-registers afterwards with the new `pushPermissionGranted`, whichever way
  /// the rep answered — a declined registration is still kept so the inbox
  /// syncs, and it keeps the delivery log reading `NO_DEVICE` rather than a run
  /// of failures.
  ResultFuture<PushPermissionStatus> requestPermission();

  /// Registers or refreshes this installation.
  ///
  /// Sends the current token, the IANA time zone (without which the backend has
  /// to assume UTC and a 22:00 quiet window starts at 05:00 local), and the real
  /// permission state. A registration the backend previously deactivated because
  /// FCM reported the token dead is **revived** by this call, so a rep never
  /// needs an administrator to start receiving notifications again (§4.3).
  ///
  /// Returns a null result when there is nothing to register — no push transport
  /// in this build (web), or FCM has not minted a token yet. That is a normal
  /// outcome, not a failure: the inbox is unaffected.
  ResultFuture<PushRegistrationResult?> register();

  /// Deregisters this installation — `DELETE /mobile/devices/{deviceId}`.
  ///
  /// **Call this before discarding the access token.** Skipping it leaves the
  /// platform pushing one rep's notifications at a handset that has since been
  /// handed to somebody else (§4.4). `404 Notification.DeviceNotFound` is
  /// success: it means the registration is already gone.
  ResultFuture<void> deregister();

  /// Fires whenever FCM rotates the token, so [register] can run again.
  ///
  /// §4.1 lists this as a required trigger. A rotated token that is never
  /// re-registered is the failure mode with no symptom — the app looks healthy
  /// and simply stops being reachable.
  Stream<String> get tokenRefreshes;
}
