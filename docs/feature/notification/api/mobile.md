# Notifications — Mobile Integration Guide

**Purpose:** the notification surface consumed by the Flutter app — inbox, badges, push, actions, preferences.
**Scope:** `/api/v1/mobile/notifications` and `/api/v1/mobile/devices`. Admin is [admin.md](admin.md).
**Status:** Active · **Last updated:** 2026-08-27

**Audience:** Flutter engineers building the SteelForce Sales Rep app
**Backend:** ISI SteelForce 360 · `ISI.Api` v1
**Status:** Phase 1 (Foundation) complete — inbox, device registry, preferences, push, delivery log
**Companion specs:** [Notification — Functional requirements](../../../requirement/notification/functional-requirements.md) · [Notification — Business requirements](../../../requirement/notification/business-requirements.md)

---

## 1. The one thing to understand first

> **The inbox is the notification. Push is only an accelerator.**

Every notification the platform raises is written to the database *before* anything is
sent to Firebase. Push then tries to wake the handset — and fails routinely, for
reasons neither you nor the backend control:

- the phone is off, flat, or in a coverage hole
- the rep declined the OS notification permission
- an OEM battery optimiser (Xiaomi, Oppo, Vivo, Huawei) killed the app
- the FCM token rotated and the app has not re-registered yet
- Google is having a bad afternoon

**Design the app so that a dropped push costs nothing.** If your only path to a new
route assignment is `FirebaseMessaging.onMessage`, reps *will* miss work. Pull the
inbox on every foreground and after every sync; treat push purely as "check now
instead of in five minutes".

```
Backend                          Device
───────                          ──────
Business event
   │
   ├──▶ Notification row  ──────────────────▶  GET /notifications      ← GUARANTEED
   │    (the system of record)                 (poll / catch-up)
   │
   └──▶ FCM ──────────────────────────────▶  onMessage / onMessageOpenedApp
        (best effort, may never arrive)        ← ACCELERATOR ONLY
```

---

## 2. Base URL, auth and envelope

| | |
|---|---|
| Base | `{host}/api/v1/mobile` |
| Auth | `Authorization: Bearer {access_token}` on every call |
| Language | `Accept-Language: km-KH` or `en-US` — the `message` field comes back localised |
| Content type | `application/json` |

All mobile routes return the standard mobile envelope:

```json
{
  "success": true,
  "message": "Notifications retrieved successfully.",
  "data": { },
  "metadata": { },
  "traceId": "0HN7...",
  "timestamp": "2026-08-25T08:12:04.512Z"
}
```

Failures are **not** wrapped. They are RFC 9457 problem documents:

```json
{
  "type": "https://docs.isigroup.com.kh/errors/Notification.AlreadyResolved",
  "title": "The request conflicts with the current state of the resource.",
  "status": 409,
  "detail": "This notification has already been dealt with.",
  "errorCode": "Notification.AlreadyResolved",
  "correlationId": "0HN7..."
}
```

**Branch on `errorCode`, never on `detail`.** `detail` is English developer text;
`errorCode` is a stable contract you localise from on the device.

> The same endpoints also exist without the `/mobile` segment
> (`/api/v1/notifications`, `/api/v1/devices`, `/api/v1/users/me/notification-preferences`)
> for the admin portal. Same handlers, different envelope — use the `/mobile` ones.

---

## 3. Endpoint reference

### Devices

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/mobile/devices/register` | Register or refresh this installation's FCM token |
| `GET` | `/mobile/devices` | List the rep's registered installations |
| `DELETE` | `/mobile/devices/{deviceId}` | Deregister on sign-out |

### Inbox

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/mobile/notifications` | List / catch-up, paged and filtered |
| `GET` | `/mobile/notifications/unread-count` | Badge figures |
| `PATCH` | `/mobile/notifications/{id}/read` | Mark one read |
| `PATCH` | `/mobile/notifications/read-all` | Mark all read (optionally one category) |
| `POST` | `/mobile/notifications/{id}/action` | Record that the rep **acted** |
| `DELETE` | `/mobile/notifications/{id}` | Dismiss |

