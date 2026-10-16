# Notification — Business Rules

**Purpose:** the rules the notification implementation enforces.
**Scope:** state transitions, preferences, delivery, multi-device.
**Status:** Active · **Last updated:** 2026-08-27

**Implementation:** `src/ISI.Domain/Modules/Notifications/` ·
`Features/Notifications/Publishing/NotificationService.cs`

---

## Delivery

| Rule | Consequence |
|---|---|
| **The inbox row is written first and unconditionally** | A notification is never lost to a channel failure |
| A preference can disable Push, Email, Sms, Web — **never Inbox** | The user always has a record |
| A disabled channel produces a `Skipped` delivery row | "Why no email?" is answerable |
| A rejected FCM token marks the *delivery* `Failed` | The notification itself still stands |
| Every channel attempt is one `NotificationDelivery` row | Delivery is auditable per channel |

`NotificationDeliveryStatus`: `Queued` · `Sent` · `Delivered` · `Failed` ·
`Skipped`.

---

## State

`NotificationState`: `Unread` · `Read` · `Actioned` · `Dismissed` · `Expired` ·
`ResolvedElsewhere`.

- **Read ≠ Actioned.** Reading is "I saw it"; actioning is "I did the thing". A
  route assignment that is read but not actioned is still outstanding work.
- **`Dismissed` is not a delete.** `DELETE /{id}` moves the notification to
  `Dismissed`; the row and its delivery history remain.
- **`Expired` is a state, not a deletion**, so a delivery log stays explicable
  after the notification stops being actionable.
- **`ResolvedElsewhere` exists for multi-device.** A notification actioned on one
  handset must not still demand attention on another.
- Transitions are one-way except `Unread → Read → Actioned`; a notification cannot
  return to `Unread`.

---

## Actions

`NotificationActionType`: `DeepLink` · `ApiCall`.

- **Deep-link destinations come from a server-side registry** (`DeepLinkRegistry`):
  `route`, `stop`, `quotation`, `order`, `depot`, `dashboard`, `approval`.
  A client cannot be sent to a screen it does not have, and adding a destination
  does not need a client release to *validate* it.
- An inline action is declarative — the client renders a button from the
  notification, it does not hard-code one per event type.

---

## Events

`NotificationEventCatalog` is the registry of raisable event types. An event not in
the catalogue cannot be raised. Keeping it server-side means the taxonomy is
versioned with the API rather than agreed by convention across three clients.

---

## Preferences

Stored per user in `UserNotificationPreference` and read on every dispatch, not
cached at raise time — a preference changed a second before a notification is
raised takes effect.

Endpoints: `GET`/`PUT /api/v1/users/me/notification-preferences` (all clients) and
`GET`/`PUT /api/v1/mobile/notifications/preferences` (mobile).

---

## Priority

`NotificationPriority` tiers exist in `NotificationEnums.cs` and drive channel
selection and client presentation. Priority does **not** override a user
preference: a high-priority notification with push disabled still only lands in the
inbox. Overriding preferences by priority is how a product trains users to disable
notifications entirely.

---

## Related

- [Workflow](workflow.md) · [Data model](data-model.md) · [Security](security.md)
- [Notification architecture](../../blueprint/notification-architecture.md)
