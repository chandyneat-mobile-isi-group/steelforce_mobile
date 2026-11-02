# Firebase & push notifications

Authoritative: `docs/feature/notification/` (full mobile integration guide —
inbox, push, preferences, deep links) and
`docs/feature/notification/api/devices-register.md`.

---

## 1. The shape of this feature

**The inbox is the notification.** Push only accelerates it — a rep who never
receives a push must still see everything in the in-app inbox after a sync.
Never make push delivery the only path to a piece of information.

Packages: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`,
`flutter_timezone`, `device_info_plus`. Code lives in
`lib/core/notifications/` and `lib/features/notification/`.

---

## 2. Web is a no-op path — keep it that way

`push_messaging_service_*.dart` and `local_notification_presenter_*.dart` use
conditional imports with `_native` / `_web` / `_factory` variants. A browser has
no FCM registration in this build and the inbox still syncs (ADR-010).

**Any new push code must go through the factory and have a web no-op.** Do not
import `firebase_messaging` directly into shared code — it breaks the web build.

---

## 3. Checklist for any notification change

- Android **and** iOS permission flows (`lib/core/permissions/`).
- FCM token registration **and** token refresh — a stale token is a silent
  delivery failure.
- All three app states: foreground (`local_notification_presenter` draws the
  alert the OS will not), background, terminated.
- Channel routing: the backend addresses channels by `channel_id` — see
  `notification_channels.dart`.
- Deep link resolution and navigation: `notification_deep_link.dart`.
- Time zone: the backend needs an **IANA** zone (`Asia/Phnom_Penh`) for quiet
  hours and digests. Use `device_time_zone.dart` — `dart:io` gives only the
  abbreviation (`ICT`), which is not sufficient.
- Device registry fields (`deviceName`) come from `device_info_plus`, not
  `Platform.localHostname` (which answers "localhost" on Android).

---

## 4. Never

- Log a notification payload in a release build — payloads carry customer and
  order data. See `security.md` §3.
- Commit `google-services.json`, `GoogleService-Info.plist` secrets, or any
  Firebase private credential. Check `.gitignore` first.
- Ship a change that was verified on only one platform without saying so.
