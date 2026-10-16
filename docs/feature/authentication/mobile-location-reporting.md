# Reporting device location from the mobile app

**Audience:** Flutter engineers · **Status:** Active · **Last updated:** 2026-09-18

How a handset puts itself on the portal's **Sessions & Devices** board.

---

## Three places you can send a position, and what each one is for

| Send it here | Writes | Use it for |
|---|---|---|
| Sign-in headers | `user_sessions` | Where the device was when the rep signed in |
| `POST /api/v1/mobile/devices/register` | `user_devices` | Where the installation was when it registered for push |
| `POST /api/v1/auth/sessions/current/location` | **both** | Keeping the position current while the app runs |

The board resolves a row's location **most specific first**: the session's own fix →
the push registration's fix → visit telemetry. So the third endpoint is the one that
matters day to day; the first two just stop a brand-new session showing blank.

> **Visit telemetry is not a substitute.** `POST /api/v1/mobile/visits/telemetry`
> writes `visit_location_samples`, which is keyed to a **person**. A rep signed in on a
> phone and a tablet shows the same point on both rows, which is exactly what the
> device board exists to separate. Keep sending telemetry — it feeds the live map — but
> it will not make the two devices distinguishable.

---

## 1. At sign-in — HTTP headers

The token endpoint reads device details from headers, so location travels the same way.
Add these to `POST /api/v1/auth/login` (or `/api/v1/mobile/auth/login`, `/connect/token` —
one code path serves all of them):

```http
X-Device-Id:        550e8400-e29b-41d4-a716-446655440000
X-Device-Name:      Pixel 8 - Sales
X-Device-Platform:  Android
X-Location-Lat:     11.556400
X-Location-Lng:     104.928200
X-Location-Accuracy: 12.5
X-Location-At:      2026-09-18T07:22:10Z
```

**Always invariant culture.** These are header text, and a device in a comma-decimal
locale that sends `11,5564` will be dropped. Format with `toStringAsFixed`, not with a
locale-aware formatter.

A malformed or missing value is ignored, never an error — sign-in must not fail because
the GPS was cold.

## 2. At push registration — JSON body

```http
POST /api/v1/mobile/devices/register
{
  "deviceId": "550e8400-...", "pushToken": "...", "platform": "Android",
  "latitude": 11.5564, "longitude": 104.9282,
  "locationAccuracyMeters": 12.5,
  "locationCapturedAt": "2026-09-18T07:22:10Z"
}
```

Unlike sign-in, a bad pair here **fails the registration** (422). The call is already
about describing the installation accurately, so silently dropping half of it would
hide a client bug.

## 3. While the app runs — the heartbeat

```http
POST /api/v1/auth/sessions/current/location
{
  "latitude": 11.5564, "longitude": 104.9282,
  "accuracyMeters": 12.5,
  "capturedAt": "2026-09-18T07:25:41Z"
}
→ 204 No Content
```

Needs only a valid access token. It is scoped to **the caller's own session** — there is
no id to pass and nothing to widen. It writes the session and, when the session carries
a `deviceId` matching a push registration, that row too, so both tables agree.

### Cadence

Match the telemetry rule already in the app: **no more than one report per 15 seconds,
and only after ~25 m of movement.** A handset parked in a shop for forty minutes should
send one position, not one hundred and sixty. Each call is a database write against a
live session; a per-second heartbeat from a fleet is a self-inflicted load problem.

Batching is not supported here and is not wanted — this endpoint answers "where is this
device now", not "where has it been". The breadcrumb trail is telemetry's job.

---

## Rules that apply everywhere

- **Never send (0, 0).** It is what the platform reports when it has *no* fix. All three
  endpoints reject it. Send nothing instead — the board shows "No location reported",
  which is honest, rather than a pin in the Gulf of Guinea.
- **`capturedAt` is when the handset took the fix**, not when you sent it. A device that
  buffered while offline should send the real capture time; the board labels markers
  with it rather than implying the rep is there this second.
- **Everything here is self-reported and unverified**, like every other device-supplied
  fact. It is useful for support and for seeing roughly where a fleet is. It is not
  evidence, and nothing is authorised on it.
- **Ask for permission at a moment that makes sense** — on first check-in, not on the
  login screen. A denial is remembered by the OS and is painful to reverse.

## Verifying it worked

```sql
select device_name, platform, last_latitude, last_longitude, last_location_at
from user_sessions where revoked_at is null order by last_location_at desc nulls last;
```

Then open `/user-management/sessions-devices` in the portal. A reporting device shows a
phone-shaped pin; the "Live tracking" pill is about the telemetry socket, and is a
separate thing from these three endpoints.
