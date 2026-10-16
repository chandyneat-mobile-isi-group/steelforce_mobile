# Promotions & Discounts — Admin API

**Base:** `/api/v1` · **Envelope:** `ApiResponse<T>` ·
**Errors:** RFC 9457 problem documents with a stable `errorCode`
**OpenAPI:** tagged `Admin.Promotions` and `HeadSales.Promotions`, in the `admin`,
`head-sales` and `v1` documents
**Status:** Active · **Last updated:** 2026-09-12

---

## Endpoints

| Method | Route | Permission |
|---|---|---|
| `GET` | `/agreement-requests?status=&step=&depotId=` | `agreements.read` |
| `GET` | `/agreement-requests/{requestId}` | `agreements.read` |
| `POST` | `/agreement-requests/{requestId}/steps/{stepOrder}/{outcome}` | `agreements.read` + **the step's own** |
| `GET` | `/agreement-terms?depotId=&categoryCode=&state=` | `agreements.readall` |
| `POST` | `/agreement-terms/{termId}/terminate` | `agreements.terminate` |
| `GET` | `/sap-tasks?status=` | `agreements.sap` |
| `POST` | `/sap-tasks/{taskId}/done` | `agreements.sap` |
| `GET` | `/settings/category-mappings` | `agreements.read` |
| `PUT` | `/settings/category-mappings` | `promotions.configure` |
| `GET` | `/settings/pickup-rules` | `agreements.read` |
| `PUT` | `/settings/pickup-rules?ruleId=` | `promotions.configure` |

---

## The approvals inbox

`GET /agreement-requests?step=2` is *"what is waiting for me"* when the caller is a
Regional Sales Manager.

**Scoped before it is filtered.** Without a chain permission or `agreements.readall`,
this returns only the caller's own requests, and `step` narrows that already-narrowed
set. A filter that could widen a scope is an authorisation hole with a query string.

An unrecognised `status` matches **nothing** rather than everything — a typo must not
silently show an approver the whole queue.

Each row carries `slaDueAt` from the pending step. Nothing escalates on it yet; it is
there so Sales can see where requests are sitting, which is the first question they
will ask.

---

## `POST .../steps/{stepOrder}/{outcome}` — the decision

`outcome` is `forward`, `approve`, `return` or `reject`. **What each step may do is
configuration, not code:**

| Step | Who | Permission | May |
|---|---|---|---|
| 1 | Sales Support | `agreements.prepare` | forward, return |
| 2 | Regional Sales Manager | `agreements.verify` | forward, return, reject |
| 3 | Consultant | `agreements.approve-consultant` | approve, reject |
| 4 | Commercial Director | `agreements.approve-final` | approve, reject |

Step 1 cannot reject because it checks that a request is *complete*, not whether it is
a good idea; a malformed request goes back to be fixed rather than being closed over a
typo. Steps 3 and 4 cannot return because two signatures exist by then and a return
would discard both.

This settles **D15**, where the BRD contradicts itself. Changing it is an edit to
`AgreementApprovalTemplate`, not a code change — every inbox, timeline and guard
follows.

```http
POST /api/v1/agreement-requests/{id}/steps/2/forward   { "comment": "Targets confirmed." }
POST /api/v1/agreement-requests/{id}/steps/1/return    { "comment": "Cost centre is wrong." }
POST /api/v1/agreement-requests/{id}/steps/2/reject    { "comment": "Margin too thin." }
```

| Failure | Meaning |
|---|---|
| `403 Agreement.StepNotYours` | The caller does not hold that step's permission |
| `409 Agreement.InvalidTransition` | That step is not the one holding the request |
| `409 Agreement.OutcomeNotAllowed` | Not permitted at this step |
| `409 Agreement.AlreadyActedByYou` | The caller raised it, **or** already signed this revision |
| `400 Agreement.ReasonRequired` | A return or reject with no comment |
| `409 Agreement.OverlapsEffective` / `OverlapsPending` | Re-checked at the fourth approval, and the world moved |

