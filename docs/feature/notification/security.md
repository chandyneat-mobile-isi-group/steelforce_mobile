# Notification — Security

**Purpose:** who may read, send and manage notifications and devices.
**Scope:** permissions, audiences, and the ownership boundary.
**Status:** Active · **Last updated:** 2026-08-27

**Verified against** `src/ISI.Api/Controllers/Notifications/` and
`Controllers/Mobile/`, 2026-08-27.

---

## Permissions

| Permission | Grants |
|---|---|
| `notifications.read` | Read own inbox, counts, mark read, action, dismiss, preferences |
| `notifications.send` | Broadcast, test push, read the delivery log |

---

## Endpoint matrix

| Endpoints | Permission | Audience |
|---|---|---|
| `/api/v1/notifications/*` (list, unread-count, read, read-all, action, delete) | `notifications.read` | All clients |
| `/api/v1/mobile/notifications/*` (incl. preferences) | `notifications.read` | Mobile |
| `/api/v1/admin/notifications/broadcast`, `/test-push`, `/logs` | `notifications.send` | **Admin · HeadOfSales** |
| `/api/v1/devices` (POST, GET, DELETE) | **none** | All clients |
| `/api/v1/mobile/devices/register`, GET, DELETE | **none** | Mobile |
| `/api/v1/users/me/notification-preferences` (GET, PUT) | **none** | All clients |

---

## Three endpoint groups carry no permission attribute

Device registration, device listing/removal and the shared preferences controller
have **no `[HasPermission]`**. They are authenticated — a Bearer token is required —
but not permission-gated.

This is defensible and appears deliberate: registering *your own* device and setting
*your own* preferences are not privileges to be granted, and gating them would mean
a user could be authenticated yet unable to receive notifications at all. The
security boundary is **ownership, enforced in the handler** — every one of these
operates on `ICurrentUser`, never on a user id from the request.

> The risk to be aware of: because the boundary is in the handler rather than
> declarative, a future endpoint added to `DevicesController` that *does* take a
> user id would inherit no protection from the controller. If that happens, add
> `[HasPermission]` at that point.

---

## The ownership boundary

| Operation | Scoped to |
|---|---|
| Read inbox, counts | The current user's notifications only |
| Mark read, action, dismiss | The current user's notifications only |
| Register / list / delete a device | The current user's devices only |
| Get / set preferences | The current user's preferences only |

There is **no `notifications.readall`**. No endpoint lets one user read another's
inbox — an administrator sees *delivery logs*, not message contents by recipient.

---

## Broadcast is the privileged operation

`POST /api/v1/admin/notifications/broadcast` can reach every user on the platform.
It requires `notifications.send`, is Admin/HeadOfSales audience, and is the reason
that permission is separate from `notifications.read`.

`POST /admin/notifications/test-push` carries the same permission — it can send to
an arbitrary device, so it is not a lesser operation.

---

## Push tokens are credentials

An FCM token in `UserDevices` lets the holder send push to that handset. Treat the
table as credential storage: never log a token, never return one in an API
response, and delete the row when a device is removed rather than marking it
inactive.

---

## Related

- [Authorization architecture](../../blueprint/authorization-architecture.md)
- [Business rules](business-rules.md) · [API — admin](api/admin.md)
