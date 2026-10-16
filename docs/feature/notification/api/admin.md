# Notification API — Admin

**Purpose:** the notification endpoints consumed by the Admin Portal and the Head of
Sales portal.
**Scope:** `/api/v1/admin/notifications`, plus the shared inbox, device and
preference routes that portals also use. The Flutter surface is
[mobile.md](mobile.md).
**Status:** Active · **Last updated:** 2026-08-27

**Verified against** `src/ISI.Api/Controllers/Notifications/`, 2026-08-27.

---

## Conventions

**Authentication** — Bearer token on every endpoint. None is anonymous.

**Response envelope** — `ApiResponse<T>`.

**Errors** — RFC 9457 ProblemDetails with stable `Notification.*` codes.

**Status codes** — `200` read/update · `202`/`200` broadcast accepted ·
`400` validation · `401` unauthenticated · `403` missing permission ·
`404` not found · `502` Firebase unavailable.

---

## Endpoint summary

| Method | Path | Permission | Audience |
|---|---|---|---|
| POST | `/api/v1/admin/notifications/broadcast` | `notifications.send` | Admin · HeadOfSales |
| POST | `/api/v1/admin/notifications/test-push` | `notifications.send` | Admin · HeadOfSales |
| GET | `/api/v1/admin/notifications/logs` | `notifications.send` | Admin · HeadOfSales |
| GET | `/api/v1/notifications` | `notifications.read` | All clients |
| GET | `/api/v1/notifications/unread-count` | `notifications.read` | All clients |
| GET | `/api/v1/notifications/{notificationId}` | `notifications.read` | All clients |
| POST | `/api/v1/notifications/{notificationId}/read` | `notifications.read` | All clients |
| POST | `/api/v1/notifications/read-all` | `notifications.read` | All clients |
| POST | `/api/v1/notifications/{notificationId}/action` | `notifications.read` | All clients |
| DELETE | `/api/v1/notifications/{notificationId}` | `notifications.read` | All clients |
| POST | `/api/v1/devices` | — (authenticated) | All clients |
| GET | `/api/v1/devices` | — (authenticated) | All clients |
| DELETE | `/api/v1/devices/{deviceId}` | — (authenticated) | All clients |
| GET | `/api/v1/users/me/notification-preferences` | — (authenticated) | All clients |
| PUT | `/api/v1/users/me/notification-preferences` | — (authenticated) | All clients |

`{notificationId}` is constrained to `:guid`. `{deviceId}` is not.

> The device and preference endpoints carry **no `[HasPermission]`** — they are
> authenticated but not permission-gated, and are scoped to the caller in the
> handler. See [security.md](../security.md#three-endpoint-groups-carry-no-permission-attribute).

---

## POST /api/v1/admin/notifications/broadcast

Raises a notification for a set of recipients.

**Permission:** `notifications.send` · **Audience:** Admin · HeadOfSales

This is the **privileged operation** in the feature — it can reach every user on
the platform.

**Validation** — `BroadcastNotificationCommandValidator`. The event type must exist
in `NotificationEventCatalog`; a deep-link destination must exist in
`DeepLinkRegistry`.

**Business rules**

- An inbox row is written for every recipient **unconditionally**.
- Per-recipient preferences then decide Push / Email / Sms / Web. A disabled channel
  produces a `Skipped` delivery row, not an omission.
- **Priority does not override a preference.** A high-priority broadcast with push
  disabled still only lands in the inbox.

**Errors** — `400` unknown event type or deep link · `403` missing
`notifications.send` · `502` Firebase unreachable (the inbox rows still exist).

---

## POST /api/v1/admin/notifications/test-push

Sends a push to a specific device, for verifying Firebase configuration.

**Permission:** `notifications.send` — the same as broadcast, because it can target
an arbitrary device. It is not a lesser operation.

Returns the FCM outcome so a misconfiguration is diagnosable without reading logs.
`502` when Firebase is unreachable.

---

## GET /api/v1/admin/notifications/logs

The delivery log: one row per channel attempt.

**Permission:** `notifications.send`

**Query parameters**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `pageNumber` | number | No | 1-based page index |
| `pageSize` | number | No | Records per page |

Each row carries its `NotificationChannel` and `NotificationDeliveryStatus`
(`Queued` · `Sent` · `Delivered` · `Failed` · `Skipped`).

> This is the endpoint that answers "why didn't they get an email?" — a `Skipped`
> row means a preference, a `Failed` row means a channel problem. That distinction
> is the reason skipped channels are recorded rather than omitted.

**It returns delivery metadata, not message contents by recipient.** There is no
`notifications.readall`, and no endpoint lets an administrator read another user's
inbox.

---

## Shared inbox — `/api/v1/notifications`

The portal's own inbox. Scoped to the **calling user** in every case; there is no
parameter to read someone else's.

| Endpoint | Effect |
|---|---|
| `GET /` | List, paged |
| `GET /unread-count` | Badge count — the authority for the count |
| `GET /{id}` | One notification. Named route `GetNotificationByIdAsync` |
| `POST /{id}/read` | `Unread → Read` |
| `POST /read-all` | Mark every unread notification read |
| `POST /{id}/action` | `→ Actioned`. **Read ≠ actioned** — actioning records that the work was done |
| `DELETE /{id}` | `→ Dismissed`. **Not a delete** — the row and its delivery history remain |

Note the shared controller uses `POST` for read-marking; the mobile controller uses
`PATCH` for the same transition. Deliberate, and the reason they are separate
controllers.

---

## Devices and preferences

| Endpoint | Effect |
|---|---|
| `POST /api/v1/devices` | Register or update the caller's device (upsert on token) |
| `GET /api/v1/devices` | The caller's devices |
| `DELETE /api/v1/devices/{deviceId}` | Remove one of the caller's devices |
| `GET /api/v1/users/me/notification-preferences` | The caller's per-category channel opt-ins |
| `PUT /api/v1/users/me/notification-preferences` | Replace them |

`Inbox` cannot be disabled. An FCM token is a **credential** — never logged, never
returned in a response.

---

## Related

- [API — mobile](mobile.md) · [Security](../security.md) · [Business rules](../business-rules.md)
- [Notification architecture](../../../blueprint/notification-architecture.md)
