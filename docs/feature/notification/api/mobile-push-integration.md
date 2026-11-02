# Mobile integration: push notifications and the in-app inbox

For the mobile team. This page covers three things:

- **Registering the phone** so the backend can send it push notifications.
- **Handling a push** when it arrives or is tapped.
- **The in-app inbox:** the notification list and the unread badge.

The backend sends pushes through Firebase Cloud Messaging (FCM). Every push is also saved in the
user's inbox, so nothing is lost if a push is missed.

Field-level contract: [api-contract.md](api-contract.md). Design: [README.md](README.md).

## Before you start

| Item | Notes |
|---|---|
| Firebase SDK | Firebase Messaging (`firebase_messaging` in Flutter). |
| Firebase config | `google-services.json` / `GoogleService-Info.plist` for the right environment's project. Ask the backend team for the project of each environment. |
| Android | Create a notification channel with id **`default`**; the backend sends every push on it. Android 13+: ask for the `POST_NOTIFICATIONS` permission. |
| iOS | Push Notifications capability, and an APNs key uploaded in the Firebase console. Ask for permission (`requestPermission`). |
| Installation id | A UUID the app generates **once** at first launch and keeps in storage. Send the same value as `deviceId` in `POST /api/v1/mobile/auth/login`. |

Every call below needs `Authorization: Bearer <accessToken>` from the **mobile** login
(`POST /api/v1/mobile/auth/login`).

All responses use the usual envelope: `{ "success": true, "data": … }` on success and
`{ "success": false, "error": { "code", "message", "traceId", "details" } }` on error. The
examples below show only `data`.

---

## 1. Register the phone

```http
PUT /api/v1/me/devices/{installationId}
Authorization: Bearer <accessToken>
Content-Type: application/json

{
  "platform": "android",
  "pushToken": "<FCM registration token>",
  "locale": "km",
  "appVersion": "1.4.0"
}
```

| Field | Rules |
|---|---|
| `installationId` (URL) | Required. 1–100 characters: letters, digits, `.`, `_`, `-`. |
| `platform` | `android` or `ios`. |
| `pushToken` | Required. The token from `FirebaseMessaging.getToken()`. Up to 512 characters, no spaces. |
| `locale` | `en` or `km`; default `en`. The language of the push text. |
| `appVersion` | Optional, up to 32 characters. |

`200`:

```json
{ "installationId": "3f0c…", "registeredAt": "2026-10-27T02:00:00Z" }
```

### When to call it

The call is idempotent, so sending it again is always safe. Call it:

1. **Right after sign-in**, once you have the access token.
2. **When FCM gives a new token** (`onTokenRefresh`).
3. **When the user changes the app language**, so pushes arrive in the new language.
4. **On app start** while signed in. Every start is fine; to save calls, send it only when the
   token or language changed since the last success.

### What the backend does with it

- **The registration belongs to the signed-in session.** Pushes go to this user until you
  unregister, the user signs out, or the session ends.
- **A shared phone is handled for you.** If another user signs in on the same phone and
  registers, the phone moves to the new user, and the old user's registration is removed. The
  same happens when one FCM token shows up on two installations.
- **Dead tokens are removed.** If FCM reports a token as no longer valid, the backend drops it.
  The next registration after sign-in or a token refresh adds it back.

### Errors

| Code | Meaning | What the app does |
|---|---|---|
| `400 VALIDATION_FAILED` | A bad field; each problem is under `error.details` | An app bug: fix the request. |
| `401` | The access token expired | Refresh the token, then retry. |
| `409 DEVICE_REGISTRATION_CONFLICT` | Two registrations from the same phone ran at once | Retry once. |
| `429` | More than 30 device calls per minute for this user | Wait and retry later. |

A failed registration should never block the user. Log it, and try again at the next app start.

## 2. Unregister at sign-out

```http
DELETE /api/v1/me/devices/{installationId}
Authorization: Bearer <accessToken>
```

`204 No Content`, also when nothing is registered.

Call it **before** `POST /api/v1/mobile/auth/logout`, while the access token is still valid.
If the app skips it (offline, crash), it's still safe: the backend also stops pushes when the
session ends. The inbox keeps every notification either way.

Keep the `installationId` after sign-out. It identifies the phone, not the user.

---

## 3. Handle a push

Each push has a visible `notification` (title and body, in the registered `locale`) and a
`data` map. All `data` values are strings:

| Key | Example | Use |
|---|---|---|
| `notificationId` | `0192f3a4-…` | The inbox item's id. Use it to mark the item read. |
| `type` | `planning.visits-assigned` | What happened. |
| `targetType` | `visit-plans` | Which screen to open. |
| `targetId` | `2026-10-28` | Which item on that screen. |

Delivery settings:
- **Android:** high priority, channel `default`.
- **iOS:** `apns-priority: 10` and the default sound.
- **Expiry:** a push that can't be delivered in time expires. The inbox still has it.

### Types sent today

| `type` | `targetType` / `targetId` | Text (en) |
|---|---|---|
| `planning.visits-assigned` | `visit-plans` / first date (`yyyy-MM-dd`) | "New visits assigned": "{count} visits from {first} to {last}." |
| `planning.visit-cancelled` | `visit-plans` / date | "Visit cancelled": "Your visit to {depotName} on {date} was removed." |
| `planning.daily-reminder` | `visit-plans` / today | "Today's visits": "You have {count} visits planned today." |