### Preferences

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/mobile/notifications/preferences` | Read the settings screen |
| `PUT` | `/mobile/notifications/preferences` | Replace the settings screen |

All require an authenticated user. The inbox and preference routes additionally
require the `notifications.read` permission, which every seeded role holds. Device
registration requires **only** authentication — a rep who cannot read notifications
must still be able to tell the platform their token changed.

---

## 4. Device registration

### 4.1 When to call it

Call `POST /mobile/devices/register`:

1. **After every successful login.**
2. **On every app launch** — not only the first. FCM rotates tokens silently.
3. **From `FirebaseMessaging.instance.onTokenRefresh`.**
4. **Whenever the OS notification permission changes** (send the new
   `pushPermissionGranted`).

It is idempotent on `deviceId`, so calling it more often than necessary costs one
cheap round trip and nothing else. Calling it *less* often is how a rep silently
stops receiving anything.

### 4.2 Request

```http
POST /api/v1/mobile/devices/register
Authorization: Bearer eyJhbGciOi...
Content-Type: application/json

{
  "deviceId": "b8f2c1a4-9d3e-4f77-a1b2-installation-id",
  "pushToken": "fEo7x...:APA91bH...",
  "platform": "Android",
  "deviceName": "Pixel 8 — Dara",
  "appVersion": "1.4.2+310",
  "osVersion": "Android 15",
  "locale": "km-KH",
  "timeZone": "Asia/Phnom_Penh",
  "pushPermissionGranted": true
}
```

| Field | Required | Notes |
|---|---|---|
| `deviceId` | ✅ | **Stable per installation.** Survives restarts; may change on reinstall. This is the upsert key — get it wrong and every launch creates a duplicate row. |
| `pushToken` | ✅ | From `FirebaseMessaging.instance.getToken()` |
| `platform` | | `Android`, `IOS` or `Web`. Unrecognised values are stored as `Unknown` rather than rejected. |
| `deviceName` | | Shown to support in the device registry |
| `appVersion` | | Used by the version-policy check |
| `locale` | | BCP 47. Decides which language future notifications render in. |
| `timeZone` | | **IANA zone.** Quiet hours and digests are wall-clock facts — without this the backend has to assume UTC and a rep's 22:00 quiet window starts at 05:00 local. |
| `pushPermissionGranted` | | Send `false` when the rep declined. The registration is kept (the inbox still syncs) but excluded from the push audience, so the delivery log reads `NO_DEVICE` instead of a run of failures. |

**Do not use the FCM token as `deviceId`.** Tokens rotate; installations do not. Use
`device_info_plus` (`androidId` / `identifierForVendor`) or a UUID you generate once
and persist in secure storage.

### 4.3 Response

```json
{
  "success": true,
  "message": "This device is registered for notifications.",
  "data": {
    "id": "0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5b",
    "deviceId": "b8f2c1a4-9d3e-4f77-a1b2-installation-id",
    "deviceName": "Pixel 8 — Dara",
    "platform": "Android",
    "appVersion": "1.4.2+310",
    "osVersion": "Android 15",
    "isActive": true,
    "pushPermissionGranted": true,
    "lastSeenAt": "2026-08-25T08:12:04Z"
  },
  "traceId": "0HN7...",
  "timestamp": "2026-08-25T08:12:04.512Z"
}
```

A registration the backend previously deactivated (because FCM reported the token
dead) is **revived** by this call. A rep never needs an administrator to start
receiving notifications again.

### 4.4 Sign-out

```http
DELETE /api/v1/mobile/devices/b8f2c1a4-9d3e-4f77-a1b2-installation-id
Authorization: Bearer eyJhbGciOi...
```

→ `204 No Content`

**Call this before discarding the access token.** Skipping it leaves the platform
pushing one rep's notifications at a handset that has since been handed to somebody
else.

### 4.5 Flutter

```dart
Future<void> syncPushToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token == null) return;

  final settings = await FirebaseMessaging.instance.getNotificationSettings();

  await api.post('/mobile/devices/register', {
    'deviceId': await installationId(),          // persisted UUID, NOT the token
    'pushToken': token,
    'platform': Platform.isIOS ? 'IOS' : 'Android',
    'deviceName': await deviceLabel(),
    'appVersion': (await PackageInfo.fromPlatform()).version,
    'osVersion': await osVersion(),
    'locale': Platform.localeName,
    'timeZone': await FlutterTimezone.getLocalTimezone(),
    'pushPermissionGranted':
        settings.authorizationStatus == AuthorizationStatus.authorized,
  });
}

