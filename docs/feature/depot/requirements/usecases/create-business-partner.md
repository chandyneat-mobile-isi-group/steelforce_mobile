# UC-09 — Create SAP Business Partner

| | |
|---|---|
| **API** | `POST /api/v1/mobile/depots/business-partner` |
| **Mobile use case** | `CreateBusinessPartner` |
| **Request model** | `BusinessPartnerRequestModel` (**47 fields**) |
| **Consumes into** | `BusinessPartnerResult` / `CreateBpResponse` |
| **Screen** | `DepotCreateScreen` review step |
| **User story** | [US-04](../user-stories/register-new-depot.md) |

---

## Use case

**Description.** Push a completed registration into SAP as a Business Partner.
This is the **compatibility route** — new UI should use the draft lifecycle
([UC-07](registration-draft-lifecycle.md)) so a killed handset can resume.

**Actor.** Sales Representative.

**Preconditions.** Authenticated; the form is complete; the depot code was
checked and is absent ([UC-04](lookup-depot-by-code.md)).

### Main flow

1. The rep reviews and submits.
2. `BusinessPartnerRequestModel.toJson()` → 47 keys.
3. `POST …/business-partner` with a **60-second** timeout.
4. SAP returns a status and, when approved, a customer number.
5. Attachments upload separately (A-15).

### Error flows

| Condition | Result |
|---|---|
| Timeout | **The worst available outcome** — SAP may still complete it, and retrying creates a duplicate. Hence the 60s budget (BR-16) |
| `400` | The SAP return table is in the body; the client parses it rather than throwing |
| 4xx | `ValidationFailure` — not retried |
| 5xx | Retryable |
| Offline | Queued as a `PendingSubmission` and retried |

### Business rules

**BR-16.** SAP BP creation runs **synchronously** through the middleware and
regularly takes longer than a list fetch. The default client timeout is tuned
for reads; inheriting it makes the rep see a timeout for a registration SAP went
on to complete — and the obvious response is to try again and create a duplicate.

---

## API request

```http
POST /api/v1/mobile/depots/business-partner HTTP/1.1
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "Name1": "Sokha Steel Shop",
  "Name2": "", "Name3": "", "CoName": "",
  "SearchTerm1": "SOKHA", "SearchTerm2": "",
  "Street": "St. 271", "HouseNo": "42",
  "City": "Phnom Penh", "District": "Chamkar Mon",
  "PostalCode": "12000", "Region": "PP", "Country": "KH",
  "Language": "EN",
  "Telephone": "023123456", "MobilePhone": "012345678",
  "Latitude": "11.5449", "Longitude": "104.8922",
  "AccountGroup": "Z001", "BpRole": "FLCU01",
  "PartnerCategory": "1", "PartnerFunction": "SP",
  "PartnerCounter": "001", "PartnerGroup": "",
  "SalesOrg": "1000", "DistributionChannel": "10", "Division": "10",
  "SalesOffice": "PP01", "SalesGroup": "G01",
  "CustomerGroup": "Z1", "PriceGroup": "P2", "PricingProc": "1",
  "Currency": "USD", "PaymentTerms": "NT30",
  "CreditControlArea": "1000", "CreditLimit": "15000",
  "ShippingCondition": "01", "DeliveryPriority": "02",
  "TaxClass": "1", "TaxCountry": "KH", "TaxType": "MWST",
  "CustomerNumber": "", "PersonnelNumber": "",
  "OrderBlock": "", "SALESBLOCK": "", "BLOCKFLAG": "",
  "Commit": "X",
  "submitToSap": true
}
```

### Field contract

**The payload is 47 keys.** Names are **SAP field names, PascalCase**, unlike
every other endpoint in this feature — that is deliberate: this maps onto SAP's
BAPI, not the platform's own model.

| Group | Fields |
|---|---|
| Identity | `Name1`*, `Name2`, `Name3`, `CoName`, `SearchTerm1`, `SearchTerm2` |
| Address | `Street`, `HouseNo`, `City`, `District`, `PostalCode`, `Region`, `Country`, `Language` |
| Contact | `Telephone`, `MobilePhone` |
| Geo | `Latitude`, `Longitude` |
| BP classification | `AccountGroup`, `BpRole`, `PartnerCategory`, `PartnerFunction`, `PartnerCounter`, `PartnerGroup` |
| Sales area | `SalesOrg`, `DistributionChannel`, `Division`, `SalesOffice`, `SalesGroup` |
| Commercial | `CustomerGroup`, `PriceGroup`, `PricingProc`, `Currency`, `PaymentTerms`, `CreditControlArea`, `CreditLimit` |
| Logistics | `ShippingCondition`, `DeliveryPriority` |
| Tax | `TaxClass`, `TaxCountry`, `TaxType` |
| Keys | `CustomerNumber`, `PersonnelNumber` |
| Blocks | `OrderBlock`, `SALESBLOCK`, `BLOCKFLAG` |
| Control | `Commit`, `submitToSap` |

