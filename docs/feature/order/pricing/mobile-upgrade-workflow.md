# Pricing — Mobile upgrade workflow

**Purpose:** migrate the Flutter app onto the real SAP pricing integration.
**Scope:** `/api/v1/mobile/pricing`, plus the `depotId` filter on `/api/v1/mobile/materials`.
**Status:** Backend deployed · **Last updated:** 2026-09-10

> [!CAUTION]
> **This release contains breaking changes.** Prices are now real, the response is
> paged, and an item carries a unit it did not carry before. An app built against the
> previous shape will show **fifty of 3,869 prices** and render them **without their
> unit** — both silently. Read §2 before shipping.

---

## 1. What changed, and why it had to

The old backend served **invented prices** from a development mock, because the SAP
middleware had no Pricing controller. It was deployed between 2026-09-04 and
2026-09-10. The mock is now deleted; there is no switch that brings it back.

Turning the real integration on exposed four defects, each of which produced a
**plausible-looking wrong answer** rather than an error:

| Was | Is | What the app would have shown |
|---|---|---|
| Rate read from `Amount` | SAP sends **`UnitPrice`** | every price `null` |
| Dates parsed as `yyyyMMdd` | pricing sends **`dd-MM-yyyy`** | `01-09-2026` as **9 January** — eight months stale |
| Open-ended sentinel `99991231` | it is **`31-12-9999`** | an unexpiring price shown as expired |
| Condition type `PR00` | this business prices on **`ZP01`** | zero rows — "this depot has nothing to sell" |

All four are fixed server-side. Nothing is required of the app for them.

---

## 2. Breaking changes — do these before shipping

### 2.1 The response is paged

Previously the endpoint returned every price in one array. A single walk-in depot
prices **3,869 materials**; that response was several hundred kilobytes and twenty
sequential SAP calls.

Now: **50 per page, 200 maximum, and there is no "give me everything" parameter.**

```jsonc
"data": {
  "items": [ /* 50 */ ],
  "page": { "number": 1, "size": 50, "totalCount": 3869, "totalPages": 78, "hasMore": true }
}
```

**An app that renders `items` as the complete price list shows 1.3% of it.** Read
`page.hasMore` and request `?page=2`.

### 2.2 A price is not a number

An item now carries `conditionUnit` and `pricingUnit`. The full statement is:

> **`price` `currency` per `pricingUnit` `conditionUnit`**

This catalogue is quoted in **eight** units — `BAG`, `KG`, `M`, `PAC`, `PC`, `ROL`,
`SET`, `UNI`. `0.475` alone means eight different things.

`pricingUnit` is `1` on every record today. **Do not hard-code it.** SAP prices "per
100 KG" as a matter of routine, and an app that assumed 1 would be wrong by a factor
of a hundred with nothing on screen to suggest it.

### 2.3 `currency` is usually `US3`, not `USD`

`US3` appears on 3,867 of 3,869 records; `USD` on 2. Both are real SAP currency codes,
passed through exactly as sent. **Do not assert `USD` and do not "correct" `US3`.**

### 2.4 One material can return more than one price

`?materialNumber=2400000466` returns **two** valid condition records — `100.000 USD`
per M and `2.765 US3` per M — differing by material price group and release status.

**Do not write `items[0]`.** Which record wins is an open commercial question, not a
mapping one; until the business decides, show both or ask. Every other material in the
catalogue returns one.

### 2.5 `raw` is now `null`

It used to echo SAP's field names on every row. That was scaffolding for the period
when the contract was guessed. It is now populated **only** on a row the mapper could
not read — such a row also has `price: 0` and a blank currency, and
`source.recordsUnmapped` counts them. Never bind a feature to `raw`.

---

## 3. New capabilities worth adopting

### 3.1 Look a price up by material

Three spellings are accepted and behave identically:

```
?materialNumber=1500000017     # matches the name used everywhere else in this API
?material=1500000017
?materials=1500000017,1500000018
```

`materialNumber` was added because it is what the platform calls this everywhere else
(`/materials/{materialNumber}/stock`, the Postman `{{materialNumber}}` variable).
Before, sending that name was **silently ignored** and you received page 1 of the whole
catalogue.

### 3.2 Show only what the depot can buy

Every mobile material surface now accepts `depotId`:

| Endpoint | Parameter |
|---|---|
| `GET /mobile/materials` | `?depotId=` |
| `GET /mobile/materials/search` | `?depotId=` |
| `GET /mobile/materials/selection/categories` | `?depotId=` |
| `POST /mobile/materials/selection/facets` | `selection.depotId` |
| `POST /mobile/materials/selection/materials` | `selection.depotId` |

Sellable means SAP holds a price for it in that depot's sales area — 3,832 SKUs
instead of 13,499. It scopes **facet options too**, so the guided finder keeps its
no-dead-ends promise. See [../material/sellability.md](../material/sellability.md).