// Wire it up once, at startup.
FirebaseMessaging.instance.onTokenRefresh.listen((_) => syncPushToken());
```

---

## 5. The notification object

Every inbox response returns this shape. Field names are `snake_case` — they follow
the published specification rather than the rest of the API's `camelCase`, because
this object is quoted verbatim in the spec and in the FCM payload.

```json
{
  "notification_id": "0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5b",
  "event_code": "ROUTE.ASSIGNED",
  "category": "ASSIGNMENT",
  "priority": "P2",
  "title": "New route assigned — Wed, 26 Aug",
  "body": "North Phnom Penh R3: 12 stops from 08:00. Tap to review and confirm.",
  "image_url": null,
  "deep_link": "app://routes/0198f2b0-1111-7000-8000-000000000001",
  "web_link": "/routes/0198f2b0-1111-7000-8000-000000000001",
  "requires_ack": true,
  "expires_at": null,
  "group_key": "Assignment:0198f2b0-1111-7000-8000-000000000001",
  "badge": 3,
  "actions": [
    { "id": "view", "label": "View Route", "type": "deeplink",
      "endpoint": null, "method": null, "destructive": false },
    { "id": "ack",  "label": "Acknowledge", "type": "api_call",
      "endpoint": "/api/v1/routes/0198f2b0.../acknowledge", "method": "POST",
      "destructive": false }
  ],
  "data": {
    "entity_type": "route",
    "entity_id": "0198f2b0-1111-7000-8000-000000000001",
    "route_date": "2026-08-26",
    "stop_count": "12"
  },
  "state": "unread",
  "created_at": "2026-08-25T08:12:04Z",
  "delivered_at": "2026-08-25T08:12:04Z",
  "read_at": null,
  "actioned_at": null
}
```

### 5.1 `state` — the lifecycle

```
                    ┌──────────┐  read     ┌────────┐  acted    ┌────────────┐
   created ────────▶│  unread  │──────────▶│  read  │──────────▶│  actioned  │
                    └────┬─────┘           └───┬────┘           └────────────┘
                         │                     │
              ┌──────────┼─────────────────────┤
              ▼          ▼                     ▼
       ┌───────────┐ ┌─────────┐    ┌────────────────────┐
       │ dismissed │ │ expired │    │ resolved_elsewhere │
       └───────────┘ └─────────┘    └────────────────────┘
