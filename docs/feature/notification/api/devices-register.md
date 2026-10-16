# Device Registration — Mobile Integration Guide

**Purpose:** register a handset for push, and let a rep see what the platform believes about it.
**Scope:** `/api/v1/mobile/devices`. The notification inbox is [mobile.md](mobile.md).
**Status:** Active · **Last updated:** 2026-09-10

For the Flutter field sales app. Base URL `https://<host>/api/v1`.
Every request and response below was executed against a running server on 2026-09-10.

---

## Why this is the first thing to get right

Nothing else in the notification system matters until this works. A rep whose token is
stale looks **exactly** like a rep whose phone is switched off — the delivery log fills
with `UNREGISTERED` and nobody finds out until somebody asks why they missed an
approval.

> [!IMPORTANT]
> **Authentication only. No permission is required.**
> Telling the platform your push token changed is part of signing in, not a business
> capability — and the user whose token most needs updating is precisely the one it
> would be worst to lock out.

---

## 1. `POST /api/v1/mobile/devices/register`

Registers this installation, or refreshes its push token.

### When to call it

**On every launch, and on every FCM `onTokenRefresh`** — not only after login. FCM
rotates tokens without warning.

The call is **idempotent on `deviceId`**: the same `deviceId` updates the existing
registration in place rather than creating a second one. A registration that a
stale-token sweep deactivated is **revived** by this call.

### Request

```json
{
  "deviceId": "doc-sample-device-001",
  "pushToken": "fcm-sample-token-abc123",
  "platform": "Android",
  "deviceName": "Pixel 8",
  "appVersion": "1.4.2",
  "osVersion": "14",
  "locale": "km-KH",
  "timeZone": "Asia/Phnom_Penh",
  "pushPermissionGranted": true
}
```

| Field | Type | Required | Max | Notes |
|---|---|---|---|---|
| `deviceId` | string | **yes** | 128 | Your stable per-installation id. The idempotency key — keep it across launches and token rotations. |
| `pushToken` | string | **yes** | 512 | The FCM registration token. |
| `platform` | string | no | 32 | `Android`, `IOS` or `Web`, case-insensitive. Anything unrecognised — including omitted — stores as `Unknown`; it is never rejected. |
| `deviceName` | string | no | 128 | Label shown in the device registry. |
| `appVersion` | string | no | 32 | Build, for support triage. |
| `osVersion` | string | no | 64 | OS version. |
| `locale` | string | no | 16 | BCP 47 tag, e.g. `km-KH`. |
| `timeZone` | string | no | 64 | IANA zone. **Decides when the daily digest fires** — send the device's real zone, not UTC. |
| `pushPermissionGranted` | bool | no | — | Defaults to `true`. |

> [!IMPORTANT]
> **Send `pushPermissionGranted: false` when the rep declines the OS prompt.**
> The registration is kept — the installation still syncs the inbox — but it is
> excluded from the push audience. The delivery log then records `NO_DEVICE` once,
> instead of a run of failures against a handset that was never going to ring.

### Response — `200 OK`

```json
{
  "success": true,
  "message": "This device is registered for notifications.",
  "data": {
    "id": "01a08a0e-1e19-7a24-8365-c6ba238eed78",
    "deviceId": "doc-sample-device-001",
    "deviceName": "Pixel 8",
    "platform": "Android",
    "appVersion": "1.4.2",
    "osVersion": "14",
    "isActive": true,
    "pushPermissionGranted": true,
    "lastSeenAt": "2026-09-10T06:42:56.142882+00:00"
  },
  "metadata": null,
  "traceId": "0HNOF0O3FPATK:00000001",
  "timestamp": "2026-09-10T06:42:56.1736033+00:00"
}
```

`id` is the platform's identifier for the registration; `deviceId` is yours. Store
neither — send `deviceId` again next launch and the platform finds the row.

### Idempotency, verified

Re-registering the same `deviceId` with a rotated token and a new build:

