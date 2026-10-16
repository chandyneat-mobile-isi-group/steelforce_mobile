# Promotions & Discounts — Integration Points

**What it is:** how a quotation consumes agreements, the seams it plugs into, and what
a future build must not break.
**Status:** ✅ Code-backed · **Last updated:** 2026-09-12

Everything on this page is verified against the source. Contrast with
[overview.md](overview.md) and the plan, which are design.

---

## The consumption pipeline, as built

When a quotation is previewed, edited or submitted, `QuotationWorkspace.RefreshAsync`
runs two steps before the calculator sees anything:

1. **Resolve categories.** `IMaterialCategoryResolver` maps each line's material to
   SAP's material price group, and that price group to a category code through
   `category_mappings`. One query for the whole document.
2. **Resolve standing deductions.** `IAgreementLookup` reads the depot's
   **effective, on-invoice** terms valid today, plus the pickup rule when the shipment
   type is `Pickup`. One query for the whole document.

Each line then gets `Quotation.ApplyStandingDiscounts`, which **replaces every
non-manual deduction and keeps the manual one**. A rate that expired overnight is gone
from the next preview; a rate that became effective this morning is on it; the
percentage the representative asked for is untouched.

**Only while the document is editable.** Once submitted, the deductions are what the
approver is looking at — an agreement changing underneath a queued quotation would mean
nobody approved the figure that was finally stored.

### What is deliberately *not* deducted

| Not deducted | Why |
|---|---|
| A term in state `Approved` | SAP has not confirmed it. The depot is not being charged it |
| A term in state `SapMismatch` | SAP holds something different. Quoting it would quote a price SAP will not honour |
| A volume rebate, in any state | The month's total is unknowable while the month is running |
| An immediate-payment term | D22 has not settled what it means |
| A pending request | It is not a discount; it is a question |

---

## The seams it plugs into

These were left by the Quotations release so that adding promotions widened behaviour
rather than reshaping the model.

### 1. A discount is a row, with its origin attached

[`QuotationLineDiscount`](../../../src/ISI.Domain/Modules/Quotations/QuotationLineDiscount.cs)
— table `quotation_line_discounts`, one row per deduction:

| Field | Purpose for this feature |
|---|---|
| `Kind` | `Manual` · `Agreement` · `Pickup` · `Campaign` |
| `Percent` | The rate |
| `SourceReference` | The agreement term number, rule id or user id that authorised it |
| `SapConditionType` | What it will be sent to SAP as |
| `EstimateAmount` | The platform's figure |
| `SapAmount` | What SAP actually deducted, once readback exists |

**Rows rather than columns** because a line can carry several incentives at once, and
because the question the feature exists to answer — *which rule or approval produced
this reduction?* — needs somewhere to be recorded.

**`EstimateAmount` versus `SapAmount` is the drift detector.** A gap between them says
the platform models a rule differently from SAP's pricing procedure. More usefully:
*an agreement the platform expected and SAP did not apply* is the signal that the
condition record is missing — which is exactly the check the verification loop needs.

### 2. The discount kinds

[`QuotationDiscountKind`](../../../src/ISI.Domain/Modules/Quotations/QuotationEnums.cs)
declares `Agreement = 1`, `Pickup = 2` and `Campaign = 3` alongside `Manual = 0`.
`Manual`, `Agreement` and `Pickup` are all written today; `Campaign` is declared and
never created. The values are stored as integers — do not renumber them.

### 3. The calculator is kind-agnostic

[`QuotationCalculator`](../../../src/ISI.Application/Features/Quotations/QuotationCalculator.cs)
prices **every** deduction identically: `percent × line gross`, rounded to the
currency's scale, additive rather than compounded, counted towards the per-line cap.

The only place `Kind` is inspected is approval-level routing, where just `Manual`
percentages count — a rate four people already signed should not push a document to a
higher approver.

**So an agreement rate is totalled, capped and rounded by exactly the same code as a
representative's own discount** — which is why adding promotions needed no calculator
change at all.

### 4. An agreement rate is already read-only to the representative

Two halves, both in place:

- [`QuotationMapping.ToDto`](../../../src/ISI.Application/Features/Quotations/QuotationMapping.cs)
  sets `Editable = Kind == Manual`, so the mobile contract already marks a non-manual
  deduction read-only. The app greys the chip rather than hiding it — the depot's
  terms stay visible on the quotation that applies them.
- [`SetQuotationDiscountsCommandHandler`](../../../src/ISI.Application/Features/Quotations/QuotationCommands.cs)
  keeps every non-`Manual` discount when the representative replaces theirs. `PUT
  .../discounts` cannot touch an agreement rate, by construction rather than by rule.

### 5. The category column

`QuotationLine.Category` (`quotation_lines.category`) is now written on every edit by
`IMaterialCategoryResolver`, and re-resolved rather than set once — a mapping added
after a line was priced starts earning that line its agreement rate.

