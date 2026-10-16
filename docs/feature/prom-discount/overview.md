# Promotions & Discounts — Overview

**What it is:** one design for every price reduction the business offers.
**Status:** Active for incentives #1 and #5; the rest designed · **Last updated:** 2026-09-12

This is the orientation document. The authority on design is
[promotions-discounts-plan.md](promotions-discounts-plan.md); the authority on what is
actually built is [README.md](README.md). This summarises both so nobody has to read
1,800 lines to hold the shape of the feature in their head.

---

## The problem, in one paragraph

Today a Sales Employee fills in an Excel sheet proposing, for one depot, a rate per
product category — flat, tiered on monthly purchases, or for immediate payment. Four
people sign it. Someone then makes SAP charge it, and someone else works out the
rebates at month end. Separately, representatives give line discounts and take pickup
discounts at their discretion, and sometimes quote prices HQ has never set. None of it
is linked. Nobody can answer *"why did this depot pay this price on this invoice?"*
without opening three spreadsheets. **The feature exists to make that question
answerable.**

---

## The principle

> **Agreed in the platform, enforced by SAP, shown by the platform.**

The platform owns the decision: the request, the approvals, the audit trail, the
notification. **SAP owns the price** — the only discount that is real is one SAP
applies. The platform shows an estimate, and then verifies that SAP agreed.

Two consequences that shape everything downstream:

- An approved agreement must become a **SAP condition record**, not just a row in this
  database. Otherwise a depot buying at the counter — through an order the app never
  touches — gets nothing, while the same depot buying through the app gets a discount.
  Same depot, two prices, depending on which door they walked through.
- Because that copying can fail or drift, an approved term is not yet an effective one.
  The design adds an **`Effective`** state that a nightly verification job grants only
  when SAP is holding a matching record. The same job re-checks every effective term,
  so a rate changed directly in SAP surfaces as a mismatch the next morning instead of
  diverging silently from what four people approved.

---

## Eight incentives, four natures

The diagram, the BRD and the Flutter app each name a different subset of these. This
is the single list, and each row has exactly one home in SAP.

| # | Incentive | Earned | Created by | Approved by | Home in SAP |
|---|---|---|---|---|---|
| 1 | **On-invoice depot discount** | At the invoice line | Rep request | 4-step chain | Condition record: depot × material price group |
| 2 | **Volume-tier rebate** | At month end | Rep request | 4-step chain | Rebate agreement / condition contract |
| 3 | **Immediate-payment discount** | At payment | Rep request | 4-step chain | Payment terms, or a conditional condition (D22) |
| 4 | **Pickup discount** | At the line, if collected | Commercial, as a rule | Once, when the rule is set | Condition on shipping condition (D13) |
| 5 | **Rep line discount** | At the line | Rep, per quotation | By authority level (D4) | Manual item condition |
| 6 | **Price request** | Replaces a missing price | Rep, per quotation | Always (D7) | Manual price condition, plus a task to maintain a real one |
| 7 | **Free goods** | Extra units on the order | Commercial, as a rule | Once, when the rule is set | Free-goods determination → zero-price item (D17) |
| 8 | **Campaign** | As 1–3, for many depots | Commercial | Shortened chain (D27) | As 1–3, keyed on a segment |

**Built today:** **#1** on-invoice depot discounts, end to end — requested, signed four
times, snapshotted into an immutable term, confirmed in SAP, and deducted from a
quotation. **#5** the representative's manual line discount, from the quotations
release. **#4** the pickup rule is built but ships unconfigured (D13).

**#2** volume rebates can be requested and approved — the ladder is stored and shown —
but nothing computes a month-end accrual (D19, D24, and no billing read). **#3** can be
approved and is shown, never deducted (D22). **#6** belongs to quotations. **#7** and
**#8** are not built; the `Campaign` discount kind and segment scope are declared and
refused.

### Flutter mobile UI to backend entity mapping

Each of the 8 incentives has an exact counterpart in the mobile UI codebase:

| # | Incentive | Flutter Mobile Widget / State | Backend Table & Nature | Backend Endpoint |
|---|---|---|---|---|
| 1 | **On-invoice depot discount** | `PromotionSectionWidget` (Group: `depot_discount`), `PromoCard`, `QuotationLineItem.agreementDiscounts` | `agreement_terms` (`nature = 'ON_INVOICE'`) | `GET /depots/{id}/incentives`, `GET /depots/{id}/agreements` |
| 2 | **Volume-tier rebate** | `PromotionSectionWidget` (Group: `depot_discount`), `DiscountSummarySection` (Progress banner) | `rebate_accruals`, `agreement_term_tiers` | `GET /depots/{id}/agreements` (includes `rebateTiers`) |
| 3 | **Immediate-payment discount** | `PromotionSectionWidget` (Group: `cod_pickup`), `PromoView` (`kind: paymentTerm`) | `agreement_terms` (`nature = 'IMMEDIATE_PAYMENT'`) | `GET /depots/{id}/incentives` |
| 4 | **Pickup discount** | `PromotionSectionWidget` (Group: `cod_pickup`), `OrderTerms(isPickup: true)` | `pickup_rules` (`sap_condition_type = 'ZPKP'`) | `GET /depots/{id}/incentives?shipment=Pickup` |
| 5 | **Rep line discount** | `LineDiscountChips`, `ManualDiscountInputSheet`, `QuotationLineDiscount(kind: manual)` | `discount_authorities` | `GET /me/discount-authority`, `PUT /quotations/{id}/discounts` |
| 6 | **Price request** | `ManualPriceInputSheet` (Price request with currency/unit) | `price_requests` | `POST /quotations/{id}/lines` (requests price) |
| 7 | **Free goods** | `PromotionSectionWidget` (Group: `free_goods`), `PromoBuyGet`, `PromotionEvaluation` | `promotions`, `promotion_tiers` | `POST /promotions/evaluate`, `GET /quotations/{id}/preview` |
| 8 | **Campaign** | `PromoCard` with countdown timer (`PromoUrgency`), `PromotionDetailScreen` | `promotions` (scoped by segment) | `GET /depots/{id}/incentives` |

### The axis that decides everything: *when* is it earned?

| Earned | Incentives | On a quotation | Mobile UI Rendering |
|---|---|---|---|
| At the invoice line | 1, 4, 5 | **Deducted** | Green discount pill on line; deducted in `QuotationPreviewSection` subtotal |
| At payment | 3 | Shown as conditional | Grey/info badge: "+x % if paid cash/COD" |
| At month end | 2 | **Shown as progress, never deducted** | Blue progress bar in `DiscountSummarySection` ("$2,340 this month → 3% at $3,000") |
| In goods, not money | 7 | A separate zero-price line | Dedicated bonus item badge: "Buy 40 Bags → 3 Bags Free" |

**A month-end rebate can never be deducted on a quotation.** A tier that depends on the
month's total purchases is unknowable while the month is running — it is retroactive by
nature. The BRD's `FLAT / TIERED / NO_TARGET` modes blur this; the domain stores *what
is earned when* rather than the BRD's labels, and the request form keeps the BRD's
words only for familiarity.

---

## Two objects, deliberately separate

| Object | What it is | Mutable? | Database Table |
|---|---|---|---|
| **Agreement request** | What the representative asked for. Carries revisions and the 4-step approval trail | Yes, while `Draft` or `Returned` | `agreement_requests`, `agreement_request_lines`, `agreement_request_tiers` |
| **Agreement term** | What was approved. Created on final approval | **Immutable.** Only its state and end date change, both audited | `agreement_terms`, `agreement_term_tiers` |

Quotations, the SAP sync and the rebate run read **terms only**. The BRD would have had
the pricing engine read rates off the *request* — which stays editable while it is
returned, meaning the rate being charged could change under a document that had already
been approved.

---

## The calculation, in one block

```text
base   = SAP price (or an approved price-request price)
gross  = quantity × base ÷ pricingUnit            quantity in the price's condition unit
       − #1 on-invoice agreement %                × gross
       − #8 campaign %                            × gross   (best-of vs #1, per D21)
       − #4 pickup %                              × gross   (if collected)
       − #3 immediate-payment %                   × gross   (only if the term qualifies)
       − #5 rep %                                 × gross   (not on a price-request line)
= net                                             cap: Σ % ≤ policy maximum per line
+ tax                                             SAP determines it; shown, not chosen
#7 free goods                                     separate zero-price line
#2 volume rebate                                  not here — month end
```

Percentages are **additive on gross, not compounded**, rounded per line to the
currency's scale and then summed. That is the common SAP arrangement and it is what the
quotation calculator already does — but it is a *proposal* until the SD session
confirms the pricing procedure. **Where SAP stacks, rounds or bases a condition
differently, the platform follows SAP.** The point is to agree with the ERP, not to be
clever: a platform that stacks differently makes every estimate quietly wrong.

---

## What the approvers will need, and do not have

The BRD asks the Regional Sales Manager to judge a request against *targets* and the
Consultant against *margin*. **The platform holds neither sales history, nor targets,
nor cost.** Without them, four signatures become four rubber stamps and the feature
changes nothing about the business's commercial risk.

The minimum that makes steps 2–4 meaningful, buildable once a SAP billing read exists:
for each requested line, the depot's last six months of net purchases, the current
rate, the proposed rate, and the **estimated annual cost of the change**. That one
number is what an approver is actually being asked about.

---

## Related

- [integration-points.md](integration-points.md) — exact code-backed seams in the Flutter mobile app and backend
- [promotions-discounts-plan.md](promotions-discounts-plan.md) — the complete design, schema ERD, DDL, and API contracts
- [../quotation-orders/README.md](../quotation-orders/README.md) — the companion quotation feature that consumes this