A depot with no SAP sales area answers **422 `Pricing.DepotNotPriceable`**. It
never silently falls back to the full catalogue — handle the 422.

---

## 4. Migration steps, in order

**Step 1 — update the model.** Add `conditionUnit`, `pricingUnit`; keep `raw` nullable.

```dart
class MobilePriceItem {
  final String material;
  final double price;
  final String currency;
  final String? conditionUnit;   // new
  final num? pricingUnit;        // new
  final DateTime? validFrom;
  final DateTime? validTo;

  /// Present only on a row the server could not map. price == 0 there.
  final Map<String, dynamic>? raw;
}

class MobilePricingPage {
  final int number, size, totalCount, totalPages;
  final bool hasMore;
}
```

**Step 2 — render the unit.** Everywhere a price appears. `pricingUnit == 1` may be
rendered as `0.475 US3 / KG`; anything else must show the quantity: `47.50 US3 / 100 KG`.

**Step 3 — page the depot price list.** Follow `page.hasMore`. Do not loop to the
end on open — 78 pages is 78 requests; page on scroll.

**Step 4 — switch material lookups to `materialNumber`.** A material-detail screen
should send `?materialNumber=<code>` rather than fetching a page and searching it
client-side.

**Step 5 — stop assuming one price per material.** Handle a 2-item response.

**Step 6 — pass `depotId` on catalogue screens** opened in a depot's context, and
handle `422`.

**Step 7 — drop any `raw` reads.**

---

## 5. Realtime is unchanged, and stays unpaged

`PricingUpdated` over `/hubs/pricing` still carries `items` + `updatedAt`, with the
**full** list rather than a page.

That is deliberate: broadcasting page one would leave every subscriber holding a
silently truncated price list. It does mean the event can be large.

> [!NOTE]
> **Known open item.** A ~500 KB broadcast is its own problem, and the likely fix is
> for the event to carry only *changed* materials. That is a design decision about what
> "pricing updated" means and has not been taken. Until it is, treat `PricingUpdated`
> as "your prices moved — refetch page 1" rather than as the data itself.

Keep using `updatedAt` to discard events older than your last known state.

---

## 6. Reference response

`GET /api/v1/mobile/pricing/depots/{depotId}?materialNumber=1500000017`, captured
live 2026-09-10:

```json
{
  "success": true,
  "message": "ទាញយកតម្លៃបានជោគជ័យ។",
  "data": {
    "items": [
      {
        "material": "1500000017",
        "price": 0.475,
        "currency": "US3",
        "conditionUnit": "KG",
        "pricingUnit": 1,
        "validFrom": "2025-10-29",
        "validTo": "9999-12-31",
        "raw": null
      }
    ],
    "source": { "recordsReturned": 1, "recordsUnmapped": 0, "erpAnswered": true },
    "page": { "number": 1, "size": 50, "totalCount": 1, "totalPages": 1, "hasMore": false }
  },
  "metadata": null,
  "traceId": "…",
  "timestamp": "…"
}
```

`validTo` `9999-12-31` is SAP's open-ended sentinel. Render it as "no end date", not as
a year 9999.

### Errors

| Status | Code | Meaning |
|---|---|---|
| `404` | `Pricing.DepotNotFound` | No such depot, **or** not one this rep may see — deliberately indistinguishable |
| `422` | `Pricing.DepotNotPriceable` | Depot has no SAP sales area. Not a fault |
| `502` | `Sap.*` | ERP unreachable or errored. **Not** the same as "no prices" — never render it as an empty list |

---

## 7. Acceptance checklist

- [ ] A price never appears without its unit.
- [ ] `pricingUnit` is read, not assumed to be 1.
- [ ] `US3` renders correctly; nothing asserts `USD`.
- [ ] The depot price list pages; `hasMore` drives it.
- [ ] Material lookup uses `materialNumber` and does not assume one result.
- [ ] `422` is handled distinctly from `404` and from an empty list.
- [ ] `502` shows "prices unavailable", never "no prices".
- [ ] Catalogue screens in a depot context pass `depotId`.
- [ ] No code reads `raw`.

## 8. Backend verification already done

| Check | Result |
|---|---|
| Full read, sales org 0001 / price group 11 | 3,869 records, **0 unmapped** |
| Prices | exactly SAP's `UnitPrice`, three decimals |
| `01-09-2026` | `2026-09-01` — day-first |
| `31-12-9999` | `9999-12-31` — sentinel survives |
| Default page | 50 items, **8 KB in 0.77 s** (was ~500 KB, 20 SAP calls) |
| `?pageSize=99999` | clamped to 200 |
| `?materialNumber=` / `?material=` / `?materials=` | identical single item |
| Sellability filter | 13,499 → 3,832 SKUs; facets 4 → 2 options |
| Unit tests | 305 passing |

Contract details: [sap-integration.md](sap-integration.md) · test data:
[test-data.md](test-data.md) · endpoint reference: [api/mobile.md](api/mobile.md)