```

| `state` | Meaning | Render as |
|---|---|---|
| `unread` | Not opened | Bold, unread dot |
| `read` | Opened | Normal weight |
| `actioned` | The rep did the thing | Normal, with a tick |
| `dismissed` | Swiped away | History only |
| `expired` | Its moment passed unread | History, greyed, "This is no longer current" |
| `resolved_elsewhere` | Somebody else decided first | History, greyed, "Already actioned by someone else" |

**Nothing is ever deleted.** Every one of these stays in the inbox history with an
explanatory subtitle, because a rep who half-remembers being told something has to be
able to find it.

### 5.2 `priority` — how loud

| Tier | Meaning | Quiet hours | Opt-out | Push |
|---|---|---|---|---|
| `P1` | Critical | **Bypassed** | **Bypassed** | Yes, high priority, alert tone |
| `P2` | High | Deferred to window end | Honoured | Yes, heads-up banner |
| `P3` | Normal | Deferred to window end | Honoured | Yes, silent-capable |
| `P4` | Low | Never pushed | Honoured | **Inbox only** |

A P4 notification will *never* arrive as a push. If your only render path is the FCM
callback, every digest and every "route completed" confirmation is invisible.

### 5.3 `category` — the ten groupings

`ASSIGNMENT` · `QUOTE` · `ORDER` · `FINANCE` · `KPI` · `APPROVAL` · `ACCOUNT` ·
`SYSTEM` · `ANNOUNCE` · `SECURITY`

These map one-to-one onto your Android notification channels and onto the filter
chips in the inbox. Do not hard-code the list in the UI — read it from
`GET /mobile/notifications/preferences`, which returns every category with its label
and lock state.

### 5.4 `requires_ack` and `badge`

- `requires_ack: true` → the item belongs in the **Action needed** tab, is pinned to
  the top, and **cannot be dismissed** (a `DELETE` answers 409). It stays outstanding
  until you `POST /action`.
- `badge` is the server's authoritative count of **outstanding actionable items** —
  *not* unread items. Set the app-icon badge from it and nothing else. A badge that
  counts unread mail says "you have mail"; one that counts outstanding actions says
  "you have work", and only the second earns an interruption.

---

## 6. Listing and catch-up

```http
GET /api/v1/mobile/notifications?pageNumber=1&pageSize=25&state=unread
Authorization: Bearer eyJhbGciOi...
```

| Query | Values |
|---|---|
| `pageNumber`, `pageSize` | 1-based; `pageSize` clamped to 200, default 25 |
| `since` | ISO-8601. Only notifications created **after** this instant. |
| `state` | `unread` · `read` · `actioned` · `dismissed` · `expired` · `resolved_elsewhere` |
| `category` | `ASSIGNMENT`, `ORDER`, … |
| `priority` | `P1`–`P4` |
| `actionRequired` | `true` for the **Action needed** tab |

Response:

```json
{
  "success": true,
  "message": "Notifications retrieved successfully.",
  "data": [ { "notification_id": "…" } ],
  "metadata": {
    "page": 1,
    "pageSize": 25,
    "totalRecords": 84,
    "totalPages": 4,
    "hasNextPage": true,
    "hasPreviousPage": false,
    "syncTimestamp": "2026-08-25T08:12:04.512Z",
    "isDeltaSync": false
  },
  "traceId": "0HN7...",
  "timestamp": "2026-08-25T08:12:04.512Z"
}
```

### 6.1 The catch-up loop

> **Store `metadata.syncTimestamp`. Send it back as `since`. Never send the device
> clock.**

A handset running ten minutes fast that sends its own `DateTime.now()` will ask for
"changes since the future" and silently receive nothing, for ever, with no error to
notice. This is the single most common way an offline-first notification client
breaks.

```dart
Future<void> catchUp() async {
  final cursor = await prefs.getString('notif_cursor');   // null on first run

  final res = await api.get('/mobile/notifications', query: {
    if (cursor != null) 'since': cursor,
    'pageSize': '100',
  });

  for (final json in res.data) {
    // Idempotent upsert keyed on notification_id — a catch-up that overlaps a
    // push already handled must not produce a duplicate row locally.
    await db.upsertNotification(NotificationDto.fromJson(json));
  }

  await prefs.setString('notif_cursor', res.metadata.syncTimestamp);
}
```

Call it on app start, on foreground, on pull-to-refresh, and on reconnect.

### 6.2 Ordering

Always newest first. There is no `sort` parameter, deliberately — an inbox has one
useful order and the database index behind it is built for exactly that.

---

## 7. Badge counts

```http
GET /api/v1/mobile/notifications/unread-count
```

```json
{
  "success": true,
  "message": "Notification counts retrieved successfully.",
  "data": {
    "unread": 12,
    "action_required": 3,
    "by_category": { "ASSIGNMENT": 2, "ORDER": 7, "KPI": 3 },
    "sync_timestamp": "2026-08-25T08:12:04.512Z"
  }
}
```

- **App-icon badge** ← `action_required`
- **Bell / inbox tab badge** ← `unread`
- **Bottom-nav section badges** ← `by_category`

Reconcile against these on every sync rather than incrementing locally. A local
counter drifts the first time a push is dropped, and a badge nobody trusts is a badge
everybody ignores.

Cheap enough to call on every foreground.

---

## 8. Read, act, dismiss — and the difference

### 8.1 Mark read

```http
PATCH /api/v1/mobile/notifications/{id}/read
```
→ `204 No Content`

Idempotent. Safe to replay from an offline queue — the first read timestamp wins,
because that is what the time-to-open metric measures.

### 8.2 Mark all read

```http
PATCH /api/v1/mobile/notifications/read-all?category=ORDER
```

```json
{ "success": true, "message": "All notifications marked as read.", "data": 7 }
```

Pass `category` when the inbox is filtered, so the button clears what the rep can see
rather than what they cannot.

### 8.3 Record an action

```http
POST /api/v1/mobile/notifications/{id}/action
Content-Type: application/json