**Four eyes has two halves.** The requester never signs; and one person holding two of
the four permissions still signs at most once per revision. Without the second half, a
four-step chain quietly becomes a two-person one. The same person *may* sign again on a
new revision — Sales Support checking the corrected version is exactly right.

### The fourth approval is the one that does work

In a single transaction it:

1. re-checks overlap,
2. snapshots each approved line into an **immutable term**,
3. end-dates any predecessor the day before the new term starts, queuing an
   `EndDateCondition` task,
4. queues a `CreateCondition` task for each new term.

The terms are created in state **`Approved`, not `Effective`** — they are not yet
deducted from anything.

---

## The terms matrix

`GET /agreement-terms` is the screen Commercial lives in: one row per depot and
category with a state badge.

**A term sitting in `Approved` for days is the signal that the SAP queue is not being
worked** — and that the depot is not getting what four people signed.

States: `Approved`, `Effective`, `SapMismatch`, `Superseded`, `Expired`, `Terminated`.

---

## `POST /agreement-terms/{id}/terminate`

For a depot that stops paying, closes, or is found abusing a rate. The reason is
mandatory — this is the one transition that takes something away from a depot — and
an end-date task is queued so SAP stops charging it too.

**A term the platform calls terminated while SAP keeps applying the discount is worse
than no feature at all**, which is why the queue entry is part of the same transaction.

---

## The SAP condition queue

`GET /sap-tasks` defaults to `Pending` and `InProgress` — what the SD team came to do,
not everything ever queued. Oldest deadline first.

```http
POST /api/v1/sap-tasks/{taskId}/done
{ "conditionRecord": "0000012345", "notes": "VK11, sales org 0001" }
```

**Closing a `CreateCondition` task is what makes a term `Effective`**, and therefore
what makes it reach a price. The condition record number is **required**: it is the
evidence, and a confirmation without one is somebody asserting that SAP agrees.

> **This is an attestation standing in for a machine check.** The design's destination
> is a nightly job that reads the record straight out of SAP — which would also catch a
> rate someone changed directly in SAP, something nothing detects today. That job needs
> a condition-record read endpoint the middleware does not expose. `POST
> /agreement-terms/{id}/verify` is specified in the plan and **not implemented** for
> the same reason.

| Failure | Meaning |
|---|---|
| `400 Agreement.ConditionRecordRequired` | No `KNUMH` supplied |
| `409 Agreement.TaskAlreadyClosed` | Already done |
| `409 Agreement.InvalidTransition` | The term is not `Approved` or `SapMismatch` |

---

## Settings — and why they ship empty

### `PUT /settings/category-mappings`

```json
{ "categoryCode": "ROOFING_PROFILE", "sapMaterialPriceGroup": "E1",
  "description": "Roofing Profile", "isActive": true }
```

Upsert on `categoryCode`. **Nothing in the discount programme works until these rows
exist**: a rate is agreed per category, SAP files it against a material price group,
and this is the join. It also resolves a quotation line's category.

It ships empty because **D14 is unanswered** and only the business can answer it.
Inventing the mapping would put fictional SAP keys beside real ones — the same reason
this platform does not seed depots or materials.

### `PUT /settings/pickup-rules`

Omit `ruleId` to create; pass it to update. The rate is **D13** — the app shows
1–1.5%, the BRD does not mention the discount, and nobody has confirmed SAP holds a
condition for it. Until a rule is configured, **no pickup discount is applied
anywhere**.

The most specific matching rule wins: a category-scoped rate beats a blanket one,
because someone wrote the narrower rule deliberately.

---

## Not implemented

| Route in the plan | Blocked on |
|---|---|
| `POST /agreement-terms/{id}/verify` | The SAP condition-record read |
| `POST /rebates/{period}/close` | A billing read, plus D19 and D24 |
| `POST /rebate-settlements/{id}/approve` | Same |
| `POST /agreement-imports` | Needs the real spreadsheets. **Do this before launch** |