Planned for later: `customers.depot-draft-submitted`, `customers.depot-draft-approved` and
`customers.depot-draft-rejected`, all with `targetType` `depot-draft` and `targetId` the draft
id.

**Unknown types:** more types will be added later. When `type` or `targetType` is unknown, show
the push as it is, and on tap open the inbox. Never crash on it.

### What the app does

| App state | What to do |
|---|---|
| **In the foreground** | The system doesn't show the push itself. Show an in-app banner, or a local notification on channel `default`. Refresh the unread badge. |
| **Tapped, app in the background** | Open the screen for `targetType`/`targetId`, then mark the item read (section 4). |
| **Tapped, app closed** | Read the launch message (`getInitialMessage()`), then do the same. |

Opening `visit-plans` with a date shows that day's visits.

## 4. The inbox

### List

```http
GET /api/v1/me/notifications?limit=20&unreadOnly=false&cursor=
```

- **`limit`:** 1–50, default 20.
- **`unreadOnly=true`:** leaves out notifications already read.
- **`cursor`:** empty for the first page. For the next (older) page, pass the `nextCursor` value
  you got back.

`200`:

```json
{
  "items": [
    {
      "id": "0192f3a4-…",
      "type": "planning.visits-assigned",
      "title": { "en": "New visits assigned", "km": "…" },
      "body":  { "en": "12 visits from 22 Oct to 31 Oct.", "km": "…" },
      "link":  { "targetType": "visit-plans", "targetId": "2026-10-22" },
      "createdAt": "2026-10-21T02:00:00Z",
      "readAt": null
    }
  ],
  "nextCursor": "opaque-string-or-null"
}
```

- **Order:** newest first.
- **`nextCursor`:** `null` on the last page. Treat it as an opaque string; don't build or parse
  it.
- **Text:** pick `title.km` / `body.km` or `.en` by the app language. `km` falls back to English
  when no Khmer text was written.
- **`link`:** `null` when there's nothing to open.
- **`readAt`:** `null` while unread. Show unread items in bold.

### Unread badge

```http
GET /api/v1/me/notifications/unread-count
```

`200`: `{ "count": 3 }`. Refresh it on app start, when the app comes back to the foreground,
and when a push arrives.

### Mark one read

```http
POST /api/v1/me/notifications/{id}/read
```

`204`. Calling it again is safe; the first read time is kept. Another user's id, or an unknown
one, returns `404 NOTIFICATION_NOT_FOUND`; you can ignore that.

### Mark all read

```http
POST /api/v1/me/notifications/read-all
```

`200`: `{ "marked": 7 }`, the number that were unread.

---

## Flutter sketch

```dart
final installationId = await storage.getOrCreate('installationId', () => const Uuid().v4());
// Send the same installationId as deviceId in POST /api/v1/mobile/auth/login.

Future<void> registerDevice() async {
  await FirebaseMessaging.instance.requestPermission();
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;
  try {
    await api.put('/api/v1/me/devices/$installationId', {
      'platform': Platform.isIOS ? 'ios' : 'android',
      'pushToken': token,
      'locale': currentLocale,              // 'en' or 'km'
      'appVersion': packageInfo.version,
    });
  } catch (e) {
    log('device registration failed: $e'); // never block the user; retry next start
  }
}

// After sign-in, and on each start while signed in:
await registerDevice();
FirebaseMessaging.instance.onTokenRefresh.listen((_) => registerDevice());

// Taps:
FirebaseMessaging.onMessageOpenedApp.listen(openFromPush);
final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) openFromPush(initial);

// Foreground: show a banner and refresh the badge.
FirebaseMessaging.onMessage.listen((m) { showBanner(m); refreshUnreadCount(); });

Future<void> openFromPush(RemoteMessage m) async {
  final d = m.data;
  switch (d['targetType']) {
    case 'visit-plans': router.openVisitPlans(date: d['targetId']); break;
    case 'depot-draft': router.openDepotDraft(id: d['targetId']); break;
    default:            router.openInbox();
  }
  final id = d['notificationId'];
  if (id != null) await api.post('/api/v1/me/notifications/$id/read');
}

// Sign-out: unregister first, then log out.
await api.delete('/api/v1/me/devices/$installationId');
await api.post('/api/v1/mobile/auth/logout', {'refreshToken': refreshToken});
```

## Testing

1. Sign in on a real phone (emulators without Google Play services get no FCM token). Check that
   `PUT /me/devices/{installationId}` returns `200`.
2. Have an admin import a visit plan for this user. A `planning.visits-assigned` push arrives, and
   the item appears in `GET /me/notifications`.
3. Tap the push: the visit plan opens, and the unread count goes down by one.
4. Sign out: `DELETE` returns `204`. A new plan import sends **no** push to this phone, but the
   inbox still gets it.
5. Sign in on the same phone as a different user: only the new user gets pushes.

**Local backend:** with `PUSH_PROVIDER` unset (the default `Logging`), the API writes each push to
its log instead of sending it. The inbox still works. To get real pushes, the backend must run
with `PUSH_PROVIDER=Fcm` and the Firebase settings ([deploy/firebase/README.md](../../deploy/firebase/README.md)).

Questions about the API: the backend team. Always log `error.traceId`; it helps them find the
request.
