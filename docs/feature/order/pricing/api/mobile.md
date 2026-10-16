# Pricing — Mobile API

Base: `/api/v1/mobile/pricing` · Envelope: `MobileApiResponse<T>` ·
Audience: `Mobile` · Module: `Price Lists`

**The whole pricing surface is available to the field app.** Three of them are on this
page; the fourth, `POST .../publish`, is on the shared route because it returns no body
and so needs no mobile envelope. All four are scoped the same way: a representative
sees and acts on the depots assigned to them, a supervisor with `depots.readall`
on everyone's.

| Surface | Permission |
|---|---|
| `GET /api/v1/mobile/pricing/depots/{id}` | `depots.read` + ownership |
| `POST /api/v1/pricing/depots/{id}/publish` | `depots.read` + ownership |
| `WS /hubs/pricing` | authenticated + ownership on subscribe |

---

## `GET /api/v1/mobile/pricing/depots/{depotId}`

Current SAP prices for one depot.

**Permission:** `depots.read`, plus row-level scoping — a representative sees their
own depots, a supervisor with `depots.readall` sees everyone's.

The depot is in the **route**, not the query string: SAP prices a material *for a
depot*, so a pricing request without one has no answer, and a query parameter would
make the subject look optional.

### Narrowing to specific materials

| Parameter | Meaning |
|---|---|
| `materials` | Material codes to price. Omit for everything priced for the depot |
| `material` | Singular alias for the same thing |

**All of these are equivalent** — repeated, comma-separated, semicolon-separated, or
the singular name:

```text
?materials=1100000000&materials=1100000003
?materials=1100000000,1100000003
?materials=1100000000;1100000003
?material=1100000000
?material=1100000000,1100000003
```

Blank entries are dropped and duplicates collapsed, so `?materials=A&materials=A` is
one ERP call rather than two identical ones.

> [!NOTE]
> **Every material named is a separate SAP round trip** — `GetPriceByPaging` takes one
> material, not a list. A quotation screen asking for three prices is far faster than
> omitting the filter; asking for forty is slower than fetching everything.

A code that does not exist prices as **absent** — it is simply not in `items`. That is
the ERP's answer rather than a validation error, so a filter matching nothing returns an
empty `items` with `erpAnswered: true`.

> [!IMPORTANT]
> **The filter is enforced twice, and the second one is the guarantee.** It is pushed
> into SAP (where the work belongs, so the ERP does not send rows nobody wants) *and*
> applied again to the response before it leaves the server. If you name materials,
> **nothing else can come back** — whatever the ERP does.
>
> That second pass is not redundant. Whether the middleware honours its own `material`
> parameter cannot be verified from here, and a service that ignores an unknown query
> parameter answers with the whole price list. A client that asked for one material and
> received forty is likely to render the first row — a different material's price.
> When the safety net fires, the server logs
> `The ERP is not honouring the 'material' parameter`.