{ "actionId": "ack", "occurredAt": "2026-08-25T08:15:22Z" }
```
→ `204 No Content`

Both fields are optional. Omit `actionId` when the rep acted inside the record rather
than from a notification button. `occurredAt` is advisory — used only for ordering a
replayed offline queue; the server records its own clock.

> ### Reading is not acting
>
> A route assignment that has been **read** still counts against the badge and still
> escalates to a supervisor if it is never acknowledged. Only `POST /action` closes
> it. Wiring "user scrolled past it" to `/read` is correct; wiring it to `/action`
> silently breaks the escalation chain that the whole assignment flow depends on.

**409 `Notification.AlreadyResolved`** means somebody else got there first — another
approver decided, or the route was reassigned while the handset was offline. Show the
current state; **do not retry**. Replaying an action the server already recorded
answers `204`, so a queue draining after reconnect never stalls on its own success.

### 8.4 Dismiss

```http
DELETE /api/v1/mobile/notifications/{id}
```
→ `204 No Content`, or **409** when `requires_ack` is true.

A state, not a deletion. The item stays in history.

### 8.5 Offline action queue

```dart
Future<void> drainActionQueue() async {
  for (final queued in await db.pendingActions()) {
    try {
      await api.post('/mobile/notifications/${queued.id}/action', {
        'actionId': queued.actionId,
        'occurredAt': queued.occurredAt.toIso8601String(),
      });
      await db.removeQueued(queued);
    } on ApiException catch (e) {
      if (e.errorCode == 'Notification.AlreadyResolved') {
        // Somebody else decided. Drop it and tell the rep what happened —
        // §13.6 requires a clear resolution message, never a silent discard.
        await db.removeQueued(queued);
        await localNotifications.show(
          'That item was already handled',
          'Someone else actioned it while you were offline.',
        );
      } else if (e.isTransient) {
        break;                    // keep the queue, retry on next reconnect
      } else {
        await db.removeQueued(queued);
      }
    }
  }
}
```

---

## 9. The FCM payload

### 9.1 What arrives

Both a `notification` block (so the OS renders it when the app is backgrounded) and a
`data` block (so you can route on it):

```json
{
  "notification": {
    "title": "New route assigned — Wed, 26 Aug",
    "body": "North Phnom Penh R3: 12 stops from 08:00. Tap to review and confirm."
  },
  "data": {
    "notification_id": "0198f2c1-9d3e-7f77-a1b2-4c9d8e7f6a5b",
    "event_code": "ROUTE.ASSIGNED",
    "type": "ROUTE_ASSIGNED",
    "category": "ASSIGNMENT",
    "priority": "P2",
    "deep_link": "app://routes/0198f2b0-1111-7000-8000-000000000001",
    "action": "app://routes/0198f2b0-1111-7000-8000-000000000001",
    "entity_type": "route",
    "referenceType": "ROUTE",
    "entity_id": "0198f2b0-1111-7000-8000-000000000001",
    "referenceId": "0198f2b0-1111-7000-8000-000000000001",
    "route_date": "2026-08-26",
    "stop_count": "12"
  }
}
```

**Two naming conventions on purpose.** The canonical spec fields
(`event_code`, `entity_type`, `entity_id`, `deep_link`) sit alongside the mobile
shorthand (`type`, `referenceType`, `referenceId`, `action`). `type` is `event_code`
with dots flattened to underscores. Pick one set and use it consistently; the
duplication exists so neither document is wrong.

> ⚠️ **Every FCM `data` value is a string.** `"stop_count": "12"`, not `12`. Parse
> accordingly.

### 9.2 What is deliberately *not* in it

No prices, no credit limits, no depot phone numbers. A push renders on a locked
screen in front of whoever is holding the phone. The full record is one authenticated
tap away, which is where it belongs.

### 9.3 Android channels

The backend sets `android.notification.channel_id` per category. **Create these
channels at app startup** or Android drops the notification into a default channel and
the rep loses per-category OS control:

| Channel id | Category | Importance |
|---|---|---|
| `assignment` | `ASSIGNMENT` | HIGH |
| `quotes` | `QUOTE` | DEFAULT |
| `orders` | `ORDER` | DEFAULT |
| `finance` | `FINANCE` | HIGH |
| `approvals` | `APPROVAL` | HIGH |
| `kpi` | `KPI` | LOW |
| `account` | `ACCOUNT` | DEFAULT |
| `system` | `SYSTEM` | DEFAULT |
| `announcements` | `ANNOUNCE` | DEFAULT |
| `security` | `SECURITY` | HIGH |

Also set on Android: `collapse_key` (a burst of route edits replaces itself rather
than stacking), `tag` (shade grouping) and `notification_count` (the badge).

On iOS: `apns-priority` 10 for P1/P2 else 5, `apns-expiration` from the tier's TTL,
`apns-collapse-id`, plus `aps.badge` and `aps.thread-id`.

### 9.4 Time-to-live

| Tier | TTL |
|---|---|
| P1 | 24 h |
| P2 | 12 h |
| P3 | 6 h |
| P4 | not pushed |

Past the TTL, FCM discards rather than waking somebody about a route that started six
hours ago. **The inbox copy is unaffected** — this is exactly why the catch-up call
matters.

---

## 10. Handling push by app state

| State | What to do |
|---|---|
| **Foreground** | Suppress the OS banner. Show an in-app snackbar. Live-update any open screen showing that record. Refresh the badge. |
| **Background** | OS renders it. On tap → `onMessageOpenedApp` → navigate to `deep_link`. |
| **Terminated** | OS renders it. On tap → cold start → `getInitialMessage()` → authenticate → navigate. **If the session expired, preserve the deep link across login.** |
| **Data-only** | Trigger a background sync. No user-visible alert. |

```dart
void wireNotificationRouting() {
  // Foreground: no OS banner, in-app card instead.
  FirebaseMessaging.onMessage.listen((m) {
    inbox.upsertFromPush(m.data);
    badges.refresh();
    showInAppCard(m.notification?.title, m.notification?.body, m.data);
  });

  // Background → tapped.
  FirebaseMessaging.onMessageOpenedApp.listen(_route);

  // Terminated → tapped. MUST be checked at startup or the tap is swallowed.
  FirebaseMessaging.instance.getInitialMessage().then((m) {
    if (m != null) _route(m);
  });
}

