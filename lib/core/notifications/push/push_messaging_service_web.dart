import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/push/push_message.dart';
import 'package:steelforce/core/notifications/push/push_messaging_service.dart';

/// The web transport: there isn't one, and that is a decision rather than a gap.
///
/// ## Why web has no push in this build
///
/// FCM on the web is a different delivery mechanism from the mobile one, not the
/// same one with a different plugin. It needs three things this app does not
/// ship: a `firebase-messaging-sw.js` service worker at the site root, a VAPID
/// key pair registered against the Firebase project, and the Firebase web config
/// inlined into `web/index.html`. Half-wiring it produces the worst possible
/// outcome — a browser that *asks* for notification permission and then never
/// delivers anything.
///
/// It also buys very little. The web target is a desk-bound view of the same
/// data (ADR-010), where a rep already has the app open; the mobile handset in
/// the field is the surface that needs waking.
///
/// ## Why this is a no-op and not an error
///
/// `docs/feature/notification/README.md` §1: *"Design the app so that a
/// dropped push costs nothing."* Web is the permanent case of that. Every method
/// answers honestly — [isSupported] is false, [authorization] is
/// [PushAuthorization.unsupported], [token] is null — so
/// `PushDeviceRepository` skips registration entirely rather than posting a
/// registration with an empty token, and the inbox catch-up runs exactly as it
/// does on a handset.
///
/// This is why nothing above `PushMessagingService` needs a `kIsWeb` branch.
class UnsupportedPushMessagingService implements PushMessagingService {
  const UnsupportedPushMessagingService(this._logger);

  final AppLogger _logger;

  @override
  bool get isSupported => false;

  @override
  Future<void> initialize() async {
    // Logged once at info, so a web session's console says why no token was
    // ever registered instead of leaving it to be inferred from silence.
    _logger.info('push.unsupported_platform');
  }

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();

  @override
  Future<PushAuthorization> authorization() async =>
      PushAuthorization.unsupported;

  /// Never prompts.
  ///
  /// Returning [PushAuthorization.unsupported] rather than
  /// [PushAuthorization.denied] matters: `denied` would have the permission
  /// explainer treat this as a rep who said no and offer them a route into
  /// system settings that cannot help.
  @override
  Future<PushAuthorization> requestPermission() async =>
      PushAuthorization.unsupported;

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

/// Builds the web transport. Selected by
/// `push_messaging_service_factory.dart` when `dart.library.io` is absent.
PushMessagingService createPushMessagingService(AppLogger logger) =>
    UnsupportedPushMessagingService(logger);
