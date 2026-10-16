# Promotions & Discounts

**Purpose:** every price reduction the business offers — standing depot agreements,
order terms, representative discretion, rebates, free goods and campaigns — so the app,
the portal and SAP show and charge the same thing.
**Scope:** the incentive catalogue, the depot-agreement request and its four
signatures, the immutable terms it produces, the SAP condition queue, and how a
quotation consumes all of it.
**Status:** Active (phase P1 + option-B effectiveness + quotation consumption) ·
**Last updated:** 2026-09-12

**Implementation:** `src/ISI.Domain/Modules/Promotions/` ·
`src/ISI.Application/Features/Promotions/` · `src/ISI.Api/Controllers/Promotions/` ·
`src/ISI.Persistence/Configurations/PromotionConfigurations.cs` ·
`AgreementTermConfigurations.cs`

---

## Documents

| Document | Contains | State |
|---|---|---|
| [overview.md](overview.md) | What the feature is, the eight incentives, and the principle that governs them | 📋 Design |
| [business-rules.md](business-rules.md) | Every rule the code enforces, where it lives, and what a caller sees | ✅ Code-backed |
| [data-model.md](data-model.md) | The nine tables, their columns, indexes and the exclusion constraint | ✅ Code-backed |
| [integration-points.md](integration-points.md) | How a quotation consumes agreements, and the seams it plugs into | ✅ Code-backed |
| [testing.md](testing.md) | What is covered, and the gap worth filling next | ⚠️ |
| [api/mobile.md](api/mobile.md) | The Flutter surface: incentives, agreements, requests | ✅ Code-backed |
| [api/admin.md](api/admin.md) | The portal: approvals inbox, terms matrix, SAP queue, settings | ✅ Code-backed |
| [promotions-discounts-plan.md](promotions-discounts-plan.md) | The full design: ERD, DDL, mobile payloads, roadmap, decisions D19–D33 | 📋 Specification |
| [promotions/](promotions/README.md) | **The Flutter client's own docs**, copied in from the mobile repository | ⚠️ Other repo |
| [../quotation-orders/README.md](../quotation-orders/README.md) | The feature that consumes this | ✅ Active |
| [../quotation-orders/quotation-orders-plan.md](../quotation-orders/quotation-orders-plan.md) | The companion programme, and decisions D1–D18 | 📋 Proposal |

> [!WARNING]
> **[promotions/](promotions/README.md) describes the mobile app, not this backend**, and
> parts of it are superseded. It documents client-side arithmetic — a 0–10% rep cap, a
> USD manual price override, a free-goods ladder evaluated on the phone — that the
> server now owns or deliberately refuses. Read it for the UI; read
> [api/mobile.md](api/mobile.md) for what the endpoints actually do.

---

## In one paragraph

A representative raises a discount request for a depot — one proposed rate per product
category, flat or on a volume ladder. It collects **four signatures** (Sales Support,
Regional Sales Manager, Consultant, Commercial Director), each step with its own
permission and its own allowed outcomes, and nobody signs twice. Final approval
snapshots the lines into **immutable terms** and queues the SAP condition work. A term
becomes **Effective** only when someone records the condition record number SAP
actually holds — and only an effective, on-invoice term is deducted from a quotation.

---

## The one thing to know

> **A discount is real only when SAP applies it.**

The platform owns the *decision* — the request, the approvals, the audit, the
notification. SAP owns the *price*. A rate that lives only in this database reaches no
invoice, and a depot buying at the counter through an order the app never touches gets
nothing.

That is why `Approved` and `Effective` are different states, and why only the second
one reaches a price. A term four people signed shows on the app greyed, labelled
*approved, not yet active in SAP*, and is not deducted. Promising it would be promising
a price the invoice will not show.

---

## What is built