void _route(RemoteMessage m) {
  final link = m.data['deep_link'];
  if (link == null) return;

  if (!session.isValid) {
    pendingDeepLink = link;      // resume after login — do NOT drop it
    router.go('/login');
    return;
  }

  router.go(toAppRoute(link));   // app://routes/{id} → /routes/{id}
}
```

---

## 11. Deep links

| Destination | Mobile URI |
|---|---|
| Route detail | `app://routes/{routeId}` |
| Stop detail | `app://routes/{routeId}/stops/{stopId}` |
| Today's plan | `app://today` |
| Quotation | `app://quotations/{quoteId}` |
| Order | `app://orders/{orderId}` (`?tab=credit` for credit holds) |
| Approvals queue | `app://approvals?filter={type}` |
| Depot | `app://depots/{depotId}` |
| Dashboard / KPI | `app://dashboard?period={period}` |
| Inbox | `app://notifications` |
| Settings | `app://settings/notifications` |

**The backend builds these; do not assemble your own from `entity_type` and
`entity_id`.** Three clients deriving the same URI is three chances for one of them to
get it subtly wrong, and the failure — a notification that opens the wrong screen — is
invisible until a rep reports it.

An event that points at no single record falls back to `app://notifications` rather
than emitting a URI you cannot route. Handle that gracefully.

