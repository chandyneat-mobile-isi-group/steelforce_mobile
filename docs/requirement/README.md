# Requirements

> **Purpose:** what the application must do, stated from the user and business
> perspective, with testable acceptance criteria.
> **Status: empty.** No requirement documents exist for any feature.

This directory is deliberately not padded with placeholder files. What follows
is an honest account of the gap, where the information currently lives instead,
and which feature to start with.

---

## Why this is a real gap, not a formality

Requirements answer a different question from every other directory here:

```
requirement/   what the app MUST do        ← business intent, testable
feature/       what the app DOES do        ← current implementation
blueprint/     how it is BUILT             ← architecture
adr/           WHY it is built that way    ← decisions
```

With no requirement documents, three things are impossible:

1. **Verification.** There is nothing to test *against*. A test can prove the
   code does what the code does; it cannot prove the code does what the business
   asked for.
2. **Divergence detection.** When implementation and intent drift, nobody can
   tell which one is wrong — so the code silently becomes the requirement.
3. **Traceability.** The chain
   `requirement → feature → UI → architecture → API → implementation → test`
   is broken at its first link for every feature in the app.

This bites hardest where business rules are non-obvious and enforced only in
code: geofence tolerance and fraud policy (`my_visits`), pricing/discount/approval
rules (`order`), and the SAP Business Partner field requirements (`depots`).

---

## Where requirement-shaped information currently lives

Scattered through implementation documentation, which is the wrong place for it —
those documents describe what *is*, and are rewritten when the code changes.

| Kind of information | Currently in |
|---|---|
| Business rules, validation | [../feature/authentication/business-rules.md](../feature/authentication/business-rules.md) — **the only explicit business-rules document in the repo** |
| Use cases | [../feature/authentication/use-cases.md](../feature/authentication/use-cases.md) |
| Acceptance criteria | [../feature/authentication/uat.md](../feature/authentication/uat.md) and [testing.md](../feature/authentication/testing.md) — closest thing to testable criteria that exists |
| SAP field requirements | [../feature/depot/ui-ux.md](../feature/depot/ui-ux.md), [../feature/depot/reference/](../feature/depot/reference/) |
| Sprint acceptance criteria | [../blueprint/migration-plan.md](../blueprint/migration-plan.md) — infrastructure only, not product |
| Everything else | Only in `lib/` — validators, use cases, and cubit branches |

[../feature/authentication/](../feature/authentication/) is the model: it has
business rules, use cases, and UAT written down. No other feature does.

---

## Suggested priority

Ranked by how much is enforced in code today with nothing written down:

| # | Feature | Why first |
|---|---|---|
| 1 | **`my_visits`** | Geofence tolerance, check-in validity, and fraud flagging are business policy with legal and payroll consequences, enforced entirely in code. `fraud_flags` is a real table. |
| 2 | **`order`** | 43 use cases and 9 repositories. Pricing, discount, and quotation-approval rules have no written source of truth. |
| 3 | **`depots`** | SAP BP field requirements exist as a `.xlsx` and a `.docx` — neither reviewable in a PR nor testable. |
| 4 | **`notification`** | Ten channels, quiet hours, digests, and priority routing are backend-driven; the mobile side's obligations are undocumented. |

---

## Document set per feature

Create only what carries information. Acceptance criteria must be **testable**.

| File | Contents |
|---|---|
| `README.md` | Scope, stakeholders, and links to the corresponding `feature/` docs |
| `functional-requirements.md` | Numbered `FR-n` statements of required behaviour |
| `business-requirements.md` | The business outcome and constraints behind them |
| `user-flow.md` | The journey from the user's perspective, not the code's |
| `acceptance-criteria.md` | Given/When/Then, one per requirement, each mappable to a test |
| `edge-cases.md` | Offline, permission-denied, partial-sync, conflict, and expiry cases |

### Acceptance-criteria form

```
Given   the Sales Representative is authenticated
When    the user opens Depot Registration
Then    the application must display the required depot fields
And     validate required fields before allowing submission
And     submit valid data to the backend
And     display the created depot after success
```

Every `Then`/`And` must be checkable by a person or a test. "The form should be
intuitive" is not an acceptance criterion.

### Offline is a requirement, not an implementation detail

Because this app is offline-first, every feature's criteria must state what
happens with no connectivity. A requirement that only describes the online path
is incomplete here — see
[../blueprint/offline-architecture.md](../blueprint/offline-architecture.md).

---

## Related

- [../feature/README.md](../feature/README.md) — what each feature currently does
- [../feature/authentication/business-rules.md](../feature/authentication/business-rules.md) — the one existing example
- [../skills/engineering-standard.md](../skills/engineering-standard.md) §10 — the test tiers criteria feed
- [../README.md](../README.md#authority-precedence) — requirements are authoritative for *intended* behaviour; the code is authoritative for *current* behaviour
