# Quotations — Business Rules

**What it is:** every rule the quotation feature enforces, where it lives, and what a
caller sees when it bites.
**Status:** Active · **Last updated:** 2026-09-11

A rule is listed here only if code enforces it. Rules the plan proposes but nothing
implements are in [quotation-orders-plan.md](quotation-orders-plan.md), not here.

---

## Ownership and visibility

| Rule | Where | Answer |
|---|---|---|
| A quotation may only be opened against a depot the caller may see | `CreateQuotationCommandHandler` via `IPricingAudienceResolver` | `404 Quotation.NotFound` |
| Someone else's quotation is invisible | `QuotationWorkspace.LoadAsync` | `404 Quotation.NotFound`, never 403 |
| `quotations.readall` widens reading to everyone's documents | `QuotationWorkspace.LoadAsync`, `ListQuotationsQueryHandler` | — |
| `quotations.readall` does **not** widen editing | `QuotationWorkspace.LoadForEditAsync` | `404 Quotation.NotFound` |
| The `ownerUserId` filter narrows an already-scoped list; it never widens it | `ListQuotationsQueryHandler` | — |

**404 and not 403, deliberately.** Naming a document confirms a commercial record the
caller has no right to know exists. The same rule Pricing and depot drafts follow.

**An approver's route to changing a document is to return it.** A supervisor holding
`quotations.readall` can read a representative's draft and cannot edit it out from
under them.

---

## Pricing a line

| Rule | Where | Answer |
|---|---|---|
| The client never sends a price | `AddQuotationLineRequest` has no price field | — |
| SAP holds no price for this depot and material | `QuotationLinePricer` | `422 Quotation.MaterialNotPriced` |
| SAP holds more than one valid price | `QuotationLinePricer` | `422 Quotation.MultiplePrices` |
| SAP could not be read, or the row was unmapped | `QuotationLinePricer` | `502 Quotation.PriceUnavailable` |
| The depot has no SAP sales area | passed through from Pricing | `422 Pricing.DepotNotPriceable` |
| A price must carry an amount, a currency and a condition unit | `QuotationLinePrice.Create` | `422 Quotation.MaterialNotPriced` |
| A missing or zero `pricingUnit` means "per one" | `QuotationLinePrice.Create` | coerced to 1 |

**Never `items[0]`.** Material `2400000466` returns 100.000 USD/M *and* 2.765 US3/M on
the live connection. Choosing between two prices SAP considers valid is a commercial
decision, so the line is blocked until the business makes one.

**An outage never unlocks anything.** The app's current behaviour — offering manual
price entry whenever a price is missing — cannot be reached through this API, because
"SAP answered with nothing" and "SAP did not answer" are different status codes.

---

## Building the document

| Rule | Where | Answer |
|---|---|---|
| Quantity must be greater than zero | `QuotationLine.Create`, validator | `400` / `422 Quotation.QuantityInvalid` |
| Quantity must be stated in the price's condition unit | `QuotationLine.Create` | `422 Quotation.UnitMismatch` |
| One material per document | `Quotation.AddLine` + unique index | `422 Quotation.DuplicateLine` |
| Every line shares one document currency | `Quotation.AddLine`, calculator | `422 Quotation.MixedCurrency` |
| Removing the last line releases the document currency | `Quotation.RemoveLine` | — |
| Delivery requires a ship-to | `Quotation.UpdateHeader`, `Quotation.Submit` | `422 Quotation.ShipToRequired` |
| Content changes only while `Draft` or `Returned` | `Quotation.IsEditable` | `409 Quotation.NotEditable` |

**No unit conversion.** The platform does not hold the material master's conversion
factors, so rebar quoted in pieces against a per-KG price is refused rather than
converted with an assumed factor. That is the whole reason for `UnitMismatch`.

---

## Discounts

| Rule | Where | Answer |
|---|---|---|
| The client sends a percentage, never an amount | `QuotationDiscountIntent` | — |
| A percentage is between 0 and 100 | `QuotationLineDiscount.Create`, validator | `422 Quotation.DiscountPercentInvalid` |
| `PUT .../discounts` replaces the manual set; an omitted line loses its discount | `SetQuotationDiscountsCommandHandler` | — |
| Non-manual deductions survive that replacement untouched | `SetQuotationDiscountsCommandHandler` | — |
| Total deduction on a line may not exceed the configured cap | `QuotationCalculator` | `422 Quotation.DiscountCapExceeded` |
| Total deduction may not exceed the line | `QuotationCalculator` | `422 Quotation.DiscountExceedsGross` |
| A rate above the caller's authority is accepted, and raises the approval level | `QuotationCalculator.ResolveApprovalLevel` | — |

**Above authority is accepted, not refused.** The business need is real; refusing it
means the representative rings the office. What it costs is the level the document is
routed to, computed at submit and stored so the queue can filter on it.

**Never `max(0, gross − discount)`.** Clamping hides a discount larger than the order
behind a plausible zero.

