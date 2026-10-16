# Quotations — Admin API

**Base:** `/api/v1/quotations` · **Envelope:** `ApiResponse<T>` ·
**Errors:** RFC 9457 problem documents with a stable `errorCode`
**OpenAPI:** tagged `Admin.Quotations` and `HeadSales.Quotations`, in the `admin`,
`head-sales` and `v1` documents
**Status:** Active · **Last updated:** 2026-09-11

---

## Endpoints

| Method | Route | Permission | Purpose |
|---|---|---|---|
| `GET` | `/` | `quotations.read` | List, paged. The approval queue is `?status=PendingApproval` |
| `GET` | `/{id}` | `quotations.read` | One document in full |
| `GET` | `/{id}/history` | `quotations.read` | The approval trail |
| `POST` | `/{id}/approve` | `quotations.approve` | Accept |
| `POST` | `/{id}/return` | `quotations.approve` | Send back for rework, with a reason |
| `POST` | `/{id}/reject` | `quotations.approve` | Refuse outright, with a reason |
| `POST` | `/{id}/submit-to-sap` | **`quotations.sap`** | Create the SAP sales quotation. Also the retry |
| `GET` | `/{id}/sap-submissions` | **`quotations.sap`** | Every attempt, for troubleshooting |

The three decisions are **verbs, not a status assignment**. A single "set status"
endpoint would let a caller move a quotation anywhere the enum allows, which is exactly
what the state machine exists to prevent.

---

## `GET /` — the queue

| Parameter | Notes |
|---|---|
| `status` | A concrete status or a tab group. `PendingApproval` is the queue |
| `depotId` | Restrict to one depot |
| `ownerUserId` | Restrict to one representative |
| `page` · `pageSize` | One-based; default 20, clamped to 100 |

**Without `quotations.readall` this returns only the caller's own documents**, and
`ownerUserId` cannot widen that. A filter that could widen a scope is an authorisation
hole with a query string.

Each row carries `requiredApprovalLevel`, computed from the document's largest manual
discount at submit and stored — so the queue can be filtered to "needs my level" and
the audit can say *why* it was routed there, even after the authority ladder changes.

---

## Deciding

```http
POST /api/v1/quotations/{id}/approve
POST /api/v1/quotations/{id}/return   { "reason": "Discount above policy for this depot" }
POST /api/v1/quotations/{id}/reject   { "reason": "Not commercially viable" }
```

All three return the recalculated document.

| Failure | Meaning |
|---|---|
| `409 Quotation.InvalidTransition` | The document is not `PendingApproval`. A second approve lands here |
| `403 Quotation.ApproverIsAuthor` | The decider raised this quotation |
| `422 Quotation.ReasonRequired` | A return or rejection with no reason |
| `404 Quotation.NotFound` | No such document, **or** outside the caller's scope |

**Nobody decides on their own quotation.** The rule lives on the aggregate, so it holds
however the command was dispatched — portal, background job or test. Without it, one
person holding both `quotations.create` and `quotations.approve` would be the entire
workflow.

**Return versus reject.** A return reopens the document as a new revision for the
representative to fix and resubmit; the reason is shown to them. A rejection is
terminal — the representative raises a new quotation. Recording both as "rejected"
would leave nobody able to explain why a refused document is being worked on again.

---

## What approval does **not** do

**It does not create a SAP quotation.** Approving releases the document inside the
platform and nothing else; it leaves `sapQuotationStatus: "NotSent"`. Putting the
quotation into SAP is a separate, explicitly triggered act with its own permission —
so approving cannot have an ERP side effect somebody did not intend.

---

## `POST /{id}/submit-to-sap` — the only path to a SAP document

**Not on the mobile surface, and not reachable from it.** A representative's
responsibility ends at Admin Review.

### Guards, all server-side

| Guard | Answer |
|---|---|
| Caller lacks `quotations.sap` | `403` |
| The quotation is not approved | `409 Quotation.NotApprovedForSap` |
| SAP already holds it | `409 Quotation.AlreadyInSap` |
| An attempt is in flight or unresolved | `409 Quotation.SapSubmissionInFlight` |

### A SAP refusal returns `200`

This looks wrong and is deliberate. The command pipeline rolls a transaction back when
a handler returns a failure — which would discard the attempt record and the status
change that say what SAP refused. So anything SAP *answered*, rejection included,
completes successfully.

**Read the outcome from the returned document, not the HTTP status:**

| `sapQuotationStatus` | Meaning | Next step |
|---|---|---|
| `Created` | SAP holds it; `sapQuotationNumber` is set | Nothing |
| `Failed` | SAP answered and refused | Read `GET .../sap-submissions`, fix, submit again |
| `Unknown` | Sent, answer never arrived | **Do not resubmit.** Submitting again looks it up first and adopts the document if SAP has it |

Only a guard violation — where nothing was attempted — returns an error status.

### Lookup before create

Every submission asks SAP whether it already holds a quotation carrying this
document's number (`purchaseOrderNo`) before creating one. That is what turns an
attempt whose outcome was never seen into a resolved one instead of a second sales
document.

### Retry

The same endpoint. Allowed only from `SapFailed`, where SAP answered and said no, so
nothing was created. An `Unknown` attempt is deliberately **not** retryable.

### It ships disabled

Until `SAP:QuotationSubmissionEnabled` is set, the call records a failed attempt with
`Quotation.SapSubmissionDisabled` and nothing leaves the process. Two more settings
matter before it is switched on:

| Setting | Default | Why |
|---|---|---|
| `SAP:QuotationSubmissionEnabled` | `false` | Off until an environment is deliberately pointed at SAP |
| `SAP:QuotationTestRun` | `true` | Asks SAP to validate and roll back. Proves the payload against real validation without creating a document |
| `SAP:QuotationDocType` | *none* | No safe default — the wrong type creates a valid document of the wrong kind. SD owns it |

**The request contract is specified** (`QuotCreateRequestDto` is fully declared in the
middleware's OpenAPI document) but **every response is a bare `200 OK` with no
schema**, so the document number is read tolerantly across several plausible field
names and the names SAP actually sent are logged when none match.

---

## `GET /{id}/sap-submissions` — the attempt log

One row per attempt: number, state, the reference SAP was asked to carry, the document
number it returned, and a stable error code.

**SAP's own error text is not in the response.** It names hosts, connection ids and
ABAP objects; it is kept in the `sap_submissions` row for an administrator with
database access.

---

## The trail

`GET /{id}/history` returns the append-only `approval_records` entries for the
document — action, stage, the status either side, who acted, the reason and when.
Scoped through the same load as every other read, so the trail of a document the caller
may not see is not reachable by asking for its history instead of for the document.

The header also carries a summary of the last decision (`decidedBy`, `decidedAt`,
`decisionReason`), which is what the detail screen shows without a second call.