---

## 12. Inline action buttons

```json
"actions": [
  { "id": "view", "label": "View Route", "type": "deeplink",
    "endpoint": null, "method": null, "destructive": false },
  { "id": "ack", "label": "Acknowledge", "type": "api_call",
    "endpoint": "/api/v1/routes/{id}/acknowledge", "method": "POST",
    "destructive": false }
]
```

| `type` | What to do |
|---|---|
| `deeplink` | Navigate to the notification's `deep_link` |
| `api_call` | Call `method endpoint` with the bearer token, then `POST /action` with this `actionId` |
| `dismiss` | Close it; call `DELETE /{id}` |

`destructive: true` → confirm before proceeding. Rejecting a quotation from a lock
screen is one mis-tap from a decision nobody meant to make.

At most three buttons. Ignore any beyond that.

---

## 13. Preferences

```http
GET /api/v1/mobile/notifications/preferences
```

```json
{
  "success": true,
  "message": "Notification settings retrieved successfully.",
  "data": {
    "quietHoursStart": "20:00:00",
    "quietHoursEnd": "07:00:00",
    "quietDays": [],
    "digestTime": "18:00:00",
    "language": "km-KH",
    "categories": [
      { "category": "ASSIGNMENT", "displayName": "Assignments & Schedule",
        "isEnabled": true, "pushEnabled": true, "isLocked": true },
      { "category": "KPI", "displayName": "Performance & KPI",
        "isEnabled": true, "pushEnabled": false, "isLocked": false }
    ]
  }
}
```

**Build the settings screen from `categories`, not from a hard-coded list.** A
category added server-side stays invisible until the app is rebuilt otherwise.

- `isLocked: true` → render the toggle disabled with a tooltip explaining why. Do
  **not** hide the row; a rep should be able to see what they are receiving even when
  they cannot stop it. Locked today: `ASSIGNMENT`, `QUOTE`, `ORDER`, `FINANCE`,
  `APPROVAL`, `SYSTEM`, `SECURITY`.
- `pushEnabled: false` with `isEnabled: true` → keep it, but inbox only.
- `quietDays: []` means **every day**, not "no days".
- A window that wraps midnight (`20:00`→`07:00`) is normal and handled.
- A user who has never opened this screen still gets a full response with everything
  on. Absence of a record means "everything", not "nothing".

### Saving

```http
PUT /api/v1/mobile/notifications/preferences
Content-Type: application/json

{
  "quietHoursStart": "20:00:00",
  "quietHoursEnd": "07:00:00",
  "quietDays": ["Saturday", "Sunday"],
  "digestTime": "18:00:00",
  "language": "km-KH",
  "categories": [
    { "category": "KPI", "isEnabled": true, "pushEnabled": false }
  ]
}
```

A whole-document update; categories you omit are left alone. Send
`quietHoursStart`/`quietHoursEnd` **together or not at all** — one without the other
answers `400 Notification.QuietHoursIncomplete`.

Muting a locked category answers `422 Notification.CategoryNotMutable` rather than
silently ignoring the change, so a toggle never snaps back with no explanation.

Preferences are stored server-side and follow the rep across devices.

**Quiet hours defer, they never drop.** A P2 raised at 22:00 is delivered when the
window ends. P1 ignores the window entirely — a route cancelled at midnight for a
06:00 start has to wake somebody.

---

## 14. Permission priming

Do **not** request the OS push permission on first launch. iOS gives you one prompt
ever; spending it on a cold user is how an app ends up permanently silent.

```
Login
  ↓
Onboarding
  ↓
Rep sees their first route          ← now they understand why it matters
  ↓
In-app explainer card:
  "Get notified the moment a route, order, or approval needs you."
  [ Enable ]  [ Not now ]
  ↓ Enable
OS prompt
  ↓ Allowed
POST /mobile/devices/register  (pushPermissionGranted: true)
```

