# Notification — Overview

**Purpose:** what the notification feature does and the assumption it is built on.
**Scope:** the feature as a whole.
**Status:** Active · **Last updated:** 2026-08-27

---

## The one thing to understand first

> **Push is not delivery. The inbox is delivery.**

Every notification is written to the database as an inbox row before any channel is
attempted. Push, email and SMS are *accelerators* — ways of telling the user
sooner. A client that treats a push message as the notification will lose
notifications, because push is the least reliable channel in the system:

- a user can deny the OS permission prompt
- a token can be revoked by the OS at any time
- Firebase can be unreachable
- the handset can be off for a day

None of those lose an inbox row.

---

## Why it exists

The platform is a communication layer, not just a data store. A sales manager
assigns a route; the representative must know. A quotation is approved; the
representative must know now, not at the next sync. A KPI slips; the manager must
know.

`Admin / Sales Manager → System → Sales Rep → Action → Status → Manager` is the
loop the feature closes.

---

## Categories

`Assignment` · `Quote` · `Order` · `Finance` · `Kpi` · `Approval` · `Account` ·
`System` · `Announce` · `Security`

Wire values are upper-case (`ASSIGNMENT`); the enum name is what is stored.

---

## Channels

`Inbox` · `Push` · `Email` · `Sms` · `Web`

`Inbox` is always attempted and never skipped by a preference. The others are
per-user, per-category preferences, and a skipped channel is recorded as a
`Skipped` delivery rather than silently dropped — so "why didn't I get an email?"
is answerable from the delivery log.

---

## Two ways a notification is raised

1. **A domain event** — picked up by `NotificationRaisedDomainEventHandler` after
   commit.
2. **An admin broadcast** — `POST /api/v1/admin/notifications/broadcast`.

Both go through `NotificationService`. There is no third path that bypasses
preferences or delivery logging.

---

## What is shipped, and what is specified but not built

The [requirement documents](../../requirement/notification/) specify twelve
business flows (route assignment, stop changes, visit reminders, quotation status,
sales order events, KPI warnings, offline sync notices, and more). **The
infrastructure for all of them is shipped** — categories, priorities, states, deep
links, the event catalogue, delivery logging and push.

The **event producers** for most of those flows are not, because the features that
would raise them (quotations, orders, KPI) do not exist yet. What exists today is
the pipeline plus admin broadcast.

---

## Related

- [Workflow](workflow.md) · [Business rules](business-rules.md) · [Architecture](architecture.md)
- [Notification architecture](../../blueprint/notification-architecture.md)
- [Requirements](../../requirement/notification/)