---

## The arithmetic

```text
line gross = quantity × price.amount ÷ price.pricingUnit      rounded to the currency scale
           − each discount percent × line gross               each rounded, then summed
line net   = line gross − total discount                      rounded
document   = Σ line net
```

- **Percentages are additive on gross, not compounded.** That is the common SAP
  arrangement, where discount conditions reference the gross step. It is a *proposal*
  until the SD session confirms the pricing procedure; if the procedure compounds, the
  calculator compounds.
- **Rounding is per line, then summed** — how SAP does it. A one-cent disagreement on a
  quotation is a support ticket.
- **Away from zero, not banker's rounding.** Half a cent rounding down half the time is
  defensible statistics and indefensible on an invoice a depot checks by hand.
- **Scales come from configuration**: `USD` 2, `US3` 3, `KHR` 0, default 3.

---

## Submitting

| Rule | Where | Answer |
|---|---|---|
| A quotation needs at least one line | `Quotation.Submit` | `422 Quotation.NoLines` |
| Every price is re-read from SAP at submit | `SubmitQuotationCommandHandler` | — |
| A price that moved stops the submit | `SubmitQuotationCommandHandler` | `409 Quotation.PriceChanged` |
| Accepting new prices is a deliberate act | `POST .../reprice` | — |
| Repricing is all-or-nothing | `RepriceQuotationCommandHandler` | `502 Quotation.PriceUnavailable` |

**Why not reprice automatically?** Because the representative has been showing the
depot figures from the snapshot. Silently substituting new ones at submit puts a
number into an approval queue that nobody was shown. The 409 → reprice → look → submit
loop makes the change visible to the person who has to explain it.

---

## Approval

| Rule | Where | Answer |
|---|---|---|
| Only a `PendingApproval` document can be decided | `Quotation.GuardDecision` | `409 Quotation.InvalidTransition` |
| Nobody decides on their own quotation | `Quotation.GuardDecision` | `403 Quotation.ApproverIsAuthor` |
| A return needs a reason | `Quotation.Return`, validator | `422 Quotation.ReasonRequired` |
| A rejection needs a reason | `Quotation.Reject`, validator | `422 Quotation.ReasonRequired` |
| A return increments the revision and reopens editing | `Quotation.Return` | — |
| A rejection is terminal | status derivation | — |
| Every decision writes an `ApprovalRecord` | `QuotationDecisionService` | — |
| Cancellation is allowed while `Draft`, `Returned` or `PendingApproval` | `Quotation.Cancel` | `409 Quotation.InvalidTransition` |

**Four eyes lives on the aggregate, not in a handler.** It therefore holds however the
command was dispatched — portal, background job or test. Without it, one person holding
both `quotations.create` and `quotations.approve` would be the entire workflow.

**Cancellation after a decision is refused.** A document an approver has acted on is
closed by the decision, not by its author changing their mind.

---

## Submitting to SAP

| Rule | Where | Answer |
|---|---|---|
| Only `quotations.sap` may submit | `SubmitQuotationToSapCommand` attribute | `403` |
| Only an **approved** quotation may be submitted | `Quotation.BeginSapSubmission` | `409 Quotation.NotApprovedForSap` |
| A quotation SAP already holds is never sent again | `Quotation.BeginSapSubmission` | `409 Quotation.AlreadyInSap` |
| An attempt in flight or unresolved blocks a new one | `Quotation.BeginSapSubmission` | `409 Quotation.SapSubmissionInFlight` |
| A retry is allowed only from `SapFailed` | same guard | — |
| A 2xx with no document number is not a success | `Quotation.RecordSapQuotationCreated` | recorded as `Failed` |
| Every attempt is recorded before anything is sent | `SapSubmission` | — |
| SAP's error text never leaves the server | `SapSubmissionDto` omits it | — |
| Submission is disabled unless configured | `SapQuotationService.EnsureEnabled` | recorded as `Failed` |

**Mobile cannot reach SAP, structurally.** Three independent things would each have to
be undone: the permission (held by no mobile role), the absence of any mobile route
dispatching the command, and the aggregate refusing to begin from anything but
`Approved`.

**A SAP refusal is a successful command.** The pipeline rolls a transaction back on a
failure result, which would discard the attempt record and the status change that say
what SAP refused. So anything SAP *answered* completes successfully and the outcome is
read from `sapQuotationStatus`.

**A timeout is not a failure.** If the request left the wire and no answer came, SAP may
hold the document. That is `Unknown`, and it is deliberately not retryable — the next
submission looks the quotation number up first and adopts the document if SAP has it.
Resending would commit a depot to two quotations, and SAP has no way to know the
second was an accident.

**Look before creating, always.** One extra call per submission, and it is what turns an
unresolved attempt into a resolved one.

---

## Logging

Ids, numbers, statuses and counts. **No amounts, no prices, no depot commercial
terms** — the same rule Pricing follows, for the same reason: a log is read by more
people than a quotation is.
