# Depot Mobile Registration — API

Base: `/api/v1/mobile/depots`. Bearer token required.

`references` needs `depots.read`; the draft endpoints need `depots.create`.

---

## 1 · `GET references` — the dropdowns

**Call once when the form opens.** Returns the nine small catalogues, ~4.5 KB, ~98 ms,
served from the database.

| Parameter | Notes |
|---|---|
| `kinds` | Repeatable. Omit for the nine small ones. |
| `search` | Narrows every requested catalogue by code or name, case-insensitively. |

```jsonc
{
  "data": {
    "catalogues": {
      "SalesOrg":            [{ "code": "0001", "name": "Phnom Penh (ISI)" }],
      "DistributionChannel": [{ "code": "10",   "name": "End-User" }],
      "Division":            [{ "code": "10",   "name": "ISI Steel" }],
      "SalesGroup":          [{ "code": "010",  "name": "Channel Sales" }],
      "SalesOffice":         [{ "code": "0001", "name": "Phnom Penh" }],
      "PriceGroup":          [{ "code": "11",   "name": "End-User" }],
      "ShippingCondition":   [{ "code": "01",   "name": "ISI Services" }],
      "PaymentTerm":         [{ "code": "BL30", "name": "LC after BL date 30days" }],
      "DepotGroup":       [{ "code": "01",   "name": "End-User" }]
    },
    "synchronisedAt": "2026-08-26T08:30:02Z"
  }
}
```

**Sales employees are not in that set** — 5,809 rows would make this 252 KB. Fetch them
as a search:

```
GET references?kinds=SalesEmployee&search=leng
→ 48 matches, 2.3 KB, 39 ms
```

A requested catalogue always appears, empty if SAP has never supplied it, so a client
can always bind. Submit `code` back verbatim — it is a key, not a label.

---

## 2 · `POST draft` — open the form

No body. Creates server-side state and returns the whole payload prefilled.

```jsonc
{
  "data": {
    "draftId": "01a03d33-a4c7-77c0-8727-df5a36ff50b6",
    "status": "Draft",
    "isEditable": true,
    "submittedDepotId": null,
    "fields": {
      "partnerCategory": "2", "bpRole": "ZFLCU1", "accountGroup": "Z001",
      "country": "KH", "language": "E", "currency": "USD",
      "taxCountry": "KH", "salesOrg": "1000",
      "name1": null, "street": null, "city": null, "mobilePhone": null
      // …46 fields in total
    }
  }
}
```

Eight prefilled from `SAP:DepotDefaults` configuration. Every one is a **default,
not a constraint** — the rep can change any of them.

---

## 3 · `POST update` — save as they type

**A patch.** Omit a field → unchanged. Send `""` → cleared. Send a value → set.

```jsonc
{ "draftId": "01a0…", "fields": { "name1": "Sok Dara Hardware" } }
```

Returns the whole draft, so the handset never merges state. Safe to call on every
field blur — three sequential patches took 105 ms, 14 ms, 8 ms.

Codes are normalised (`bl30` → `BL30`); names, addresses and the tax number keep their
case; Khmer is preserved.

A submitted or discarded draft answers **409 `Depot.DraftNotEditable`**.

---

## 4 · `POST submit` — become a depot

```jsonc
{ "draftId": "01a0…" }
```

```jsonc
{
  "data": {
    "depotId": "01a03d34-35b9-7993-9598-5c7110aee91d",
    "depotCode": "BP-202608-00003",
    "name": "Sok Dara Hardware",
    "sapStatus": "Submitted",
    "submittedAt": "2026-08-26T08:33:46Z"
  }
}
```

The depot appears in `GET /api/v1/mobile/depots` immediately with
`sapStatus: "Submitted"`.

**This never calls SAP.** A rep at a counter has no route to the ERP and often no
signal; the registration still has to succeed. Delivery happens on the next
`POST /api/v1/depots/sap/push-pending`.

### Required fields

Four, checked together so the rep fixes the form in one pass:

```jsonc
// 400 General.Validation
"errors": {
  "Name1":       ["A depot name is required."],
  "MobilePhone": ["A telephone or mobile number is required."],
  "Street":      ["A street address is required."],
  "City":        ["A city is required."]
}
```

The **sales area and account group are deliberately not required**. SAP needs them to
register the depot and the push reports it when they are missing, but the platform
holds a shop perfectly well without them — a shop captured at a counter is a real shop
before anyone decides its price group.

Submitting twice answers **409 `Depot.DraftAlreadySubmitted`**.

---

## 5 · Housekeeping

| Route | Purpose |
|---|---|
| `GET drafts` | The rep's unfinished forms — "continue where you left off" |
| `GET draft/{draftId}` | One draft |
| `DELETE draft/{draftId}` | Abandon it |

A draft belonging to another rep answers **404, not 403** — telling a caller it exists
confirms something that is not theirs to know.

---

## 6 · Admin

`POST /api/v1/depots/sap/sync-references` (`depots.sync`) refreshes all ten
catalogues on demand. The same command runs **daily at 03:00 UTC**.

```jsonc
{ "success": true, "inserted": 5918, "updated": 0,
  "catalogues": 10, "failedCatalogues": [],
  "synchronisedAt": "2026-08-26T08:30:02Z", "durationMs": 3186 }
```

---

## Error codes

| Code | HTTP | Meaning |
|---|---|---|
| `General.Validation` | 400 | Missing required fields; see `errors` |
| `Depot.DraftNotFound` | 404 | No such draft, or not yours |
| `Depot.DraftNotEditable` | 409 | Submitted or discarded |
| `Depot.DraftAlreadySubmitted` | 409 | Submitted twice |
| `Depot.DraftDiscarded` | 409 | Submitting an abandoned draft |
