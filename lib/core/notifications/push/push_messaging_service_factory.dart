/// Platform-selected [PushMessagingService] constructor.
///
/// Both sides expose `PushMessagingService createPushMessagingService(AppLogger)`.
/// Native returns the `firebase_messaging`-backed transport; web returns a
/// no-op that reports `isSupported == false`, because a browser build ships no
/// service worker or VAPID key (ADR-010, and see
/// `push_messaging_service_web.dart` for the full reasoning).
///
/// The conditional export — rather than a `kIsWeb` branch — is what keeps
/// `firebase_messaging` out of the web compilation unit entirely. A runtime
/// branch would still have to compile the Firebase import for web, and
/// `firebase_core`'s web path insists on config this app does not provide.
/// Same pattern as `core/platform/device/device_os.dart`.
library;

export 'push_messaging_service_web.dart'
    if (dart.library.io) 'push_messaging_service_native.dart';
