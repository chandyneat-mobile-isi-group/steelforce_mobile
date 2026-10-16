# Promotions & Discounts — Mobile API

**Base:** `/api/v1/mobile` · **Envelope:** `MobileApiResponse<T>` ·
**Errors:** RFC 9457 problem documents with a stable `errorCode`
**OpenAPI:** tagged `Mobile.Promotions`, in the `mobile` and `v1` documents
**Status:** Active · **Last updated:** 2026-09-12

---

## The three rules a client must follow

1. **A representative chooses nothing.** A depot's rates were agreed in advance by four
   people. The app shows them and the server applies them; there is no "pick a
   promotion" step.
2. **`approvedNotEffective` is not active.** A term four people signed that SAP has not
   confirmed is returned with that status and is **not** deducted. Render it greyed.
   Showing it as active promises a price the invoice will not show.
3. **A rebate is not a discount.** A volume tier is earned on the month's total and
   settled afterwards. Show progress; never show it as a deduction.

---

## Endpoints

| Method | Route | Permission |
|---|---|---|
| `GET` | `/depots/{depotId}/incentives?shipment=` | `depots.read` |
| `GET` | `/depots/{depotId}/agreements` | `depots.read` |
| `GET` | `/me/discount-authority` | *authenticated only* |
| `GET` | `/category-mappings` | `agreements.read` |
| `GET` | `/agreement-requests` | `agreements.read` |
| `GET` | `/agreement-requests/{requestId}` | `agreements.read` |
| `POST` | `/agreement-requests` | `agreements.request` |
| `PUT` | `/agreement-requests/{requestId}` | `agreements.request` |
| `POST` | `/agreement-requests/{requestId}/submit` | `agreements.request` |
| `POST` | `/agreement-requests/{requestId}/withdraw` | `agreements.request` |

`GET /me/discount-authority` carries no permission attribute on purpose: every
authenticated user has *some* limit, and gating it would leave the discount chips
blank for whoever was missed.

---

## `GET /depots/{id}/incentives` — the promotions view

Groups, in display order. **A group with no cards is omitted** — an empty group with a
heading implies the business has none, rather than that the feature is unbuilt.

| Group id | Contains |
|---|---|
| `depot_discount` | The depot's standing agreements, effective or not |
| `cod_pickup` | The pickup rule, when one is configured |
| `depot_requests` | Requests still on the approval chain |
| `free_goods` | **Never returned** — free-goods rules are not built |

Pass `shipment=Pickup` so a collection discount comes back `active` rather than
`pending`. **A card whose requirement the draft does not meet is still returned**, with
`requires: ["pickup"]` — the representative needs to know that collecting would earn
another percent.

Card `status` values: `active`, `pending`, `approvedNotEffective`, `mismatch`. Only
`active` on-invoice cards affect a price.

`value` is a tagged union: `{"type":"percent","percent":2.0}` today. The `buyGet` shape
is declared for free goods and never returned.

---

## `GET /depots/{id}/agreements` — the plainer list

For depot and visit screens. A tiered agreement carries its whole ladder in
`rebateTiers`, and `percent` is the **top rung** — what the depot earns if it reaches
the target. `targetAmount` is that rung's floor.

`status` is `Active`, `ApprovedNotEffective`, `Mismatch` or `Ended`. Superseded terms
and terms whose end date has passed are excluded.

---

## `GET /me/discount-authority` — the chips

```json
{ "level": 1, "roleName": "Sales Representative",
  "maxManualDiscountPercent": 3.0, "lineDiscountCapPercent": 7.0,
  "currency": "US3", "suggestedChips": [0.5, 1.0, 1.5, 2.0, 2.5, 3.0] }
```

**`maxManualDiscountPercent` is where escalation starts, not where the input stops.** A
larger percentage is accepted and routes the quotation to a higher approver — refusing
it would just mean the representative rings the office. Show the limit; do not enforce
it.

The caller's level is the highest rung whose permission they hold, so an approver
browsing the app sees their own larger limit.