If declined: register anyway with `pushPermissionGranted: false`, show an unobtrusive
banner in the inbox linking to system settings, and re-show the explainer at most once
every 14 days.

The inbox works perfectly without the permission. That is the whole point of the
design.

---

## 15. Error codes

| `errorCode` | HTTP | What it means | What to do |
|---|---|---|---|
| `Notification.NotFound` | 404 | Not yours, or does not exist | Remove from the local cache |
| `Notification.AlreadyResolved` | 409 | Actioned, dismissed, expired, or decided by someone else | Refresh, tell the rep, **do not retry** |
| `Notification.ActionNotOffered` | 400 | `actionId` is not one of this notification's buttons | Client bug |
| `Notification.AuthenticationRequired` | 401 | No signed-in user | Refresh the token, then retry |
| `Notification.DeviceIdRequired` | 400 | `deviceId` missing | Client bug |
| `Notification.PushTokenRequired` | 400 | `pushToken` missing | Retry `getToken()` |
| `Notification.DeviceNotFound` | 404 | Not one of yours | Treat sign-out as done |
| `Notification.CategoryNotMutable` | 422 | Tried to mute a locked category | Show why; keep it on |
| `Notification.QuietHoursIncomplete` | 400 | Start without end, or vice versa | Send both or neither |

Localise from `errorCode`. `detail` is English developer text.

---

## 16. Integration checklist

**Startup**
- [ ] Android notification channels created for all ten categories
- [ ] `getInitialMessage()` checked (terminated-state taps are otherwise swallowed)
- [ ] `onTokenRefresh` wired to `POST /mobile/devices/register`
- [ ] Catch-up call runs on start and on foreground

**Auth**
- [ ] Register device after login
- [ ] Deregister **before** discarding the token on sign-out
- [ ] Deep link preserved across an expired-session login

**Inbox**
- [ ] Upserts keyed on `notification_id` (catch-up overlaps a push safely)
- [ ] Cursor is `metadata.syncTimestamp`, **never** the device clock
- [ ] App-icon badge from `action_required`, not `unread`
- [ ] "Action needed" tab pinned; `requires_ack` items not swipeable
- [ ] `/read` and `/action` wired to genuinely different gestures
- [ ] Offline action queue handles 409 with a user-visible explanation

**Settings**
- [ ] Categories rendered from the API, not hard-coded
- [ ] Locked categories shown disabled, not hidden
- [ ] IANA `timeZone` sent at registration

**Resilience**
- [ ] App fully usable with push permission denied
- [ ] Tested against OEM battery killers (Xiaomi, Oppo, Vivo, Huawei)
- [ ] Tested after force-stop and after reboot

---

## 17. Quick reference

```
POST   /api/v1/mobile/devices/register
GET    /api/v1/mobile/devices
DELETE /api/v1/mobile/devices/{deviceId}

GET    /api/v1/mobile/notifications?since=&state=&category=&priority=&actionRequired=
GET    /api/v1/mobile/notifications/unread-count
PATCH  /api/v1/mobile/notifications/{id}/read
PATCH  /api/v1/mobile/notifications/read-all?category=
POST   /api/v1/mobile/notifications/{id}/action
DELETE /api/v1/mobile/notifications/{id}

GET    /api/v1/mobile/notifications/preferences
PUT    /api/v1/mobile/notifications/preferences
```

Interactive docs: `{host}/scalar` → **Mobile Application › Notifications**.

---

## 18. Open items

| Item | Status |
|---|---|
| Inbox, devices, preferences, push, delivery log | ✅ Phase 1 complete |
| Business events (route assigned, quote approved, …) | ⏳ Phase 2+. The event catalogue and deep links are published now so you can build against them; nothing raises them yet. |
| Email / SMS / WebSocket channels | ⏳ Adapters not registered. Rows are queued and visible in the delivery log. |
| Rule builder, template manager, analytics | ⏳ Phase 4–5 |
| `ROUTE.ASSIGNED` vs `ROUTE_ASSIGNED` | ⚠️ Both shipped in the FCM payload (`event_code` and `type`) pending sign-off. |