### 200

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
      }
    ],
    "source": {
      "recordsReturned": 1,
      "recordsUnmapped": 0,
      "erpAnswered": true
    }
  },
  "metadata": null,
  "traceId": "0HNOA7D1C66TK:00000001",
  "timestamp": "2026-09-04T04:16:30.6672159+00:00"
}
```

### `items[]`

| Field | Type | Notes |
|---|---|---|
| `material` | string | SAP material number |
| `price` | number | Unit price, in `currency` |
| `currency` | string | ISO code, carried on **every item** rather than once on the response — a price without its currency is a number somebody has to remember the currency of |
| `validFrom` | date \| null | First day valid. Null when open-ended |
| `validTo` | date \| null | Last day valid. `9999-12-31` is SAP's open-ended sentinel, passed through as a real date |
| `raw` | object \| null | **Diagnostic only — see the warning below** |

### `source`

| Field | Type | Meaning |
|---|---|---|
| `recordsReturned` | int | Rows mapped into `items` |
| `recordsUnmapped` | int | Rows SAP sent that could not be mapped. **Non-zero means the field-name contract is wrong** — the server log names the fields SAP actually sent |
| `erpAnswered` | bool | Whether SAP answered at all |

`erpAnswered: true` with an empty `items` means *"this depot has no prices"*. That
is a different statement from *"we could not load prices"*, which is an error status —
the two must never render the same way.

> [!CAUTION]
> **`raw` is a debugging aid, not part of the contract. Do not build on it.**
> It echoes the SAP field names while the pricing response contract is still unverified
> (see [sap-integration.md](../sap-integration.md)). Reading `raw["KBETR"]` in the
> Flutter client would make the ERP's schema the mobile app's problem forever, and its
> keys change the moment the real contract is pinned. Use the typed fields. It is
> expected to be removed before release.

### Errors

| Status | Code | Meaning |
|---|---|---|
| 401 | — | No or expired token |
| 403 | — | Lacks `depots.read` |
| 404 | `Pricing.DepotNotFound` | No such depot, **or** not one this caller may see — deliberately indistinguishable |
| 422 | `Pricing.DepotNotPriceable` | Depot exists but has no SAP sales area, typically a locally coded depot awaiting registration |
| 500 | `Sap.*` | SAP unreachable, errored, or the endpoint is missing. **Not** the same as "no prices" |

> [!IMPORTANT]
> **The response is one page.** 50 items by default, 200 maximum, and no way to ask
> for the lot — an unnarrowed price list is 3,869 records. Read `data.page.hasMore`
> and request `?page=2`; a client that renders `items` as the complete price list will
> be showing the depot 1.3% of it.
>
> **Render the unit.** An item reads *`price` `currency` per `pricingUnit`
> `conditionUnit`* — above, 100.00 USD per metre. This catalogue is quoted in `BAG`,
> `KG`, `M`, `PAC`, `PC`, `ROL`, `SET` and `UNI`, so a screen showing `100.00` alone is
> ambiguous.
>
> **`raw` is `null` on a normal row** and populated only when the mapper could not read
> one — those rows carry `price: 0` and a blank currency, and `source.recordsUnmapped`
> counts them. Do not bind a feature to `raw`.
>
> **One material can return more than one price.** `2400000466` returns two valid
> condition records in different currencies; do not assume a single price per material.
> See [test-data.md](../test-data.md).

---

## `POST /api/v1/pricing/depots/{depotId}/publish`

Re-reads the depot's pricing from SAP and pushes `PricingUpdated` to everyone
subscribed to that depot.

**Permission:** `depots.read` plus the same ownership scoping as the reads — a
representative can publish for their own depots, and gets **404** for anyone else's.

There is no `/mobile/` variant: the endpoint returns 204 with no body, so there is no
envelope to differ. Call it on the shared route.

| Status | Meaning |
|---|---|
| 204 | Published. Reaching nobody (no active subscribers) is a normal outcome, not an error |
| 404 | No such depot, or not one this caller may publish for |
| 500 | SAP unreachable — **nothing was published**, and handsets keep the prices they hold |

Useful after the rep changes something in SAP and wants the field to see it without
waiting for a pull-to-refresh. It is not needed for ordinary use: the REST read is
already current by definition.

---

## `WS /hubs/pricing`

The realtime channel. Unversioned and outside `/api`, like the public file route — a
hub path is a transport endpoint rather than a resource.

### Connecting

The token goes in the **query string**, because a WebSocket handshake cannot carry an
`Authorization` header:

```text
wss://<host>/hubs/pricing?access_token=<accessToken>
```

This is accepted on this path only.

### Methods the client calls

| Method | Argument | Behaviour |
|---|---|---|
| `SubscribeToPricingAsync` | `depotId` (Guid) | Joins that depot's group |
| `UnsubscribeFromPricingAsync` | `depotId` (Guid) | Leaves it |

**Send a depot id, never a group name** — the server derives the group, and a
caller who is not entitled gets a `HubException` carrying `Pricing.DepotNotFound`,
the same answer as for a depot that does not exist.

### Event the client receives

`PricingUpdated`:

```json
{
  "items": [
    { "material": "1100000000", "price": 1018.25, "currency": "USD",
      "validFrom": "2026-01-01", "validTo": "9999-12-31" }
  ],
  "updatedAt": "2026-09-04T04:16:30.6672159+00:00"
}
```

The item shape is identical to the REST response, so `MobilePriceItem.fromJson` is
shared client-side. The extra `updatedAt` is the server's clock.

### Client rules that matter

1. **Load over REST first, then subscribe.** A client that only subscribed would show
   nothing until something changed.
2. **Re-fetch over REST after every reconnection.** Group membership dies with the
   connection and there is no replay buffer, so any event that fired while the client
   was away is gone. Re-subscribe as well.
3. **Drop an event whose `updatedAt` precedes your last known state.** This is what
   stops an event queued before a disconnection from overwriting fresher prices.

```text
open app ──► GET /pricing ──► render
                 │
                 └──► connect hub ──► SubscribeToPricingAsync(depotId)
                                          │
                          PricingUpdated ─┴─► if updatedAt > lastKnown: render
                          disconnect ──────► reconnect, GET /pricing, re-subscribe
```