Served from the `Quotations` configuration section rather than a `discount_authorities`
table — see [../README.md](../README.md#one-deliberate-deviation-from-the-plan).

---

## `POST /agreement-requests` — raising a request

**Send `clientRequestId`.** It makes the call idempotent: a draft written offline and
synced twice produces one request, and the second call returns the first one rather
than an error. A request needs no live price, which is what makes offline drafting
feasible here and not on a quotation.

```json
{
  "clientRequestId": "e89d1b09-…",
  "depotId": "3fa85f64-…",
  "scopeType": "DEPOT",
  "remarks": "Depot opening a second branch; requesting volume assistance.",
  "lines": [
    { "categoryCode": "ROOFING_PROFILE", "entryMode": "FLAT_PERCENT",
      "nature": "ON_INVOICE", "percent": 2.5,
      "validFrom": "2026-10-01", "validTo": "2026-12-31" },
    { "categoryCode": "REBAR", "entryMode": "TIERED",
      "nature": "VOLUME_REBATE", "validFrom": "2026-10-01", "validTo": null,
      "tiers": [
        { "tierOrder": 1, "minAmount": 0,    "maxAmount": 2500, "percent": 0 },
        { "tierOrder": 2, "minAmount": 2500, "maxAmount": 5000, "percent": 1.5 },
        { "tierOrder": 3, "minAmount": 5000, "maxAmount": null, "percent": 3 }
      ] }
  ]
}
```

**`entryMode` is the BRD's word; `nature` is what the server acts on.** A flat
percentage with a monthly target is a rebate, and only `nature` says so.

| Failure | Meaning |
|---|---|
| `404 Agreement.NotFound` | No such depot, or not one the caller may see |
| `422 Agreement.CategoryUnmapped` | The category has no SAP price group. **Expected until D14 is configured** |
| `422 Agreement.SegmentScopeNotSupported` | `scopeType: "SEGMENT"` — campaigns are not built |
| `422 Agreement.RetroactiveNotAllowed` | `validFrom` is in the past |
| `422 Agreement.TiersInvalid` | Gaps, overlaps, or a ladder not starting at zero |
| `422 Agreement.TiersMismatched` | A tiered line with no tiers, or a flat line with them |
| `422 Agreement.DuplicateCategory` | The same category twice |
| `422 Agreement.PercentRequired` | A flat line with no percentage |

> **The category list is not free text.** Offer only what
> `GET /category-mappings` returns — a category missing from it has no SAP mapping, so
> a rate on it could never be charged.

---

## `PUT /agreement-requests/{id}` — editing

Send the **complete** set of lines the form is showing; a category left out is one the
representative removed. Only the author may edit, and only while `Draft` or `Returned`
— anything else is `409 Agreement.NotEditable`.

---

## `POST .../submit` — onto the chain

Moves the request to step 1 and opens all four signature slots at once, so the timeline
can show how many signatures are still to come.

| Failure | Meaning |
|---|---|
| `422 Agreement.NoLines` | Nothing to approve |
| `409 Agreement.OverlapsEffective` | The depot already holds an effective rate for that category over those dates |
| `409 Agreement.OverlapsPending` | Another request for the same scope is already on the chain |

Both overlaps are **re-checked at final approval**, because the world changes while
four people sign.

---

## `POST .../withdraw`

Allowed while `Draft`, `Returned`, or only with Sales Support. Once the Regional Sales
Manager has acted, withdrawing would discard a signature — the answer is then `409`.

---

## Reading a request

`GET /agreement-requests/{id}` returns the lines and a `timeline` of all four steps for
the revision in play, including ones nobody has reached (`status: "Waiting"`).

**Show `decisionReason` on a returned request.** It is the whole point of a return,
and the representative cannot act without it.

A returned request comes back `isEditable: true` with `revision` incremented.
Resubmitting **restarts at step 1** — every signer sees the version they signed.

---

## Errors, generally

Failures are problem documents, not the envelope. Branch on `errorCode`, never on
`detail`. `404` covers "no such record" and "not yours" alike, deliberately: a depot's
rates are another depot's negotiating position.
