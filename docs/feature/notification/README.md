# Notification

**Purpose:** how a business event becomes something a user sees, on any channel.
**Scope:** the notification aggregate, the device registry, preferences, and the
six controllers that expose them.
**Status:** Active · **Last updated:** 2026-08-27

**Implementation:** `src/ISI.Domain/Modules/Notifications/` ·
`src/ISI.Application/Features/Notifications/` ·
`src/ISI.Api/Controllers/Notifications/` + `Controllers/Mobile/`

---

## Documents

| Document | Contains | State |
|---|---|---|
| [overview.md](overview.md) | What it is and the one thing to understand first | ✅ |
| [workflow.md](workflow.md) | Raise → dispatch → read → action, end to end | ✅ |
| [business-rules.md](business-rules.md) | State model, preferences, multi-device rules | ✅ |
| [architecture.md](architecture.md) | The pipeline and where each piece lives | ✅ |
| [diagram.md](diagram.md) | Delivery, state and push-by-app-state flows | ✅ |
| [data-model.md](data-model.md) | Tables, entities, enumerations | ✅ |
| [security.md](security.md) | Permissions and the device-ownership boundary | ✅ |
| [testing.md](testing.md) | Coverage — currently a gap | ✅ |
| [api/admin.md](api/admin.md) | Broadcast, test push, delivery logs | ✅ |
| [api/mobile.md](api/mobile.md) | Inbox, badges, actions, preferences, devices | ✅ |
| [api/devices-register.md](api/devices-register.md) | Push-token registration: the first thing that must work | ✅ |

Requirements: [requirement/notification/](../../requirement/notification/).
System-level design: [blueprint/notification-architecture.md](../../blueprint/notification-architecture.md).

---

## In one paragraph

The **inbox row is written first and unconditionally**; push is an accelerator, not
the delivery mechanism. A user who never receives a push still finds the
notification in the app. That one decision is what makes the feature survive a
Firebase outage, a revoked device token, or a user who denied the permission
prompt.

---

## Related

- [Features index](../README.md) · [Requirements](../../requirement/notification/)
