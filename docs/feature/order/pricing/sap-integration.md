# Pricing — SAP integration

> [!NOTE]
> **Live. Both contracts verified 2026-09-10** against
> `https://192.168.100.112:4451`, conId `Live110`. The Pricing controller was deployed
> between 2026-09-04 and 2026-09-10; the block described in earlier revisions of this
> page is resolved, and the development mock has been deleted.
>
> A full read for sales org `0001` / price group `11` returns **3,869 condition
> records, of which 0 fail to map**. That number is the argument that the response
> contract below is right, not merely plausible.

## The endpoint

```text
GET /api/Pricing/GetPriceByPaging/{conId}
```

Recorded in [sap-api-catalogue.md](../../blueprint/sap-api-catalogue.md) as available
and, until this feature, unused. It reads SD condition records.

## The request — verified

Every parameter below is specified in
[sap-openapi.json](../../blueprint/sap-openapi.json). Blanks are omitted rather than
sent empty, because the middleware treats a present-but-empty parameter as a value to
match on for some fields and silently returns nothing.

| Parameter | Sent as | Source |
|---|---|---|
| `validOn` | `yyyyMMdd`, today | `IDateTimeProvider` — the server's clock, never a handset's |
| `salesOrg` | Depot's `DepotSalesArea.SalesOrgCode` | Database |
| `priceGroup` | Depot's `DepotSalesArea.PriceGroupCode` | Database |
| `application` | `V` (sales) | `SAP:PricingApplication` |
| `conditionType` | `ZP01` | `SAP:PricingConditionType` |
| `includeA004` | `X` | `SAP:PricingIncludeA004` |
| `material` | One material code, or omitted | Caller |
| `page`, `pageSize` | 1-based; 200 per page | `SAP:PricingPageSize` |

`releaseStatus` and `materialPriceGroup` are supported by the filter type but not
currently sent. See "Two prices for one material" below for the one case where
`materialPriceGroup` would disambiguate.

> [!IMPORTANT]
> **`conditionType` is `ZP01`, not `PR00`.** PR00 is SAP's standard price condition and
> the obvious default, and it is *empty in this system*: it matches no condition record
> at all, while ZP01 returns 3,869. Defaulting to the textbook condition type produced
> an empty price list that was indistinguishable from a working integration with
> nothing to sell.

> [!IMPORTANT]
> **`includeA004` is sent as `X`, not `true`.** It is typed as a string and handed to
> the RFC as an ABAP flag, where truth is `X` and falsehood is a space. Verified against
> the live middleware:
>
> | Value sent | Answer |
> |---|---|
> | `true` | **HTTP 500** |
> | `false` | **HTTP 500** |
> | `X` | 200 |
> | `1` | 200 |
> | *(empty)* | 200 |
>
> Sending the JSON spelling of a boolean into a one-character ABAP field is what made
> every pricing call fail with a server error.

**The material filter is enforced again on the response.** It is sent to SAP as the
`material` parameter, and `SapBackedPricingService` then drops any row outside the
requested set before returning. Whether this middleware honours that parameter is not
verifiable from here, and a service that ignores an unknown query parameter answers
with everything — so the guarantee is made where it can be, rather than assumed
upstream. A discrepancy is logged as
`The ERP is not honouring the 'material' parameter`.

**One SAP call per requested material.** `GetPriceByPaging` takes a single material,
not a list, so a request naming three materials makes three calls. Omitting `materials`
makes one unfiltered call for everything priced for that depot.

**A004** is the condition table holding sales-org / channel / material prices — a plain
material price. Without it a depot with no depot-specific conditions prices as
empty.

## The response — verified

Captured 2026-09-10 from `Live110`, one row exactly as it arrived:

