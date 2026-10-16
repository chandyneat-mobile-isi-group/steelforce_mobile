# Pricing — Admin API

Base: `/api/v1/pricing` · Envelope: `ApiResponse<T>` ·
Audience: `Admin | HeadOfSales` · Module: `Price Lists`

The same logic as the mobile surface behind a different envelope — the split every
other module on this platform makes. A price shown in the portal and a price shown in
the field are the same number from the same SAP call.

---

## `GET /api/v1/pricing/depots/{depotId}`

Current SAP prices for one depot.

**Permission:** `depots.read`, plus the same row-level scoping the field app gets.
Portal users normally hold `depots.readall` and pass it trivially, but the check is
not skipped on that assumption — see [security.md](../security.md).

### Narrowing to specific materials

| Parameter | Meaning |
|---|---|
| `materials` | Material codes to price. Omit for everything priced for the depot |
| `material` | Singular alias for the same thing |

Repeated, comma-separated, semicolon-separated and the singular name are all accepted
and equivalent:

```text
?materials=1100000000&materials=1100000003
?materials=1100000000,1100000003
?material=1100000000
```

Duplicates collapse and blanks are dropped. **Each material is a separate SAP round
trip**, so a short list is far faster than the whole price list — and a code SAP does
not price is simply absent from `items` rather than an error.

The filter is applied **both** as a SAP query parameter and again to the response, so a
request naming materials can only ever return those materials — see
[api/mobile.md](mobile.md#narrowing-to-specific-materials).

### 200

```json
{
  "data": {
    "items": [
      {
        "material": "2400000466",
        "price": 100.0,
        "currency": "USD",
        "conditionUnit": "M",
        "pricingUnit": 1,
        "validFrom": "2026-09-01",
        "validTo": "9999-12-31",
        "raw": null
      }
    ],
    "source": {
      "recordsReturned": 1,
      "recordsUnmapped": 0,
      "erpAnswered": true
    }
  },
  "meta": {
    "correlationId": "0HNOA77TQ7VI1:00000005",
    "timestamp": "2026-09-04T04:10:59.0087802+00:00",
    "pagination": null
  }
}
```

Field meanings — `items[]`, `source` and the **`raw` caution** — are documented once in
[api/mobile.md](mobile.md#items); the payload is identical, only the envelope differs
(`ApiResponse<T>` here, `MobileApiResponse<T>` there).

`pagination` is always null: pricing is not paged at this layer. The ERP paging is
internal to the SAP client.

### Errors

| Status | Code | Meaning |
|---|---|---|
| 401 / 403 | — | Unauthenticated, or lacks `depots.read` |
| 404 | `Pricing.DepotNotFound` | No such depot, or not one this caller may see |
| 422 | `Pricing.DepotNotPriceable` | Depot has no SAP sales area |
| 500 | `Sap.*` | SAP unreachable, errored, or the endpoint is missing |

---

## `POST /api/v1/pricing/depots/{depotId}/publish`

Re-reads the depot's pricing from SAP and pushes it to every handset currently
subscribed to that depot.

**Permission:** `depots.read` **plus row-level ownership** ·
**Audience:** `Admin | Mobile | Integration`

A field representative can publish for depots assigned to them; an administrator
holding `depots.readall` can publish for anyone. Publishing for a depot you may
not see returns **404**, the same answer the reads give.

It deliberately does **not** require `depots.sync`. That permission also carries the
full depot and material master walks — six thousand rows and about a minute of ERP
time — and putting those on every field handset to enable a pricing refresh would be a
far larger grant than this feature needs.

| Query | Type | Meaning |
|---|---|---|
| `materials` | string, repeatable | Restrict the re-read. Omit to republish everything priced for the depot |

Use it after a price change is made in SAP, so the field sees the new terms without
waiting for a pull-to-refresh.

### 204

Published. **Publishing to a depot nobody is subscribed to succeeds and reaches no
one** — that is a normal outcome, not an error.

### Errors

| Status | Code | Meaning |
|---|---|---|
| 401 / 403 | — | Unauthenticated, or lacks `depots.sync` |
| 404 | `Pricing.DepotNotFound` | No such depot, **or** not one this caller may publish for |
| 422 | `Pricing.DepotNotPriceable` | Depot has no SAP sales area |
| 500 | `Sap.*` | SAP unreachable — **nothing was published**, and handsets keep the prices they hold |

---

## What is not here

**Nothing publishes automatically yet.** This endpoint is the operator's trigger; no
job polls SAP for price changes. How often that should happen is a business decision,
and wiring it is one `AddOrUpdateRecurring` in `ISI.BackgroundJobs/DependencyInjection.cs`
beside the existing SAP jobs, sending `PublishPricingUpdateCommand`.
