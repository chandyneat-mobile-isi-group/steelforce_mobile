# Notification — Workflow

**Purpose:** the life of a notification, from event to action.
**Scope:** raise, dispatch, deliver, read, action, expire.
**Status:** Active · **Last updated:** 2026-08-27

---

## 1. Raise and dispatch

```mermaid
sequenceDiagram
    participant E as Domain event / admin
    participant S as NotificationService
    participant DB as PostgreSQL
    participant D as DispatchNotificationCommand
    participant P as IPushSender
    participant F as Firebase

    E->>S: raise(event, recipients, payload)
    S->>DB: INSERT Notification (state = Unread)
    Note over S,DB: the inbox row is written first, unconditionally
    S->>DB: read UserNotificationPreference
    S->>D: dispatch enabled channels
    D->>DB: NotificationDelivery{Inbox, Sent}
    alt push enabled and a device is registered
        D->>P: send
        P->>F: FCM message
        F-->>P: accepted / rejected
        D->>DB: NotificationDelivery{Push, Sent|Failed}
    else push disabled by preference
        D->>DB: NotificationDelivery{Push, Skipped}
    end
```

A channel the user has turned off is recorded as `Skipped`, not omitted. That is
what makes the delivery log able to answer "why didn't I get an email?".

---

## 2. The user reads it

```mermaid
stateDiagram-v2
    [*] --> Unread
    Unread --> Read: PATCH /{id}/read · PATCH /read-all
    Unread --> Actioned: POST /{id}/action
    Read --> Actioned: POST /{id}/action
    Unread --> Dismissed: DELETE /{id}
    Read --> Dismissed: DELETE /{id}
    Unread --> Expired: NotificationSweeps
    Read --> Expired: NotificationSweeps
    Unread --> ResolvedElsewhere: handled on another device
    Read --> ResolvedElsewhere: handled on another device
```

`ResolvedElsewhere` is what makes multi-device work: a notification actioned on one
handset must not still demand attention on another.

**Read and actioned are different.** Reading is "I saw it"; actioning is "I did the
thing". A route-assignment notification that is read but not actioned is still
outstanding work.

---

## 3. Badge counts

```mermaid
flowchart LR
    C[Client cold start] --> U["GET /mobile/notifications/unread-count"]
    U --> B([badge])
    P[Push arrives] --> INC[increment locally]
    R[User reads one] --> DEC[decrement locally]
    S[App foregrounded] --> U
```

The count endpoint is the authority; local increments are an optimisation between
calls. Re-fetch on foreground rather than trusting an accumulated local count
across a background period.

---

## 4. Device registration

```mermaid
sequenceDiagram
    participant M as Mobile app
    participant A as API
    participant DB as PostgreSQL

    M->>M: obtain FCM token
    M->>A: POST /mobile/devices/register {token, platform}
    A->>DB: upsert UserDevice for this user
    A-->>M: 200
    Note over M,A: re-register on every token refresh
```

`GET /mobile/devices` lists the user's devices; `DELETE /mobile/devices/{deviceId}`
removes one. A token FCM rejects marks the *delivery* `Failed` — it does not fail
the notification.

---

## 5. Housekeeping

`NotificationSweeps` expires notifications past their validity and performs
retention housekeeping. Expiry is a state (`Expired`), not a delete, so a delivery
log remains explicable after the notification stops being actionable.

---

## Related

- [Business rules](business-rules.md) · [Diagram](diagram.md)
- [API — mobile](api/mobile.md) · [API — admin](api/admin.md)