```json
{
  "ConditionRecord": "0011854751",
  "ValidFrom": "01-09-2026",
  "ValidTo": "31-12-9999",
  "ConditionType": "ZP01",
  "SalesOrg": "0001",
  "PriceGroup": "11",
  "MaterialPriceGroup": "E1",
  "Material": "2400000466",
  "MaterialDescription": "C Purlin 125x50x1.60 (SGCC-Z60)",
  "ReleaseStatus": "",
  "PricingUnit": 1,
  "ConditionUnit": "M",
  "UnitPrice": 100.000,
  "Currency": "USD",
  "SourceTable": "A909"
}
```

wrapped in the same envelope every paged endpoint on this middleware uses:

```json
{ "Page": 1, "PageSize": 200, "TotalCount": 3869, "TotalPages": 20, "Rows": [ … ] }
```

`SapPriceDto` declares all sixteen names. The alias lists are kept as a fallback — the
cost is one null check per field, and a second connection answering differently is the
failure they exist for — but the declared names are the ones that bind today.

### What the capture corrected

Four defects, all of which produced a plausible-looking wrong answer rather than an
error:

| Guess | Reality | Symptom before |
|---|---|---|
| Rate is `Amount` | Rate is **`UnitPrice`** | Every price resolved `null`; every row counted as unmapped |
| Dates are `yyyyMMdd` | Pricing sends **`dd-MM-yyyy`** | `01-09-2026` read as **9 January** — a price that looked eight months stale |
| `99991231` is the open-ended sentinel | It is **`31-12-9999`** | Month 31 does not parse, so an open-ended condition read as `null` — an unexpiring price looked expired |
| Selling price is `PR00` | It is **`ZP01`** | Zero rows, indistinguishable from a depot with no prices |

The date formats are pinned explicitly and day-first, ahead of the invariant parser,
in `SapPriceDto.ParseSapDate`. A wrong date is worse than an unparsed one, so the
ambiguous formats are never left to a culture-dependent guess.

### Units are part of the price

`UnitPrice` alone is not a price. The full statement is
**`UnitPrice` `Currency` per `PricingUnit` `ConditionUnit`**.

Across the full 3,869-row read, `ConditionUnit` takes eight values — `BAG`, `KG`,
`M`, `PAC`, `PC`, `ROL`, `SET`, `UNI` — so the same figure means "per metre" on a
purlin and "per kilogram" on a coil. Both are carried through to the client as `conditionUnit`
and `pricingUnit` for that reason.

`PricingUnit` is `1` on every row sampled. It is still carried: SAP prices "per 100 KG"
as a matter of routine, and a client that assumed 1 would be wrong by a factor of a
hundred with nothing on screen to suggest it.

### Two prices for one material

One material in 3,868 — `2400000466` — returns **two** condition records for the same
sales org and price group:

| ConditionRecord | MaterialPriceGroup | ReleaseStatus | Price | ValidFrom |
|---|---|---|---|---|
| `0011854751` | `E1` | *(blank)* | 100.000 **USD** | 01-09-2026 |
| `0009518524` | `G5` | `A` | 2.765 **US3** | 15-01-2025 |

Both are returned, unchanged. **This backend does not pick one**, because choosing
between two prices SAP considers valid is a commercial decision, not a mapping one, and
the wrong choice is a wrong number quoted at a counter.

Two facts for whoever resolves it: the rows differ on `MaterialPriceGroup`, which the
filter can send but does not; and the second carries `ReleaseStatus` `A`, where every
other row sampled carries blank. In SAP, a blank release status means released.

> [!NOTE]
> `US3` is the currency on 3,867 of the 3,869 rows; `USD` appears on 2. `US3` is passed
> through exactly as SAP sends it, and is not a typo to be corrected here.

## Types and parsing

Almost everything is a string on the wire and **blank rather than null** — the same
behaviour `SapMaterialDto` documents. Consequences:

- A blank amount is **absent, not zero**. Zero and "no price" look identical on a
  screen and mean opposite things at a counter, so such a row is dropped.
