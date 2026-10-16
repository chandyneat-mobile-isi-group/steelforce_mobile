# Notification — Diagrams

**Purpose:** the notification flows in one place.
**Scope:** delivery pipeline, state machine, push handling by app state.
**Status:** Active · **Last updated:** 2026-08-27

---

## 1. Delivery pipeline

```mermaid
flowchart TB
    E[Business event or admin broadcast] --> S[NotificationService]
    S --> N[(Notification row — always)]
    S --> P{UserNotificationPreference}
    P -->|Inbox| I[Delivery: Inbox / Sent]
    P -->|Push enabled| PU[IPushSender] --> FCM[Firebase] --> DP[Delivery: Push / Sent or Failed]
    P -->|Push disabled| SK[Delivery: Push / Skipped]
    P -->|Email enabled| EM[IEmailSender] --> SMTP --> DE[Delivery: Email / Sent]
    I & DP & SK & DE --> L[(NotificationDeliveries)]
    L --> AL["GET /admin/notifications/logs"]
```

---

## 2. State machine

```mermaid
stateDiagram-v2
    [*] --> Unread
    Unread --> Read
    Unread --> Actioned
    Read --> Actioned
    Unread --> Dismissed
    Read --> Dismissed
    Unread --> Expired
    Read --> Expired
    Unread --> ResolvedElsewhere
    Read --> ResolvedElsewhere
    Actioned --> [*]
    Dismissed --> [*]
    Expired --> [*]
    ResolvedElsewhere --> [*]
```

No transition returns to `Unread`.

---

## 3. Push by application state

```mermaid
flowchart TD
    F[FCM message arrives] --> S{App state}
    S -->|Foreground| FG[Render in-app<br/>refresh badge from unread-count]
    S -->|Background| BG[OS shows the tray notification]
    S -->|Terminated| T[OS shows the tray notification]
    BG --> TAP{User taps?}
    T --> TAP
    TAP -->|Yes| DL[Resolve deep link → screen]
    TAP -->|No| NX[Nothing — the inbox row is still there]
    FG --> NX2[Inbox row already present]
    DL --> A["POST /{id}/action"]
```

The right-hand path is the point: **every branch that does not reach the user still
leaves an inbox row.** The client never depends on having received the push.

---

## 4. Device registration and token refresh

```mermaid
sequenceDiagram
    participant OS
    participant M as Mobile app
    participant A as API
    participant DB as PostgreSQL

    M->>OS: request notification permission
    OS-->>M: granted / denied
    M->>OS: get FCM token
    OS-->>M: token
    M->>A: POST /mobile/devices/register
    A->>DB: upsert UserDevice
    Note over OS,M: later — OS rotates the token
    OS-->>M: onTokenRefresh
    M->>A: POST /mobile/devices/register (new token)
    A->>DB: upsert
```

A denied permission is not an error state for the backend: no device row, no push
deliveries, inbox unaffected.

---

## 5. Multi-device resolution

```mermaid
sequenceDiagram
    participant D1 as Device A
    participant D2 as Device B
    participant A as API
    participant DB as PostgreSQL

    A->>D1: push
    A->>D2: push
    D1->>A: POST /{id}/action
    A->>DB: state = Actioned
    D2->>A: GET /mobile/notifications (next sync)
    A-->>D2: state = Actioned / ResolvedElsewhere
    Note over D2: clears the item rather than demanding action again
```

---

## Related

- [Workflow](workflow.md) · [Business rules](business-rules.md) · [Architecture](architecture.md)
- [API — mobile](api/mobile.md)
