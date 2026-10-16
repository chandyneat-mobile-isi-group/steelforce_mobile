import 'package:steelforce/core/logging/app_logger.dart';
import 'package:steelforce/core/notifications/local/local_notification_presenter.dart';

/// Web has no local notifications in this build.
///
/// `flutter_local_notifications` ships no web implementation at all — its Dart
/// entrypoint imports `dart:io`, so merely importing it breaks a web
/// compilation. Hence the conditional split rather than a `kIsWeb` guard.
///
/// Nothing is lost that the web target needs. Android channels are meaningless
/// in a browser, and the two things the presenter draws on mobile both have a
/// better home on a desktop-sized screen: a foreground push renders as the
/// in-app card (which is all web ever had), and the offline queue's
/// "already handled by someone else" message renders as an in-app banner. The
/// inbox — the system of record, per
/// `docs/feature/notification/README.md` §1 — is untouched.
class NoopLocalNotificationPresenter implements LocalNotificationPresenter {
  const NoopLocalNotificationPresenter(this._logger);

  final AppLogger _logger;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    _logger.info('local_notifications.unsupported_platform');
  }

  @override
  Future<void> registerChannels(String Function(String key) translate) async {}

  @override
  Future<void> show({
    required String title,
    required String body,
    String? categoryCode,
    String? payload,
    String? groupKey,
    bool silent = false,
  }) async {}

  /// Always false, so callers route the message to an in-app surface instead of
  /// composing an OS alert that would never appear.
  @override
  Future<bool> areNotificationsEnabled() async => false;

  @override
  Future<void> cancelAll() async {}
}

/// Builds the web presenter. Selected by
/// `local_notification_presenter_factory.dart` when `dart.library.io` is absent.
LocalNotificationPresenter createLocalNotificationPresenter(AppLogger logger) =>
    NoopLocalNotificationPresenter(logger);
