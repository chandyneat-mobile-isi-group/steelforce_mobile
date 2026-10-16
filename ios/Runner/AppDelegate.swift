import Flutter
import GoogleMaps
import UIKit
import UserNotifications
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Read from Info.plist, which resolves $(GOOGLE_MAPS_API_KEY) from
    // ios/Flutter/Env.xcconfig (generated from .env, git-ignored). The key was
    // previously a literal here and leaked via git history —
    // docs/SECURITY.md §9.
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
       !apiKey.isEmpty,
       !apiKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(apiKey)
    } else {
      // Maps tiles will not render. Deliberately not fatal: every non-map screen
      // still works offline, and a missing dev key must not brick the whole app.
      NSLog("[ISI] GoogleMapsApiKey missing — run tool/generate_ios_env.dart. Maps disabled.")
    }
    // ── Push notifications ───────────────────────────────────────────────
    //
    // `flutter_local_notifications` needs an explicit delegate to deliver a
    // tap on an alert it drew itself (the foreground card, and the
    // "already handled elsewhere" message the offline action queue shows on a
    // 409 — docs/features/notification-mobile.md §8.5). Without this those
    // taps are swallowed and the notification simply dismisses.
    //
    // This composes with Firebase rather than competing with it:
    // `FirebaseAppDelegateProxyEnabled` (Info.plist) has Firebase swizzle
    // *this* delegate object, so FCM still sees the APNs token and remote
    // deliveries. Assigning the delegate after `super` would be too late for
    // a cold start from a notification tap, which is why it is here.
    //
    // ⚠️ Do not delete this on the strength of
    // `docs/feature/notification/notification-mobile.md` Step 4.2 ("AppDelegate
    // — no change needed"). That paragraph is about **Firebase**: it is telling
    // you not to add `FirebaseApp.configure()`, which double-initialises and
    // throws. `flutter_local_notifications` is a separate plugin, and its
    // README still requires this delegate assignment (verified against 22.3.0).
    // Removing it silently breaks taps on locally-drawn alerts.
    UNUserNotificationCenter.current().delegate = self

    // Registration itself is deliberately NOT done here. Asking iOS for the
    // APNs token is what triggers the permission prompt, and §14 spends that
    // one-and-only prompt after the rep has seen their first route — not on a
    // cold launch. `PushMessagingService.requestPermission()` drives it from
    // Dart when the explainer is accepted.

    // ── Background sync ──────────────────────────────────────────────────
    //
    // Work saved offline (check-ins/outs, depot registrations, quotations) is
    // sent by an OS-scheduled BGAppRefreshTask while the app is closed —
    // `lib/core/sync/background/background_sync_scheduler_native.dart`.
    //
    // * The registrant callback gives the headless engine iOS spins up for the
    //   task the same plugins as the app (secure storage, path_provider, …);
    //   without it the task's first plugin call throws.
    // * The identifier must match `backgroundSyncTaskId` in Dart and the entry
    //   under `BGTaskSchedulerPermittedIdentifiers` in Info.plist.
    // * `registerLaunchHandlers()` is required because this app adopts UIScene:
    //   handlers must be registered before `didFinishLaunching` returns, which
    //   the plugin's own callback is too late for.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "com.isigroup.steelforce.sync",
      earliestBeginInSeconds: NSNumber(value: 15 * 60))
    WorkmanagerPlugin.registerLaunchHandlers()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