| Capability | Notes |
|---|---|
| **Category mappings** | The join from a product category to SAP's material price group (`KONDM`). Everything rests on it. **Ships empty** — see below |
| **Agreement requests** | One rate per category, flat or tiered, with validity dates. Idempotent on `clientRequestId` so an offline draft syncing twice creates one request |
| **Volume ladders** | Half-open `[min, max)`, contiguous from zero, only the top rung open-ended. What FR-04 actually means |
| **The four-step chain** | Each step has its own permission and its own allowed outcomes, held as data. Step 1 cannot reject; steps 3–4 cannot return |
| **Four eyes** | The requester never signs. One person holding two chain permissions still signs at most once per revision |
| **Returns** | Reopen the request as a new revision and **restart at step 1**, so no signer's name ends up on a version they did not read |
| **Immutable terms** | Created on the fourth approval. Rate, category, nature and start date never change; only state and end date move, both audited |
| **Supersede** | A new term end-dates its predecessor the day before it starts. The old one keeps charging until then |
| **Termination** | Commercial stops a term early, with a mandatory reason, and an end-date task is queued so SAP stops too |
| **SAP condition queue** | Option B: approval raises a task, the SD team keys the record, and recording its number makes the term effective |
| **Quotation consumption** | Effective on-invoice terms and the pickup rule are applied to every editable quotation automatically, refreshed on each preview |
| **Pickup rule** | Order-term rate for collecting the goods. **Ships with none configured** — see below |
| **Overlap protection** | Checked at submit, again at final approval, and enforced by a PostgreSQL exclusion constraint that no bulk import can route around |

### Two tables ship empty, deliberately

**Category mappings** and the **pickup rule** are configuration the business has not
supplied yet, and inventing values would put fictional SAP keys beside real ones — the
same reason this platform does not seed depots or materials.

- **Category mappings** answer **D14** (*what is a "product category" in SAP terms?*).
  Until rows exist, every request is refused with `422 Agreement.CategoryUnmapped`, and
  no quotation line resolves a category. Configure at
  `PUT /api/v1/settings/category-mappings`.
- **The pickup rule** is **D13** — the app shows 1–1.5%, the BRD does not mention the
  discount, and nobody has confirmed SAP holds a condition for it. Until one is
  configured, no pickup discount is applied. Configure at
  `PUT /api/v1/settings/pickup-rules`.

**The feature is inert until both are set.** That is the honest state, not a defect.

---

## What is not built

| Missing | Blocked on |
|---|---|
| Nightly SAP verification, `POST /agreement-terms/{id}/verify` | **A SAP condition-record read endpoint. It does not exist.** Effectiveness is granted by attestation instead — a named person recording the record number they created |
| Rebate accruals, settlements, billing snapshots | A SAP billing aggregate read, plus **D19** (whole-month vs marginal tiers) and **D24** (what the basis is). A rebate term can be requested and approved today; it is simply never deducted |
| Campaigns, free goods, `POST /promotions/evaluate` | **D17**, **D20**, **D21**, **D27**. The `Campaign` discount kind and segment scope are declared and refused |
| Immediate-payment deduction | **D22** — whether it means paid-at-order or paid-within-N-days. Such a term can be approved; it is shown, not deducted |
| Approval delegation, SLA escalation, step-up PIN | Not blocked, just not in this slice. Step deadlines are recorded and shown; nothing escalates on them |
| `discount_authorities` / `discount_policies` as tables | Deliberate deviation — see below |
| The opening import of today's Excel agreements | Needs the real spreadsheets. **Do this before launch** or every depot loses its discount on day one |

### One deliberate deviation from the plan

The plan specifies `discount_authorities` and `discount_policies` tables. The platform
already binds that policy as validated configuration (`Quotations` section), and the
quotation calculator already enforces it — so a table would be a second source of truth
for numbers that are currently correct. `GET /api/v1/mobile/me/discount-authority`
serves the plan's exact payload from that configuration. Moving it to a table later is
a migration plus a repository behind the same query, with no caller changes.

---

## Decisions still open

| # | Question | Effect today |
|---|---|---|
| **D13** | Pickup rate, scope, and whether SAP holds it | No rule configured, so no pickup discount |
| **D14** | What a product category is in SAP terms | No mappings, so the feature is inert |
| **D15** | Which steps may reject, and which may return | **Encoded as the BRD's matrix** — a configuration change, not a code change |
| **D19** | Whole-month or marginal tiers | Rebates not computed |
| **D22** | What "immediate payment" means | Such terms shown, not deducted |
| **D24** | What the rebate basis is | Rebates not computed |
| **D25** | Fixed-amount discounts | Percentages only |
| **D30** | Retroactive agreements | Refused — `valid_from` cannot be in the past |

None are engineering decisions, and none can be defaulted safely.