It stays null when the material has no price group, or its price group is unmapped.
That line is priced and sold normally; it simply earns no agreement rate, which is the
correct answer rather than a failure.

### 6. The ownership rule to reuse

`IPricingAudienceResolver` answers *"may this caller see this depot?"* — the
platform's one row-level rule, already used by pricing and quotations. Agreements are
depot-scoped and should use it rather than growing a second rule. The plan proposes
renaming it `IDepotAudienceResolver` when a third feature needs it; this is that
third feature.

### 7. Mobile UI models and the endpoints behind them

The Flutter app's entities, DTOs and state managers, and the backend each one now talks
to. Paths are in the **mobile repository**, not this one.

> Rows for incentives #2, #7 and #8 name endpoints that are **not built** — see
> [README.md](README.md#what-is-not-built). The tables behind them do not exist either.

| Mobile Client Entity | Location | Backend Table | Backend Endpoint |
|---|---|---|---|
| `DepotAgreement` | `quotation_api_entities.dart` | `agreement_terms`, `agreement_term_tiers` | `GET /api/v1/mobile/depots/{id}/agreements` |
| `PromoView`, `PromoGroup` | `promo_view.dart` | `agreement_terms`, `pickup_rules`, `promotions` | `GET /api/v1/mobile/depots/{id}/incentives?shipment=` |
| `QuotationLineDiscount` | `quotation_api_entities.dart` | `quotation_line_discounts` | Joined via `source_reference` to `agreement_terms.term_number` |
| `PromotionEvaluation` | `promotion_evaluation.dart` | `promotions`, `promotion_tiers` | `POST /api/v1/mobile/promotions/evaluate` |
| `DiscountAuthority` | `manual_discount_input_sheet.dart` | `discount_authorities` | `GET /api/v1/mobile/me/discount-authority` |
| `OrderTerms(isPickup)` | `promo_view.dart` | `pickup_rules` (`requires: ["pickup"]`) | Evaluated dynamically against `quotation.shipment_type` |

## What is now in place

| Was needed | Built as |
|---|---|
| `agreement_requests`, `_lines`, `_tiers` | Same names, plus `agreement_approval_steps` for the signature slots |
| `agreement_terms`, `agreement_term_tiers` | Same names, with a PostgreSQL exclusion constraint on overlapping effective terms |
| `category_mappings` | Same name. **Ships empty** — D14 is the business's to answer |
| `pickup_rules` | Same name. **Ships with none configured** — D13 |
| `sap_tasks` | Same name. The option-B work queue |
| An approval engine with templates as data | `AgreementApprovalTemplate` — a reviewable catalogue in code, following `PermissionCatalog`'s convention. The plan's `approval_template_steps` table is the destination once a second subject type needs a different chain; every consumer already reads the chain through this one type |
| `agreements.*` permissions | Nine of them, plus `promotions.configure` — **shipped in the same migration that grants them to roles** |
| `ApprovalSubject.AgreementRequest` | Not needed. The chain has its own signature-slot table with the step, the outcome, the actor and the revision — richer than a generic approval record, and it is what the timeline renders |
| `IAgreementLookup` | Same name, resolving both agreement terms and the pickup rule in one pass |
| A SAP condition-record **read** | **Still does not exist.** Effectiveness is granted by attestation instead |

---

## What a build must not break

| Do not | Because |
|---|---|
| Renumber `QuotationDiscountKind`, `AgreementTermState` or `AgreementRequestStatus` | All stored as integers on live rows |
| Deduct a term that is not `Effective` | SAP is not holding it, so the depot is not being charged it |
| Deduct a volume rebate | The month's total is unknowable while the month is running |
| Let a representative edit a non-`Manual` discount | It carries four signatures. The read-only marking and the preserve-on-replace behaviour are the enforcement |
| Read rates from an agreement *request* | A returned request stays editable. Read the immutable term |
| Let one person sign two steps of a revision | It turns a four-step chain into a two-person one |
| Resume a returned request mid-chain | A signer's name would end up on a version they never read |
| Make the calculator stack differently from SAP | Every estimate becomes quietly wrong |

---

## What comes next

1. **The condition-record read**, the moment the middleware exposes it. It turns the
   attestation into a machine check and — more valuably — catches a rate someone
   changed directly in SAP, which nothing detects today.
2. **The opening import** of today's Excel agreements, before launch. Without it every
   depot loses its discount on day one.
3. **Rebates**, once a billing read exists and D19 and D24 are settled.
4. **Campaigns and free goods**, once D17, D20, D21 and D27 are settled. The
   `Campaign` discount kind and segment scope are already declared and refused.
5. **Delegation and SLA escalation.** Step deadlines are already recorded and shown;
   nothing acts on them yet, and Sales will ask why requests sit for a week.
