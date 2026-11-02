# Quotations — Mobile API

**Base:** `/api/v1/mobile/quotations` · **Envelope:** `MobileApiResponse<T>` ·
**Errors:** RFC 9457 problem documents with a stable `errorCode`
**OpenAPI:** tagged `Mobile.Quotations`, in the `mobile` and `v1` documents
**Status:** Active · **Last updated:** 2026-09-11

---

## The three rules a client must follow

1. **Compute nothing.** Render `totals` and each line's `gross` / `discountTotal` /
   `net` exactly as they arrive. Every write returns the recalculated document, and
   `GET .../preview` returns it without changing anything.
2. **Send intent, never money.** Material codes, quantities and discount *percentages*
   go up. Prices, amounts, totals, tax and approval levels come down.
3. **The app never sends a quotation to SAP.** A representative's responsibility ends
   at **Admin Review**. There is no mobile route that reaches SAP, no mobile role holds
   `quotations.sap`, and the aggregate refuses a submission that is not approved — so
   this is not a rule the app has to remember, it is one it cannot break.

Render a price as all four of its fields — `0.475 US3 / KG`, or
`47.50 US3 / 100 KG` when `pricingUnit` is not 1. The amount alone means eight
different things in this catalogue.

---

## Endpoints

| Method | Route | Permission | Purpose |
|---|---|---|---|
| `GET` | `/` | `quotations.read` | List, paged |
| `POST` | `/` | `quotations.create` | Open a quotation |
| `GET` | `/{id}` | `quotations.read` | One document in full |
| `PUT` | `/{id}` | `quotations.update` | Replace the editable header |
| `POST` | `/{id}/lines` | `quotations.update` | Add a material, priced by the server |
| `PUT` | `/{id}/lines/{lineId}` | `quotations.update` | Change a quantity |
| `DELETE` | `/{id}/lines/{lineId}` | `quotations.update` | Remove a line |
| `PUT` | `/{id}/discounts` | `quotations.update` | Replace the manual discounts |
| `GET` | `/{id}/preview` | `quotations.read` | Price the draft without changing it |
| `POST` | `/{id}/reprice` | `quotations.update` | Re-read prices from SAP and take them |
| `POST` | `/{id}/submit` | `quotations.create` | Send for approval |
| `POST` | `/{id}/cancel` | `quotations.update` | Withdraw |
| `GET` | `/{id}/history` | `quotations.read` | The approval trail |

Everything except `GET /` and `GET /{id}/history` returns a `QuotationDetailDto`;
`POST /` returns `201` with a `Location` header.

---

## `GET /` — list

| Parameter | Notes |
|---|---|
| `status` | Any concrete `QuotationStatus` name **or** a tab group (`Drafts`, `Waiting`, `WithDepot`, `Won`, `Closed`). Case-insensitive |
| `depotId` | Restrict to one depot |
| `page` · `pageSize` | One-based; default 20, clamped to 100 |

Pagination arrives in `metadata` (`page`, `pageSize`, `totalRecords`, `totalPages`).

An unrecognised `status` matches **nothing**, not everything — a typo that silently
returned the whole list is how a representative ends up looking at another tab's
documents.

### Filtering by sales representative

**There is no `ownerUserId` parameter, and the app must not send one.** The scoping is
automatic and comes from the access token:

| Caller | Sees | How |
|---|---|---|
| A representative (`quotations.read`) | **Only the quotations they raised** | The handler adds `WHERE owner_user_id = <caller>` before any other filter |
| A supervisor who also holds `quotations.readall` | Everyone's | The ownership filter is skipped |

So "my quotations" needs no filter at all — `GET /api/v1/mobile/quotations` already
returns exactly that for a representative. The owner is `owner_user_id`, set to the
user who created the quotation and never reassigned.

**This is enforced, not a convenience.** A representative cannot widen it by sending a
parameter, and another representative's quotation answers `404` on the detail route
rather than `403` — naming it would confirm a commercial document they have no right
to know exists.

> **Gap, if the app has a supervisor view.** A supervisor holding `quotations.readall`
> sees the whole team's book on mobile with **no way to narrow it to one
> representative** — the parameter exists on the query but the mobile controller pins
> it to null. The admin surface does expose it
> (`GET /api/v1/quotations?ownerUserId=…`, see [admin.md](admin.md)). Ask before
> building a per-rep filter against this endpoint.

### The five tab groups

Every row carries **`statusGroup`** alongside `status`. Bind the tabs to `statusGroup`
and the chip inside the row to `status` — the grouping rule lives on the server so it
cannot drift between the app and the portal.

| Group | Statuses it covers |
|---|---|
| `Drafts` | `Draft`, `Returned` |
| `Waiting` | `PendingApproval`, `Approved`, `SubmittingToSap`, `SapFailed`, `SubmittingOrder`, `OrderFailed` |
| `WithDepot` | `Quoted` |
| `Won` | `Accepted`, `Ordered` |
| `Closed` | `Rejected`, `Cancelled`, `Lost`, `Expired` |

