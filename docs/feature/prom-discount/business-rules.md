# Promotions & Discounts — Business Rules

**What it is:** every rule this feature enforces, where it lives, and what a caller
sees when it bites.
**Status:** Active · **Last updated:** 2026-09-12

A rule is listed here only if code enforces it. Rules the design proposes but nothing
implements are in [promotions-discounts-plan.md](promotions-discounts-plan.md), and the
gaps are listed in [README.md](README.md#what-is-not-built).

---

## The rule everything else serves

> **Only an `Effective`, on-invoice term, valid today, is ever deducted from a price.**

Four conditions, all necessary, enforced by `AgreementTerm.IsDeductibleOn`:

| Condition | Why |
|---|---|
| `State == Effective` | SAP is confirmed to hold a matching condition record. An `Approved` term is not yet charged to the depot |
| `Nature == OnInvoice` | A volume rebate is earned on the month's total, which is unknowable mid-month |
| `ValidFrom <= today` | It has started |
| `ValidTo >= today` or open | It has not ended |

Everything below is in service of getting a rate honestly into that state, or of
keeping a rate that does not qualify out of a depot's price.

---

## Raising a request

| Rule | Where | Answer |
|---|---|---|
| The depot must be one the caller may see | `CreateAgreementRequestCommandHandler` via `IPricingAudienceResolver` | `404 Agreement.NotFound` |
| Segment-scoped requests are refused | `AgreementRequest.Create` | `422 Agreement.SegmentScopeNotSupported` |
| A category must have an active SAP mapping | `AgreementWorkspace.EnsureCategoriesMappedAsync` | `422 Agreement.CategoryUnmapped` |
| One rate per category per request | `AgreementRequest.ReplaceLines` + unique index | `422 Agreement.DuplicateCategory` |
| A start date cannot be in the past | `AgreementRequestLine.Create` | `422 Agreement.RetroactiveNotAllowed` |
| An end date cannot precede the start | `AgreementRequestLine.Create` | `400 Agreement.DateRangeInvalid` |
| A flat line needs a percentage | `AgreementRequestLine.Create` | `422 Agreement.PercentRequired` |
| A percentage is 0–100 | `AgreementRequestLine.Create` | `400 Agreement.PercentInvalid` |
| A tiered line needs tiers; a flat line must have none | `AgreementRequestLine.Create` | `422 Agreement.TiersMismatched` |
| Content changes only while `Draft` or `Returned` | `AgreementRequest.IsEditable` | `409 Agreement.NotEditable` |
| Only the author edits | `AgreementWorkspace.LoadOwnRequestAsync` | `404 Agreement.NotFound` |

**Retroactive rates are refused (D30).** A rate that starts in the past changes
invoices that have already been raised, which is a Finance decision rather than a sales
one.

**Only the author edits.** An approver who wants something different returns the
request. Editing it themselves would mean the signatures below theirs were given to a
different document.

---

## Volume ladders

Validated by `AgreementTierRules.Validate`, shared by the request line and the term so
a ladder that was legal when proposed is still legal when snapshotted.

| Rule | Answer |
|---|---|
| The first rung starts at `0` | `422 Agreement.TiersInvalid` |
| Rungs are contiguous — each ceiling is the next floor | `422 Agreement.TiersInvalid` |
| Only the last rung may be open-ended | `422 Agreement.TiersInvalid` |
| Orders run `1..n` with nothing missing or repeated | `422 Agreement.TiersInvalid` |
| Each rate is 0–100 | `400 Agreement.PercentInvalid` |

**Half-open `[min, max)`.** The BRD writes ladders as *"&lt;$2,000: 1.5%, &lt;$3,000:
3%"*, which leaves both boundaries ambiguous and permits gaps. An explicit inclusive
floor and exclusive ceiling makes *"exactly 2,000"* answerable and makes a gap
something the validator can see. A closed top rung is legitimate — a scheme that stops
is not the same as a gap.

---

## The four signatures

Each step's permission and allowed outcomes are data, held in
`AgreementApprovalTemplate`.

| Step | Who | Permission | May |
|---|---|---|---|
| 1 | Sales Support | `agreements.prepare` | forward, return |
| 2 | Regional Sales Manager | `agreements.verify` | forward, return, reject |
| 3 | Consultant | `agreements.approve-consultant` | approve, reject |
| 4 | Commercial Director | `agreements.approve-final` | approve, reject |

**This settles D15**, where the BRD contradicts itself — FR-06 says any approver may
reject or return; its own §8 matrix says step 1 cannot reject and steps 3–4 cannot
return. The matrix is encoded because it is the more specific of the two and it
produces a chain that makes sense: step 1 checks that a request is *complete*, not
whether it is a good idea, and by step 3 two signatures exist that a return would
discard. **Changing it is a configuration edit in one file, not a code change.**

| Rule | Where | Answer |
|---|---|---|
| The caller must hold that step's permission | `ActOnAgreementStepCommandHandler` | `403 Agreement.StepNotYours` |
| The step must be the one holding the request | `AgreementRequest.Act` | `409 Agreement.InvalidTransition` |
| The outcome must be in the step's template | `AgreementRequest.Act` | `409 Agreement.OutcomeNotAllowed` |
| The requester never signs | `AgreementRequest.Act` | `409 Agreement.AlreadyActedByYou` |
| One person signs at most one step per revision | `AgreementRequest.Act` | `409 Agreement.AlreadyActedByYou` |
| A return or reject needs a comment | `AgreementRequest.Act` | `400 Agreement.ReasonRequired` |
| A request needs at least one line to be submitted | `AgreementRequest.Submit` | `422 Agreement.NoLines` |
| Withdrawal is allowed only before step 2 acts | `AgreementRequest.Withdraw` | `409 Agreement.InvalidTransition` |

**Four eyes has two halves**, and both matter. The requester never signs their own
request; and one person who legitimately holds two of the four permissions still signs
at most once per revision. Without the second half, a four-step chain quietly becomes a
two-person one.

**A return restarts the chain at step 1.** The revision increments, four fresh slots
open, and the previous revision's signatures stay on the aggregate against the revision
they were given to. Resuming mid-chain would put the Commercial Director's name on a
version they never read.

**The same person may sign again on a new revision** — Sales Support checking the
corrected version is exactly what should happen.

---

## Overlap

| Rule | Where | Answer |
|---|---|---|
| No effective term may already cover this scope and dates | `AgreementWorkspace.EnsureNoOverlapAsync` | `409 Agreement.OverlapsEffective` |
| No other request for the same scope may be on the chain | `AgreementWorkspace.EnsureNoOverlapAsync` | `409 Agreement.OverlapsPending` |
| The database refuses overlapping effective terms outright | `exclude_overlapping_effective_terms` | `500` (and a bug report) |

**Checked at submit and again at final approval.** A request spends days collecting
four signatures, and another representative can get a rate for the same depot and
category approved in the meantime. Checking only at submit would let two effective
terms exist for one scope.

**The exclusion constraint is the backstop.** A PostgreSQL `btree_gist` constraint on
`(depot_id, category_code, nature, daterange)` where `state = Effective`. The domain
checks cannot cover a bulk import, a hand-run data fix, or two approvals committing in
the same instant — and this is a commercial guarantee, so it belongs where nothing can
route around it. Hitting it is a defect, not a user error.

---

## Terms

| Rule | Where | Answer |
|---|---|---|
| A term is created only by the fourth approval | `ActOnAgreementStepCommandHandler` | — |
| Rate, category, nature and start date never change | No setter exists | — |
| A SAP confirmation needs a condition record number | `AgreementTerm.ConfirmInSap` | `400 Agreement.ConditionRecordRequired` |
| Only `Approved` or `SapMismatch` can be confirmed | `AgreementTerm.ConfirmInSap` | `409 Agreement.InvalidTransition` |
| A successor end-dates its predecessor the day before it starts | `AgreementTerm.SupersedeFrom` | — |
| Termination needs a reason | `AgreementTerm.Terminate` | `400 Agreement.ReasonRequired` |
| Only a live term can be terminated | `AgreementTerm.Terminate` | `409 Agreement.NotTerminable` |
| A closed SAP task cannot be closed again | `SapTask.Complete` | `409 Agreement.TaskAlreadyClosed` |

**The condition record number is the evidence.** A confirmation without one is somebody
asserting that SAP agrees, which is precisely the state of affairs this feature exists
to replace.

**A superseded term keeps charging until its successor starts.** It is still what the
depot agreed to in the meantime; only once the successor's start date arrives does it
become `Superseded`.

**Termination is the one transition that takes something away from a depot**, which
is why the reason is mandatory and why an end-date task is queued alongside it. A term
the platform calls terminated while SAP keeps applying the discount is worse than no
feature at all.

---

## What a quotation deducts

Applied by `QuotationWorkspace.ApplyStandingDiscountsAsync` before every recalculation.

| Rule | Effect |
|---|---|
| Standing deductions are refreshed on every edit and preview | A rate that expired overnight is gone from the next preview |
| Manual discounts survive the refresh; everything else is replaced | The representative's own percentage is theirs until they change it |
| Only applied while the quotation is editable | Once submitted, the deductions are what the approver is looking at |
| A line with no resolvable category earns no agreement rate | It is still priced and sold normally |
| A line with no category still earns the pickup rate | The discount is for collecting the goods, not for what they are |
| The most specific pickup rule wins | A category-scoped rate beats a blanket one, because someone wrote the narrower rule deliberately |

**Never deducted**, whatever their state: a volume rebate, an immediate-payment term,
a term that is `Approved` but not `Effective`, a term in `SapMismatch`, and a pending
request. Each is shown on the incentives feed with a status that says so.

**The calculator needed no change.** It prices every deduction identically —
`percent × line gross`, additive, rounded per line, counted towards the per-line cap —
and inspects `Kind` only to decide approval routing, where just manual percentages
count. A rate four people signed should not push a document to a higher approver.

---

## Scope and visibility

| Rule | Where | Answer |
|---|---|---|
| A representative sees the requests they raised | `AgreementWorkspace.LoadRequestAsync` | `404 Agreement.NotFound` |
| Anyone holding a chain permission sees the queue | `AgreementWorkspace.IsApproverOrReaderAsync` | — |
| `agreements.readall` sees everything | same | — |
| The `step` and `ownerUserId` filters narrow; they never widen | `ListAgreementRequestsQueryHandler` | — |
| An unrecognised status filter matches nothing | `ListAgreementRequestsQueryHandler` | empty page |

**404, never 403.** A depot's rates are another depot's negotiating position, so
confirming that an agreement exists is itself a disclosure. The same rule pricing,
quotations and depot drafts follow.

**Approvers are recognised by permission, not by role name**, so the day the business
adds a fifth signature nothing in the scoping changes.

---

## Logging

Ids, numbers, counts and statuses. **No rates, no amounts, no depot terms** — a log is
read by more people than an agreement is, and a depot's commercial terms are exactly
the kind of thing that must not end up in an aggregated log search.