- **Dates arrive as `dd-MM-yyyy`** (e.g. `01-09-2026` = 1 September 2026) on this
  endpoint, unlike the `yyyyMMdd` the material feeds use. Both are parsed, day-first
  and by explicit format, never by the invariant parser's month-first default.
- `31-12-9999` — SAP's open-ended condition — is passed through as a real date rather
  than nulled. A client showing "valid to 31 Dec 9999" is odd; telling it `null` when
  the record does have an end date is wrong.
- The middleware sometimes sends a bare number where its own schema says string. Both
  the declared path (`LenientStringJsonConverter`) and the extension-data path handle
  that.

## Failure behaviour

Mirrors `SapMaterialService` exactly — same failover between primary and secondary base
URL, same shared token, one re-authentication on a 401, same 404 classification.

| Situation | Result |
|---|---|
| No condition records for the depot | Empty list. A normal state of the ERP, not a fault |
| 404 naming the connection | `Sap.ConnectionNotRegistered` — a configuration fault |
| Host unreachable | Fails over to the secondary, then `Sap.ConnectionError` |
| SAP answers 5xx | `Sap.ApiError` → **500**, carrying the status code only |
| Depot has no sales area | `Pricing.DepotNotPriceable` → 422, **not** a SAP error |
| Route missing on the middleware | `Sap.ApiError` → 500. Was the state until 2026-09-10; the controller is now deployed |

A request that reached SAP and was refused is not retried against the secondary — both
front the same ERP, so retrying only doubles the latency of a failure.

## History: why pricing returned 500 until 2026-09-10

Kept because the diagnosis is reusable, not because the fault is live.

`docs/blueprint/sap-openapi.json` described **53** paths; the middleware deployed on
2026-09-04 served **45**. The eight missing ones were exactly the Quotation and Pricing
groups, `GetPriceByPaging` among them. The spec was ahead of the deployment, and the
live tag list ended at `08. Diagnostic` with no `Pricing` group at all. Re-checked on
2026-09-10 the tag list carries 13 groups including `Pricing`.

**A bodyless 404 with no content type is an unmatched ASP.NET Core route**, not the
middleware's "no rows" answer — that one carries `{"message": "..."}`. The client still
tells the two apart and reports the route case as an error rather than as an empty
price list: "this depot has no prices" and "the pricing API does not exist" must
never look the same on a counter screen.

After the deployment, two faults of our own remained, and both are worth remembering
because neither looked like a fault:

1. `includeA004=true` → HTTP 500 from SAP on every call. See the request table.
2. `conditionType=PR00` → 200 with zero rows, which reads as "this depot has
   nothing to sell".

### The status code

`Sap.ApiError` surfaces as **500**, not 502, because it is built with `Error.Failure`.
That is the platform-wide convention every SAP client follows, not something specific
to pricing. Arguably a downstream outage should be `Error.ExternalService` (→ 502);
changing it is a decision for all three SAP clients at once, not for pricing alone.

### Reading a failing call

The log line `SAP request for price page 1: GET ...` prints the exact URL and every
filter. For anything finer, `GET /api/v1/pricing/diagnostics/raw?path=…` returns SAP's
status, content type and body untouched — see [testing.md](testing.md).

---

## Configuration

```bash
SAP__PricingPageSize=200
SAP__PricingApplication=V
SAP__PricingConditionType=ZP01
SAP__PricingIncludeA004=true
```

These are the defaults; none needs setting for the integration to work. `ZP01` is this
business's selling condition type — see the warning against `PR00` above.
`PricingIncludeA004` is a `bool` here and is translated to SAP's `X` on the wire.

There is **no pricing mock**. `SAP:UsePricingMock` and `MockSapPricingService` were
deleted on 2026-09-10 now that the real endpoint answers; a fabricated price is a
figure the business would be asked to honour at a counter, and there is no longer any
reason to be able to produce one.

`PricingApplication` and `PricingConditionType` are configuration rather than constants
because which condition type carries this business's selling price is an SD customising
decision that should not need a deployment to correct.
