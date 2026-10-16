# Notification — Testing

**Purpose:** an honest statement of notification test coverage.
**Scope:** `tests/`.
**Status:** Active · **Last updated:** 2026-08-27

---

## There are no notification tests

Verified 2026-08-27: `tests/ISI.Application.UnitTests/Features/` and
`tests/ISI.Domain.UnitTests/Modules/` contain **no** notification test class.

```bash
dotnet test --filter "FullyQualifiedName~Notification"   # matches nothing
```

This is the largest untested feature in the repository, and it is untested in the
places where a bug is least visible — a notification that is silently not delivered
produces no error anywhere.

---

## What should be covered first

In rough order of risk:

1. **Inbox-first ordering.** That the `Notification` row is written even when every
   channel fails or is disabled. This is the feature's central guarantee and nothing
   currently protects it.
2. **Preference honouring.** That a disabled channel produces a `Skipped` delivery
   row rather than being omitted, and that `Inbox` cannot be disabled.
3. **State transitions.** `Unread → Read → Actioned`, `Dismissed`, `Expired`, and
   that nothing returns to `Unread`.
4. **`ResolvedElsewhere`.** That actioning on one device resolves the item for
   another — the multi-device rule.
5. **Push failure isolation.** That a rejected FCM token marks the delivery
   `Failed` without failing the notification. `DisabledPushSender` makes this cheap
   to test.
6. **Deep-link validation.** That a destination outside `DeepLinkRegistry` is
   rejected.
7. **Device upsert.** That re-registering a refreshed token updates rather than
   duplicates the row.

---

## How to write them

Follow `MaterialTestContext`: an isolated in-memory `IApplicationDbContext` plus
NSubstitute for `IPushSender` and `IEmailSender`. `DisabledPushSender` already
exists as a real no-op implementation, which makes the "push does nothing" path
testable without a substitute at all.

See [testing skill](../../skills/backend-development/testing.md).

---

## Related

- [Business rules](business-rules.md) — the rules that need covering
- [Testing skill](../../skills/backend-development/testing.md)