The statuses past `Approved` are modelled by the domain but **no endpoint reaches them
in this release** — see "After submit". Handle them anyway: a client that switches on
`status` and throws on an unknown name will break on the day the SAP phase ships.

A list row carries `id`, `number`, `depotId`, `depotName`, `status`,
`statusGroup`, `currency`, `net`, `lineCount`, `validTo`, `createdAt`, `updatedAt` —
enough to draw the card without a second call. `net` is the SAP net once there is one
and the estimate until then.

---

## `POST /` — open a quotation

```json
{ "depotId": "…", "shipmentType": "Pickup", "shipTo": null }
```

`shipmentType` defaults to `Pickup`. The document starts as a `Draft` with no lines
and no currency, valid from today for the configured period (15 days by default).

| Failure | Meaning |
|---|---|
| `404 Quotation.NotFound` | No such depot, **or** not one the caller may see |
| `422 Pricing.DepotNotPriceable` | The depot has no SAP sales area, so there is nothing to quote |

---

## `PUT /{id}` — the header

```json
{
  "shipmentType": "Delivery",
  "shipTo": "Phnom Penh warehouse",
  "paymentTerm": "NT30",
  "depotReference": "PO-4471",
  "remarks": null
}
```

**This replaces the header — send every field the screen holds, every time.**
`shipmentType` is the only required one; the other four are nullable, and a field left
out is cleared, not kept. A PATCH-shaped call that sends `remarks` alone will wipe the
payment term and the depot's PO number.

`shipmentType` is `Pickup` or `Delivery`. Choosing `Delivery` does not require
`shipTo` here — that is checked at submit, so a representative can set the shipment
type before they know the address.

---

## `POST /{id}/lines` — add a material

```json
{ "materialNumber": "1500000017", "quantity": 10000, "unit": "KG" }
```

`unit` is optional and defaults to the price's own condition unit. Supplying a
different one is **refused, not converted** — the platform does not hold the material
master's conversion factors.

| Failure | Meaning |
|---|---|
| `422 Quotation.MaterialNotPriced` | SAP answered and holds no price for this depot and material |
| `422 Quotation.MultiplePrices` | SAP holds more than one valid price. The line is blocked rather than priced from whichever arrived first |
| `422 Quotation.MixedCurrency` | The price is in a different currency from the document's |
| `422 Quotation.DuplicateLine` | This material is already on the document |
| `422 Quotation.UnitMismatch` | The quantity is not in the price's unit |
| `409 Quotation.NotEditable` | The document has been submitted |
| `502 Quotation.PriceUnavailable` | SAP could not be read. **Do not offer manual price entry** |

The last row is the one that matters most in the app. "No price" and "prices
unavailable" are different status codes precisely so a SAP outage cannot look like a
material the business has not priced.

---

## `PUT /{id}/discounts` — manual discounts

```json
{ "lines": [ { "lineId": "…", "percent": 1.5, "reason": "volume" } ] }
```

**Send the complete set the screen shows.** A line left out has its manual discount
removed. Standing agreement rates are not in this request and cannot be changed
through it — they carry four signatures and arrive with `editable: false`.

A percentage above the caller's authority is **accepted**. What it costs is the
approval level, which `GET .../preview` reports as `requiredApprovalLevel`. Show the
representative what they are asking for rather than blocking the chip.

| Failure | Meaning |
|---|---|
| `422 Quotation.DiscountCapExceeded` | The line's total deduction exceeds policy. Refused, not trimmed |
| `422 Quotation.DiscountExceedsGross` | The deductions come to more than the line |

---

## `GET /{id}/preview` — the screen's source of truth

**One call for the whole draft**, debounced on the client — not one call per material.

```json
{
  "quotationId": "…",
  "lines": [ … ],
  "totals": { "currency": "US3", "gross": 4750.000, "discountTotal": 71.250,
              "net": 4678.750, "isEstimate": true, "tax": null },
  "warnings": [ { "code": "Quotation.PriceAgeing", "lineId": "…" } ],
  "manualDiscountLimitPercent": 10,
  "lineDiscountCapPercent": 15,
  "requiredApprovalLevel": 1
}
```

- `manualDiscountLimitPercent` and `lineDiscountCapPercent` come from the server, so
  the discount chips are not a constant in the app. A cap that lives in two places is
  a cap that disagrees with itself.
- `tax` is always `null`. SAP determines tax from tax classification; the field exists
  so no client invents one.
- `isEstimate` is `true` for the whole of this release. Anything printed while it is
  true carries a draft watermark.

Preview prices from the snapshots already on the lines, so it is fast enough to sit
behind a keystroke debounce. An ageing price is a **warning**, not a refusal.

---

## `POST /{id}/submit` — and the price-changed loop

Prices are re-read from SAP here. A line whose price moved stops the submit:

```text
POST .../submit    →  409 Quotation.PriceChanged
POST .../reprice   →  200, the document with the new prices and new totals
   (show the representative the difference)
POST .../submit    →  200, PendingApproval
```