```jsonc
// same id -> updated in place, not duplicated
"id": "01a08a0e-1e19-7a24-8365-c6ba238eed78"
"appVersion": "1.5.0"          // was 1.4.2
"osVersion": "15"              // was 14
"pushPermissionGranted": false // was true
```

### Errors

| Status | Code | Meaning |
|---|---|---|
| `400` | `General.Validation` | A required field is missing or over length. |
| `401` | — | No or expired access token. |

A missing `pushToken` answers:

```json
{ "status": 400, "errorCode": "General.Validation",
  "errors": { "PushToken": ["The PushToken field is required."] } }
```

---

## 2. `GET /api/v1/mobile/devices`

Lists the signed-in rep's registered installations, newest activity first.

Its job is answering the first question support would otherwise have to ask: *does the
platform still think this handset is live?*

### Response — `200 OK`

```json
{
  "success": true,
  "message": "Registered devices retrieved successfully.",
  "data": [
    {
      "id": "01a08a0e-1e19-7a24-8365-c6ba238eed78",
      "deviceId": "doc-sample-device-001",
      "deviceName": "Pixel 8",
      "platform": "Android",
      "appVersion": "1.5.0",
      "osVersion": "15",
      "isActive": true,
      "pushPermissionGranted": false,
      "lastSeenAt": "2026-09-10T06:43:07.181237+00:00"
    }
  ],
  "metadata": null,
  "traceId": "0HNOF0O3FPATM:00000001",
  "timestamp": "2026-09-10T06:43:07.2090063+00:00"
}
```

Not paged — a rep has a handful of installations, not a catalogue.

> [!NOTE]
> **Deactivated devices are included, deliberately.** A row with `isActive: false` is
> the answer to "why am I not getting notifications", so hiding it would remove the
> only evidence. Verified: after `DELETE`, the device still appears in this list with
> `isActive: false`.

Read the two flags together — they are different failures with different fixes:

| `isActive` | `pushPermissionGranted` | What it means |
|---|---|---|
| `true` | `true` | Healthy. |
| `true` | `false` | The rep declined the OS prompt. **Fix in phone settings** — the backend is fine. |
| `false` | either | Signed out here, or the token was swept as bad. **Fix by calling `register` again**, which revives it. |

---

## 3. `DELETE /api/v1/mobile/devices/{deviceId}`

Removes this installation from the push audience. Returns `204`, or `404` when the
`deviceId` is not one of yours.

> [!IMPORTANT]
> **Call it on sign-out, *before* discarding the access token.** Skipping it leaves the
> platform pushing one rep's notifications at a handset that has since been handed to
> somebody else. The call needs the token that is about to be thrown away.

It **deactivates rather than deletes**, because the delivery log references these rows
and a support question about a push sent last week must not hit a missing device.

---

## Client checklist

1. Generate a stable `deviceId` once per installation and persist it.
2. `POST /register` on **every launch**, after authentication.
3. `POST /register` again on every FCM `onTokenRefresh`.
4. `POST /register` with `pushPermissionGranted: false` when the OS prompt is declined,
   and again with `true` if the rep later grants it.
5. Send the device's real IANA `timeZone` — the digest schedule depends on it.
6. `DELETE /{deviceId}` on sign-out, **before** clearing the token.
7. Offer `GET /devices` on a diagnostics screen; the two flags above tell the rep
   whether the fix is theirs or support's.

## Verified

Executed against the running container on 2026-09-10:

| Check | Result |
|---|---|
| `POST /register`, new device | `200`, registration returned |
| `POST /register`, same `deviceId`, rotated token | `200`, **same `id`** — updated in place |
| Metadata refresh on re-register | `appVersion`, `osVersion`, `pushPermissionGranted` all updated |
| `GET /devices` | `200`, one row |
| `DELETE /{deviceId}` | `204` |
| `GET /devices` after delete | still listed, `isActive: false` |
| `POST /register` without `pushToken` | `400 General.Validation` |
| `POST /register` without a token | `401` |

The sample registration created for this document was removed afterwards.