> `SALESBLOCK` and `BLOCKFLAG` are **UPPER CASE** while their neighbours are
> PascalCase. Preserved verbatim from the SAP contract.

**Only `Name1` is required** — see [`../../api.md`](../../api.md) §"Only `name1` is required".

| Field | Type | Required | Notes |
|---|---|---|---|
| `Name1` | string | **Yes** | The BP name |
| `submitToSap` | boolean | Yes | `false` stages without pushing to SAP |
| `Commit` | string | Yes | `"X"` = commit |
| *(all others)* | string | No | Empty string when unknown |

### ⚠ Unknown keys are dropped silently

The server drops keys it does not recognise **without complaining**, so a
payload that has lost fields is accepted and **reaches SAP incomplete**. The
client warns when the count drifts from 47, but does not block — the count is a
smoke alarm for a bad merge, not a reason to stop a rep standing in a shop.

**`TODO / Backend Confirmation Required`** — should the server reject unknown or
missing keys instead of silently dropping them? See
[`../README.md`](../README.md#13-open-questions--todo--backend-confirmation-required) Q-09.

---

## API response

```json
{
  "success": true,
  "data": {
    "customerId": "8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70",
    "customerCode": "0001002345",
    "sapStatus": "CREATED",
    "return": [
      { "type": "S", "id": "BAPI", "number": "000", "message": "Customer 0001002345 created" }
    ]
  }
}
```

### Response mapping — `CreateBpResponse`

| Backend field | Type | Required | Mobile field | Mapping |
|---|---|---|---|---|
| `customerCode` **or** `customer_code` | string \| null | No | **`depotCode`** | **Renamed.** `null` while HQ approval is pending — SAP has not assigned a number yet |
| `sapStatus` **or** `status` | string | No | `status` | Defaults `"PENDING_HQ"`. Values: `PENDING_HQ` \| `CREATED` \| `REJECTED` |
| `customerId` **or** `local_id` | string | No | `localId` | `''` fallback |

> **⚠ The client accepts both camelCase and snake_case for all three fields.**
> Two naming conventions on one payload. See
> [`../README.md`](../README.md#13-open-questions--todo--backend-confirmation-required) Q-03 —
> backend must confirm which is authoritative.

### SAP return table → `SapReturnMessage`

Returned on `400` as well as `200` — **that table is the only place the reason
is written**, so the client reads the body on non-2xx rather than throwing.

| Backend | Mobile (`SapMessageType`) | Failure? |
|---|---|---|
| `"S"` | `success` | No |
| `"I"` | `info` | No |
| `"W"` | `warning` | No |
| `"E"` | `error` | **Yes** |
| `"A"` | `abort` | **Yes** |
| `"X"` | `exit` | **Yes** |
| anything else | `unknown` | No |

| Backend field | Type | Mobile field |
|---|---|---|
| `type` | string (1 char) | `type` |
| `message` | string | `message` |
| `id` | string | `id` (`''` default) |
| `number` | string | `number` (`''` default) |

---

## A-15 · `POST /api/v1/depots/bp/{localId}/attachments`

Multipart upload of a registration attachment.

```
local_id: <localId>      (snake_case)
kind:     <slot name>
file:     <binary>
```

Returns `{ "url": "https://…" }` — read as **`res.data['url']`**.

### ⚠ Two problems with this endpoint

1. **The route is missing `mobile/`.** Every other depot route is
   `/api/v1/mobile/depots/…`; this one is `/api/v1/depots/bp/…`.
2. **It bypasses the response envelope.** Every other endpoint returns
   `{success, data, …}`; this reads `url` off the root.

Both are likely bugs. See [`../README.md`](../README.md#13-open-questions--todo--backend-confirmation-required) Q-01, Q-02.

---

## Mobile compatibility notes

1. **Allow ≥ 60 seconds.** A gateway timeout shorter than SAP's own runtime
   produces duplicate business partners.
2. **Return the SAP table on 400.** Without it the rep sees a generic failure
   and no reason.
3. **Pin one casing** for `customerCode`/`sapStatus`/`customerId`.
4. `CreditLimit` and the coordinates are **strings** here, unlike
   [UC-03](create-depot.md) where they are numbers. Preserved from the SAP contract.
