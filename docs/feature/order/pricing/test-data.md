# Pricing — Test data

> [!NOTE]
> **Real SAP data. There is no mock.** `SAP:UsePricingMock` and
> `MockSapPricingService` were deleted on 2026-09-10, when the middleware's Pricing
> controller went live. Everything below was read off `Live110`; nothing here is
> invented, and no configuration switch can make this feature invent anything.

## What the development connection holds

Read on 2026-09-10 for sales org `0001`, price group `11`, condition type `ZP01`:

| Measure | Value |
|---|---|
| Condition records returned | **3,869** |
| Distinct materials | 3,868 |
| Rows that failed to map | **0** |
| Materials with more than one price | 1 (`2400000466`) |
| Currencies | `US3` on 3,867 rows, `USD` on 2 |
| Condition units seen | `BAG`, `KG`, `M`, `PAC`, `PC`, `ROL`, `SET`, `UNI` (8) |
| Pricing unit | `1` on every row sampled |

Because this is live ERP data, **the figures change without notice**. Assert on shape
and invariants, not on a particular price. The one number safe to depend on is that
`recordsUnmapped` is `0`; if it is not, the contract moved.

### Depots to test with

Real rows in the development database:

| Depot | Code | Id | Sales org | Price group |
|---|---|---|---|---|
| PNP-Walk In Depot | 6100000000 | `01a06a78-33bd-7571-8b0f-b1933d0c6910` | 0001 | 11 |
| BTB-Walk in Depot | 6100000001 | `01a06a78-33ee-7e14-9ebf-0f0318358675` | 0001 | 11 |
| SHV-Walk in Depot | 6100000002 | `01a06a78-33ef-73df-8868-13cea0f3951a` | 0004 | 11 |
| KPC-Walk in Depot | 6100000003 | `01a06a78-33ef-71ac-8325-4e60effef61c` | 0005 | 11 |
| TAK-Walk in Depot | 6100000004 | `01a06a78-33ef-7a16-8c94-9232ef1fa03a` | 0007 | 11 |
| KPT-Walk in Depot | 6100000005 | `01a06a78-33ef-788b-ac6f-663729133e00` | 0006 | 11 |

A depot with no sales area is not priceable and answers **422
`Pricing.DepotNotPriceable`** — a real state, not a fault.

### A material worth testing with

`2400000466` — *C Purlin 125x50x1.60 (SGCC-Z60)* — is the useful one, because it is
the single material that returns **two** condition records for one sales area. Any
client that assumes one price per material breaks on it. See
[sap-integration.md](sap-integration.md#two-prices-for-one-material).

## Calling it

> [!IMPORTANT]
> **The reads are paged.** 50 rows by default, 200 maximum. An unnarrowed price list
> is 3,869 records; there is no parameter that returns them all in one response.
> Follow `data.page.hasMore` and request `?page=2`, `?page=3`, …

```bash
TOKEN=$(curl -s -X POST http://127.0.0.1:5000/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@isigroup.com.kh","password":"<seed password>"}' \
  | python3 -c 'import sys,json;print(json.load(sys.stdin)["accessToken"])')

CUST=01a06a78-33bd-7571-8b0f-b1933d0c6910

# Admin portal — page 1 of 78, ~8 KB
curl -s "http://127.0.0.1:5000/api/v1/pricing/depots/$CUST" -H "Authorization: Bearer $TOKEN"

# A later page, and a bigger one
curl -s "http://127.0.0.1:5000/api/v1/pricing/depots/$CUST?page=2&pageSize=200" \
  -H "Authorization: Bearer $TOKEN"

# Mobile
curl -s "http://127.0.0.1:5000/api/v1/mobile/pricing/depots/$CUST" -H "Authorization: Bearer $TOKEN"

# One material — all four spellings are equivalent
curl -s "http://127.0.0.1:5000/api/v1/pricing/depots/$CUST?material=2400000466" \
  -H "Authorization: Bearer $TOKEN"
curl -s "http://127.0.0.1:5000/api/v1/pricing/depots/$CUST?materials=2400000466,1400000412" \
  -H "Authorization: Bearer $TOKEN"

# Push PricingUpdated to everyone subscribed to this depot -> 204
curl -s -X POST "http://127.0.0.1:5000/api/v1/pricing/depots/$CUST/publish" \
  -H "Authorization: Bearer $TOKEN"

# SAP's answer, untouched — status, content type and body
curl -s -G "http://127.0.0.1:5000/api/v1/pricing/diagnostics/raw" \
  --data-urlencode 'path=/api/Pricing/GetPriceByPaging/Live110?page=1&pageSize=5&validOn=20260910&salesOrg=0001&priceGroup=11&conditionType=ZP01&application=V&material=2400000466&includeA004=X' \
  -H "Authorization: Bearer $TOKEN"
```

## Sample responses

Captured 2026-09-10 for `?material=2400000466`.

### Mobile — `GET /api/v1/mobile/pricing/depots/{id}`

```json
{
  "success": true,
  "message": "Pricing retrieved successfully.",
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
      },
      {
        "material": "2400000466",
        "price": 2.765,
        "currency": "US3",
        "conditionUnit": "M",
        "pricingUnit": 1,
        "validFrom": "2025-01-15",
        "validTo": "9999-12-31",
        "raw": null
      }
    ],
    "source": { "recordsReturned": 2, "recordsUnmapped": 0, "erpAnswered": true },
    "page": { "number": 1, "size": 50, "totalCount": 2, "totalPages": 1, "hasMore": false }
  }
}
```

`page.totalCount` is the size of the whole matching condition set, taken from SAP's own
paging envelope — not a count of what arrived. On an unnarrowed read it is 3,869 across
78 pages.

Read an item as **`price` `currency` per `pricingUnit` `conditionUnit`** — here, 100.00
USD per metre. Rendering `price` alone is wrong: this catalogue is quoted in eight
different units.

`raw` is `null` on a mapped row. It is populated only when the mapper could not read a
row, and such a row also carries `price: 0` and a blank currency —
`source.recordsUnmapped` counts them.

### Admin — `GET /api/v1/pricing/depots/{id}`

The same `items` and `source`, wrapped in `ApiResponse<T>` (`data` + `meta`) rather
than `MobileApiResponse<T>`.

### Realtime — `PricingUpdated` over `/hubs/pricing`

The same item shape plus `updatedAt`, so `MobilePriceItem.fromJson` is shared
client-side. Subscribe with `SubscribeToPricingAsync(depotId)` and connect using
`?access_token=` — see [api/mobile.md](api/mobile.md).

## Verified

Run against the container on 2026-09-10, after the mock was removed:

| Check | Result |
|---|---|
| Admin read, unfiltered | 200, **50 items**, page 1 of 78, `totalCount` 3,869 |
| Payload and latency | **8 KB in 0.77 s** — one SAP call, not twenty |
| `?page=2` | 200, a different 50 |
| `?page=78` | 200, 19 items, `hasMore: false` |
| `?pageSize=99999` | clamped to 200 |
| Mobile read | 200, localised message, same items |
| Single material `?material=` | 200, 2 items — the duplicate-price material |
| Prices | exactly SAP's `UnitPrice`, to three decimals |
| `validFrom` `01-09-2026` | `2026-09-01` — day-first, not 9 January |
| `validTo` `31-12-9999` | `9999-12-31` — the open-ended sentinel survives |
| Units | `conditionUnit` and `pricingUnit` present on every item |
| `raw` on a mapped row | `null` |
| Raw SAP probe | 200, body returned untouched |
