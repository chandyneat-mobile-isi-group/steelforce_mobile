# UC-08 — Fetch SAP Reference Catalogues

| | |
|---|---|
| **API** | `GET /api/v1/mobile/depots/references` |
| **Mobile use case** | `FetchMasterData` / `RefreshMasterData` |
| **Consumes into** | `DepotReferenceCatalogue` → `SapOption` lists |
| **Screen** | Registration form dropdowns |
| **User story** | [US-04](../user-stories/register-new-depot.md) |

---

## Use case

**Description.** Supply the SAP code lists the registration form's dropdowns are
built from (sales org, payment terms, price group, …).

**Actor.** System, on behalf of the Sales Representative.

**Trigger.** Opening the registration form; manual refresh.

### Main flow

1. `FetchMasterData` reads the local cache (`MasterDataCache`) first.
2. If stale or absent, `GET /references`.
3. Catalogues are cached and the dropdowns populate.

### Error flows

| Condition | Result |
|---|---|
| Offline with cache | Cached codes used; `synchronisedAt` shown so staleness is visible |
| Offline without cache | Dropdowns empty; the form cannot be completed |
| 4xx / 5xx | Cache retained |

### Business rules

**BR-13 is the important one.** `includeInactive` must default to `false`.

---

## API request

```http
GET /api/v1/mobile/depots/references?kinds=SalesOrg,PaymentTerm HTTP/1.1
Authorization: Bearer <access_token>
```

| Parameter | Type | Required | Description | Default |
|---|---|---|---|---|
| `kinds` | string (CSV) | No | Comma-joined catalogue names. Omitted → all | all |
| `search` | string | No | Filters within a catalogue. **Sales employees are deliberately absent unless queried with `search`** | — |
| `includeInactive` | `"true"` | No | **Sent only when true.** Omitted leaves the server on its own default rather than the client asserting one | `false` |

> **Leave `includeInactive` false for the registration form.** A retired code
> renders in the dropdown exactly like a live one, and a rep who picks it gets
> the registration rejected at the SAP push **with no way to see why**. It exists
> for *reading existing records*, whose stored codes may since have been retired.

---

## API response

```json
{
  "success": true,
  "data": {
    "catalogues": {
      "SalesOrg":            [ { "code": "1000", "name": "ISI Cambodia" } ],
      "DistributionChannel": [ { "code": "10",   "name": "Direct Sales" } ],
      "Division":            [ { "code": "10",   "name": "Steel" } ],
      "DepotGroup":          [ { "code": "Z1",   "name": "Retailer" } ],
      "PriceGroup":          [ { "code": "P2",   "name": "Standard" } ],
      "PaymentTerm":         [ { "code": "NT30", "name": "Net 30 days" } ],
      "ShippingCondition":   [ { "code": "01",   "name": "Standard" } ],
      "SalesOffice":         [ { "code": "PP01", "name": "Phnom Penh" } ],
      "SalesGroup":          [ { "code": "G01",  "name": "Central" } ]
    },
    "synchronisedAt": "2026-09-24T22:00:00Z"
  }
}
```

### Response mapping

| Backend | Type | Required | Mobile | Mapping |
|---|---|---|---|---|
| `data` (whole object) | object | Yes | `DepotReferenceCatalogue.values` | **Kept as a raw map** — the ERP owns these catalogues and a new one must not need an app release |
| `data.catalogues` | object | Yes | `catalogues` → `Map<String, List<SapOption>>` | Non-map → `{}` |
| `catalogues.<name>[]` | array | Yes | `List<SapOption>` | Non-list → skipped |
| `…[].code` | string | **Yes** | `SapOption.code` | **A row with no `code` is dropped silently** |
| `…[].name` | string | No | `SapOption.name` | Falls back to `code` |
| `data.synchronisedAt` | ISO-8601 | No | `synchronisedAt` (`DateTime?`) | `DateTime.tryParse(...).toUtc()`; unparseable → null |

An empty catalogue is **omitted** from the result map, and `optionsFor(name)`
returns `[]` rather than null so a dropdown needs no null check.

### Catalogue names

`SalesOrg`, `DistributionChannel`, `Division`, `DepotGroup`, `PriceGroup`,
`PaymentTerm`, `ShippingCondition`, `SalesOffice`, `SalesGroup`.

**`TODO / Backend Confirmation Required`** — confirm this set is stable and
exhaustive. Note `DepotGroup` here maps to the SAP field `CustomerGroup` in
[UC-09](create-business-partner.md).

---

## Mobile compatibility notes

1. `code` is mandatory per row — rows without it vanish with no error.
2. `synchronisedAt` should be sent so the UI can warn when codes are stale.
3. Adding a catalogue is **safe** — the client renders whatever arrives.