The loop exists because the representative has been showing the depot figures from
the snapshot. Silently substituting new ones would put a number into an approval queue
that nobody was shown.

`reprice` is all-or-nothing: one unreadable price stops the whole repricing, because a
document half of whose lines are current is worse than one that is plainly out of date.

| Failure | Meaning |
|---|---|
| `422 Quotation.NoLines` | Nothing to submit |
| `422 Quotation.ShipToRequired` | Delivery with no ship-to |
| `409 Quotation.PriceChanged` | Call `reprice`, show the difference, submit again |
| `502 Quotation.PriceUnavailable` | SAP could not be read. Try again later |

---

## `POST /{id}/cancel`

**No body.** The cancel is unconditional for a document the caller may edit; there is
no reason field on this route. (The portal's approve / return / reject decisions carry
a reason — that is `api/admin.md`, not this surface.)

Cancelling is terminal: the document moves to `Cancelled`, joins the `Closed` tab, and
cannot be reopened. Confirm it in the app.

---

## After submit — "Admin Review"

The document is `PendingApproval` and read-only. **Show `statusDisplay`, branch on
`status`.**

```json
{ "status": "PendingApproval", "statusGroup": "Waiting", "statusDisplay": "Admin Review" }
```

`statusDisplay` is localised server-side (EN/KM) from the request's language, so the
business can rename the step without breaking a client. `status` is the stable code and
is what your `switch` should read; `statusGroup` drives the tabs.

From here the document is out of the representative's hands. An administrator approves,
returns or rejects it, and — as a **separate** action in the web portal — puts it into
SAP. Statuses a client will then see:

| `status` | `statusDisplay` | What happened |
|---|---|---|
| `Approved` | Approved | Released internally. **Not yet in SAP** |
| `SubmittingToSap` | Submitting to SAP | An administrator triggered the submission |
| `Quoted` | Submitted to SAP | SAP holds it; `sapQuotationNumber` is set |
| `SapFailed` | SAP submission failed | SAP refused. An administrator will retry |

Handle all of them. A client that throws on an unknown `status` will break the first
time a quotation reaches SAP. An approver in the portal approves,
returns or rejects it.

- **Returned** makes it editable again with `revision` incremented and
  `decisionReason` set — show that reason; it is the whole point of a return.
- **Rejected** is terminal. The representative raises a new quotation.
- **Approved** currently rests there. There is no SAP quotation, no depot
  accept/decline and no order — those are later phases.

---

## Errors, generally

Failures are problem documents, not the envelope. Branch on `errorCode`, never on
`detail` — the code is the contract and the message is for developers and logs. The
client localises from the code.

`404` covers "no such document" and "not yours" alike, deliberately.

### Every code this surface can return

| Code | Status | When |
|---|---|---|
| `Quotation.NotAuthenticated` | `401` | No user on the token |
| `Quotation.NotFound` | `404` | No such quotation or depot — or not one the caller may see |
| `Quotation.LineNotFound` | `404` | No such line on this document |
| `Quotation.NotEditable` | `409` | The document has left `Draft` / `Returned` |
| `Quotation.InvalidTransition` | `409` | The requested move is not legal from the current status |
| `Quotation.PriceChanged` | `409` | Submit found SAP prices had moved — `reprice`, show the difference, submit again |
| `Quotation.QuantityInvalid` | `422` | Quantity is zero or negative |
| `Quotation.UnitMismatch` | `422` | The quantity is not in the price's unit — refused, never converted |
| `Quotation.DuplicateLine` | `422` | That material is already on the document |
| `Quotation.MaterialNotPriced` | `422` | SAP answered and holds no price for this depot and material |
| `Quotation.MaterialNotSellable` | `422` | The material is not sellable to this depot |
| `Quotation.MultiplePrices` | `422` | SAP holds more than one valid price; the line is blocked rather than guessed |
| `Quotation.MixedCurrency` | `422` | The price's currency differs from the document's |
| `Quotation.DiscountPercentInvalid` | `422` | A percentage outside 0–100 |
| `Quotation.DiscountCapExceeded` | `422` | The line's total deduction exceeds policy — refused, not trimmed |
| `Quotation.DiscountExceedsGross` | `422` | The deductions come to more than the line |
| `Quotation.NoLines` | `422` | Nothing to submit |
| `Quotation.ShipToRequired` | `422` | `Delivery` with no ship-to |
| `Quotation.ReasonRequired` | `422` | A decision that needs a reason was sent without one |
| `Quotation.PriceUnavailable` | `502` | SAP could not be read. **Never offer manual price entry** |

`Quotation.ApproverIsAuthor` exists but is raised only by the portal's approval
routes; it cannot reach this surface.

The pairing that matters most in the app is `MaterialNotPriced` (422) against
`PriceUnavailable` (502). They are different status codes precisely so a SAP outage
cannot be shown as a material the business has not priced.
