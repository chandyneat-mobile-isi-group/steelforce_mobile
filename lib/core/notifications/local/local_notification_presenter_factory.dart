/// Platform-selected [LocalNotificationPresenter] constructor.
///
/// Both sides expose
/// `LocalNotificationPresenter createLocalNotificationPresenter(AppLogger)`.
///
/// A conditional export rather than a `kIsWeb` branch, because
/// `flutter_local_notifications` has no web implementation and its Dart
/// entrypoint imports `dart:io` — a runtime branch would still have to compile
/// that import for web and would fail the build. Same pattern as
/// `core/platform/storage/local_files.dart`.
library;

export 'local_notification_presenter_web.dart'
    if (dart.library.io) 'local_notification_presenter_native.dart';
