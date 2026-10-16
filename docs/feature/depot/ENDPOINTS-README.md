# Depots — API Endpoints (request & response)

A quick reference: every depot endpoint the mobile app calls, with its request and
response only. For the rules behind each field, follow the link under each section.

- **Base URL:** `{API_BASE_URL}/api/v1`
- **Headers on every call:** `Authorization: Bearer <access_token>` ·
  `Accept: application/json` · `Accept-Language: en-US | km-KH`
- **Sources:** the app code in `lib/features/depots/data/` and
  `lib/core/network/api/api_endpoints.dart`, plus the contract docs linked below.
  Examples use the docs' sample data.

## Endpoint list

| # | Method | Path | Used for |
|---|---|---|---|
| 1 | GET | `/mobile/depots` | First sync (paged list) |
| 2 | GET | `/mobile/depots?modifiedSince=…` | Delta sync |
| 3 | GET | `/mobile/depots/{id}` | Depot detail |
| 4 | GET | `/depots/by-code/{code}` | Look up a depot code (portal surface) |
| 5 | POST | `/mobile/depots` | Simple create |
| 6 | POST | `/mobile/depots/business-partner` | Register a business partner for SAP |
| 7 | GET | `/mobile/depots/references` | Registration dropdowns |
| 8 | POST | `/mobile/depots/draft` | Start a registration draft |
| 9 | POST | `/mobile/depots/update` | Patch draft fields |
| 10 | POST | `/mobile/depots/submit` | Submit a draft |
| 11 | GET | `/mobile/depots/draft/active` | Resume the open draft |
| 12 | GET | `/mobile/depots/drafts` | List my drafts |
| 13 | GET | `/mobile/depots/draft/{draftId}` | One draft |
| 14 | DELETE | `/mobile/depots/draft/{draftId}` | Discard a draft |
| 15 | POST | `/mobile/depots/{depotId}/documents` | Upload a document |
| 16 | GET | `/mobile/depots/{depotId}/documents` | Document checklist |
| 17 | DELETE | `/mobile/depots/{depotId}/documents/{documentId}` | Delete a document |
| 18 | GET | `/mobile/depots/{depotId}/stop-information` | Visit stop screen |
| 19 | GET | `/mobile/depots/{depotId}/agreements` | Standing discount agreements |
| 20 | GET | `/mobile/depots/{depotId}/incentives` | Promotions feed |
| 21 | GET | `/mobile/depots/{depotId}/promotions` | Promotions list |
| 22 | GET | `/mobile/pricing/depots/{depotId}` | Depot prices |

---

## 1 · List depots (first sync)

`GET /mobile/depots` · [get-depot.md](mobile/get-depot.md) · [filter-depot.md](mobile/filter-depot.md)

**Request**

```
GET /api/v1/mobile/depots?pageNumber=1&pageSize=200&sort=updatedAt
```

| Query | Type | Notes |
|---|---|---|
| `pageNumber` | int | Starts at 1 |
| `pageSize` | int | Default 25, capped at 200 |
| `sort` | string | e.g. `updatedAt`, `-updatedAt,name` |
| `search` | string | Name, code, city, SAP number, phone |
| `status` | enum | `Draft` `PendingApproval` `Active` `Suspended` `Closed` |
| `type` | enum | `Retailer` `Wholesaler` `Distributor` `KeyAccount` |
| `territory` / `province` / `district` | string | Exact match |
| `linkedToSapOnly` | bool | Only depots with a SAP number |

**Response 200**

```json
{
  "success": true,
  "message": "Depots retrieved successfully.",
  "data": {
    "customers": [
      {
        "id": "019ff532-…",
        "depotCode": "ISI-PP0005",
        "sapDepotId": "1000105",
        "shopName": "ឃ្លាំងសំណង់ ទួលគោក",
        "ownerName": "Heng Vuthy",
        "phone": "023456005",
        "city": "Phnom Penh",
        "district": "Toul Kork",
        "territory": "PP-NORTH",
        "latitude": 11.5788,
        "longitude": 104.8901,
        "type": "Distributor",
        "status": "Active",
        "statusDisplay": "សកម្ម",
        "canTrade": true,
        "creditLimit":   { "amount": 30000.0, "currency": "USD" },
        "creditBalance": { "amount": 4200.0,  "currency": "USD" },
        "lastVisitDate": "2026-08-09T03:12:00Z",
        "lastOrderDate": "2026-08-11T07:45:00Z",
        "assignedRepId": "019fefd2-…",
        "updatedAt": "2026-08-12T02:31:19Z",
        "deleted": false
      }
    ]
  },
  "metadata": {
    "page": 1,
    "pageSize": 200,
    "totalRecords": 10,
    "totalPages": 1,
    "hasNextPage": false,
    "hasPreviousPage": false,
    "syncTimestamp": "2026-08-12T09:44:12Z",
    "isDeltaSync": false
  },
  "traceId": "0HNNOE4PB87QG:00000001",
  "timestamp": "2026-08-12T09:44:12Z"
}
```

> The app reads the rows from `data.customers`. The docs show `data.depots`.
> See [Open questions](#open-questions).

---

## 2 · Delta sync

`GET /mobile/depots` with `modifiedSince` · [get-depot.md §Delta sync](mobile/get-depot.md#delta-sync)

**Request**

```
GET /api/v1/mobile/depots?modifiedSince=2026-08-28T08:31:52Z&pageNumber=1&pageSize=200&includeDeleted=true&sort=updatedAt
```

| Query | Notes |
|---|---|
| `modifiedSince` | The previous response's `metadata.syncTimestamp`. Never the device clock |
| `includeDeleted` | `true`, so deleted depots come back as tombstones |

**Response 200:** the same shape as #1, with `metadata.isDeltaSync: true`.
Deleted depots come back with `"deleted": true`.

---

## 3 · Depot detail

`GET /mobile/depots/{id}` · [get-depot-by-id.md](mobile/get-depot-by-id.md)

**Request**

```
GET /api/v1/mobile/depots/01a03189-9670-7599-98ac-45ebaf277899
```

`{id}` is the platform GUID, not the depot code.

**Response 200**

```json
{
  "success": true,
  "message": "Depot retrieved successfully.",
  "data": {
    "customer": {
      "id": "01a03189-…",
      "depotCode": "6100000017",
      "sapDepotId": "6100000017",
      "shopName": "ដេប៉ូ​​​ រស្មី សៀមរាប",
      "enName": "PNP-DEPOT REAKSMEY SIEM REAP",
      "khName": "ដេប៉ូ​​​ រស្មី សៀមរាប",
      "ownerName": null,
      "description": null,
      "phone": "012345678",
      "email": null,
      "whatsapp": null,
      "address": "Street 271, Siem Reap",
      "addressLine1": "Street 271",
      "addressLine2": null,
      "city": "Siem Reap",
      "district": null,
      "province": null,
      "postalCode": null,
      "territory": null,
      "latitude": null,
      "longitude": null,
      "type": "Retailer",
      "status": "Active",
      "statusDisplay": "សកម្ម",
      "canTrade": true,
      "creditLimit":     { "amount": 0.0, "currency": "USD" },
      "creditBalance":   { "amount": 0.0, "currency": "USD" },
      "availableCredit": { "amount": 0.0, "currency": "USD" },
      "creditTermDays": 0,
      "currency": "USD",
      "assignedRepId": null,
      "assignedRepName": null,
      "originLeadId": null,
      "productsPurchased": [],
      "contacts": [
        { "id": "019ff532-…", "name": "Heng Vuthy", "phone": "012345605",
          "position": "Owner", "email": null, "isPrimary": true }
      ],
      "lastOrderDate": null,
      "lastVisitDate": null,
      "lifetimeValue": { "amount": 0.0, "currency": "USD" },
      "totalOrders": 0,
      "openOpportunityCount": 0,
      "metricsCalculatedAt": "2026-08-28T03:00:11Z",
      "salesOrg": "0001",
      "division": "10",
      "distributionChannel": "10",
      "depotGroup": "01",
      "priceGroup": "11",
      "paymentTerms": "T030",
      "taxNumber": null,
      "createdAt": "2026-08-24T02:11:35Z",
      "updatedAt": "2026-08-28T03:00:11Z",
      "deleted": false,
      "deletedAt": null
    },
    "createdBy": null,
    "updatedBy": null
  },
  "metadata": null,
  "traceId": "0HNO1GJO3S25L:00000001",
  "timestamp": "2026-08-28T08:31:52Z"
}
```

> The app reads `data.customer`. The docs show `data.depot`.
> See [Open questions](#open-questions).

**Other statuses:** `404 Depot.NotFound` means the depot doesn't exist or is outside the
caller's scope.

---

## 4 · Look up a depot by code

`GET /depots/by-code/{code}` · [api.md §Looking a depot up by code](api.md#looking-a-depot-up-by-code)

This is the portal surface, not `/mobile`. It uses a different envelope and depot shape.

**Request**

```
GET /api/v1/depots/by-code/6100001234
```

**Response 200**

```json
{
  "data": {
    "id": "01a03189-9670-7599-98ac-45ebaf277899",
    "code": "BP-202608-00002",
    "name": "Doc Sample Hardware",
    "type": "Retailer",
    "status": "Draft",
    "canTrade": false,
    "phone": "012345678",
    "address": {
      "line1": "Street 271", "line2": null, "city": "Phnom Penh",
      "province": null, "postalCode": null,
      "latitude": 11.5449, "longitude": 104.916
    },
    "creditLimit": 0.0,
    "creditTermDays": 0,
    "assignedSalesRepId": "019fefcb-…",
    "createdAt": "2026-08-24T02:11:35.707489+00:00"
  },
  "meta": { "correlationId": "0HNO1GJO3S25L:00000001", "timestamp": "…" }
}
```

| Status | Meaning |
|---|---|
| 200 | Found, either locally or fetched from SAP |
| 404 `Depot.NotFoundByCode` | Neither the platform nor SAP has it. Safe to offer registration |
| 502 | SAP couldn't be reached. **Don't** offer registration, because it could create a duplicate |

---

## 5 · Create depot (simple)

`POST /mobile/depots` · [create-depot.md §Path A](mobile/create-depot.md#path-a--simple-create)

**Request**

```json
{
  "depotCode": "ISI-PP0099",
  "shopName": "Sok Heng Hardware",
  "type": "Retailer",
  "phone": "012 345 678",
  "addressLine1": "Street 271, Sangkat Toul Tumpung",
  "city": "Phnom Penh",
  "district": "Chamkarmon",
  "province": "Phnom Penh",
  "ownerName": "Sok Heng",
  "whatsapp": "+85512345678",
  "territory": "PP-CENTRAL",
  "latitude": 11.5449,
  "longitude": 104.9160,
  "creditLimit": 5000,
  "creditTermDays": 30,
  "enName": "Sok Heng Hardware",
  "khName": "ហាង សុខ ហេង",
  "contacts": [
    { "name": "Sok Heng", "phone": "012345678", "position": "Owner", "isPrimary": true }
  ]
}
```

- Send `latitude` and `longitude` together, or leave both out. Never send `0, 0`.
- Leave out `contacts` when there are none. Don't send `[]`.

**Response 201** (with a `Location` header): the created depot, in the same shape as
`data.customer` in #3, with `"status": "Draft"`.

---

## 6 · Register a business partner for SAP

`POST /mobile/depots/business-partner` · [create-depot.md §Path B](mobile/create-depot.md#path-b--business-partner-for-sap)

**Request**

```json
{
  "name1": "Doc Sample Hardware",
  "name3": "ហាងគំរូ",
  "partnerCategory": "2",
  "partnerGroup": "Z001",
  "bpRole": "ZFLCU1",
  "accountGroup": "Z001",
  "country": "KH",
  "region": "R01",
  "city": "Phnom Penh",
  "street": "Street 271",
  "houseNo": "12B",
  "mobilePhone": "012345678",
  "telephone": "023456789",
  "language": "E",
  "salesOrg": "0001",
  "distributionChannel": "10",
  "division": "10",
  "depotGroup": "01",
  "currency": "USD",
  "paymentTerms": "T015",
  "searchTerm1": "PHNOM PENH",
  "latitude": 11.5449,
  "longitude": 104.9160,
  "territory": "PP-CENTRAL",
  "submitToSap": true
}
```

Only `name1` is required. A blank one returns `400 Depot.NameRequired`.

**Response 200**

```json
{
  "success": true,
  "message": "Depot created successfully.",
  "data": {
    "depotId": "01a03189-9670-7599-98ac-45ebaf277899",
    "depotCode": "BP-202608-00002",
    "name": "Doc Sample Hardware",
    "sapStatus": "Submitted",
    "sapDepotNumber": null,
    "submittedAt": "2026-08-24T02:11:35.666005+00:00",
    "registeredAt": null,
    "lastError": null,
    "attemptCount": 0
  },
  "traceId": "0HNO1GJO3S25K:00000001"
}
```

`sapStatus` is one of `NotSubmitted`, `Submitted`, `Registered` or `Rejected`.

---

## 7 · Registration dropdowns

`GET /mobile/depots/references` · [registration/api.md §1](registration/api.md#1--get-references--the-dropdowns)

**Request**

```
GET /api/v1/mobile/depots/references
GET /api/v1/mobile/depots/references?kinds=SalesEmployee&search=leng
```

| Query | Notes |
|---|---|
| `kinds` | Catalogue names. Leave it out to get the nine small catalogues. The app sends a comma-joined list |
| `search` | Filters by code or name, ignoring case |
| `includeInactive` | `true` to include inactive entries. The app sends it only when true |

**Response 200**

```json
{
  "success": true,
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
      "DepotGroup":          [{ "code": "01",   "name": "End-User" }]
    },
    "synchronisedAt": "2026-08-26T08:30:02Z"
  }
}
```

---

## 8 · Start a registration draft

`POST /mobile/depots/draft` · [registration/api.md §2](registration/api.md#2--post-draft--open-the-form)

**Request:** no body.

**Response 200**

```json
{
  "success": true,
  "data": {
    "draftId": "01a0477f-2d66-7a62-a564-bda8b1a85648",
    "status": "Draft",
    "isEditable": true,
    "submittedDepotId": null,
    "submittedAt": null,
    "createdAt": "2026-08-28T08:31:52Z",
    "updatedAt": null,
    "fields": {
      "partnerCategory": "2", "bpRole": "ZFLCU1", "accountGroup": "Z001",
      "country": "KH", "language": "E", "currency": "USD",
      "taxCountry": "KH", "salesOrg": "1000",
      "name1": null, "street": null, "city": null, "mobilePhone": null
    }
  }
}
```

`fields` holds 46 keys in total.

---

## 9 · Update draft fields

`POST /mobile/depots/update` · [registration/api.md §3](registration/api.md#3--post-update--save-as-they-type)

**Request**

```json
{ "draftId": "01a0477f-…", "fields": { "name1": "Sok Heng Hardware", "city": "Phnom Penh" } }
```

This is a patch:
- a field you leave out stays unchanged;
- `""` clears it;
- a value sets it.

**Response 200:** the whole draft, in the same shape as #8.
**409 `Depot.DraftNotEditable`:** the draft was already submitted or discarded.

---

## 10 · Submit a draft

`POST /mobile/depots/submit` · [registration/api.md §4](registration/api.md#4--post-submit--become-a-depot)

**Request**

```json
{ "draftId": "01a0477f-…" }
```

**Response 200**

```json
{
  "success": true,
  "data": {
    "depotId": "01a03d34-35b9-7993-9598-5c7110aee91d",
    "depotCode": "BP-202608-00003",
    "name": "Sok Dara Hardware",
    "sapStatus": "Submitted",
    "submittedAt": "2026-08-26T08:33:46Z"
  }
}
```

**Response 400 `General.Validation`**

```json
{
  "errors": {
    "Name1":       ["A depot name is required."],
    "MobilePhone": ["A telephone or mobile number is required."],
    "Street":      ["A street address is required."],
    "City":        ["A city is required."]
  }
}
```

**409:** `Depot.DraftAlreadySubmitted` or `Depot.DraftDiscarded`.

---

## 11 · Resume the open draft

`GET /mobile/depots/draft/active`

**Request:** no parameters.

**Response 200:** the draft, in the same shape as #8, or `"data": null` when there is none.
**404:** no open draft. The app treats this as "none", not as an error.

---

## 12 · List my drafts

`GET /mobile/depots/drafts`

**Request:** no parameters.

**Response 200**

```json
{
  "success": true,
  "data": {
    "drafts": [ { "draftId": "01a0477f-…", "status": "Draft", "isEditable": true, "fields": { } } ]
  }
}
```

The app also accepts `data.items`, or `data` as a bare list.

---

## 13 · Get one draft

`GET /mobile/depots/draft/{draftId}`

**Response 200:** the draft, in the same shape as #8.
**404 `Depot.DraftNotFound`:** no such draft, or it belongs to another rep.

---

## 14 · Discard a draft

`DELETE /mobile/depots/draft/{draftId}`

**Response:** `204`, with no body.

---

## 15 · Upload a document

`POST /mobile/depots/{depotId}/documents` · [depot-documents.md §Upload](mobile/depot-documents.md#upload)

`{depotId}` accepts the platform GUID **or** the depot code / SAP number.

**Request:** `multipart/form-data`, one file per request

| Part | Value |
|---|---|
| `file` | The image or PDF, with an explicit content type (`image/jpeg`, `image/png`, `application/pdf`) |
| `Type` | `STOREFRONT` · `INSIDE_STORE` · `ID_CARD` · `PATENT_TAX` · `VAT_CERTIFICATE` |
| `CapturedAt` | Optional. When the photo was taken, in ISO-8601 UTC |

Limits:
- maximum size 10 MB;
- PDF is accepted only for `PATENT_TAX` and `VAT_CERTIFICATE`.

**Response 200**

```json
{
  "success": true,
  "message": "Photo uploaded successfully.",
  "data": {
    "id": "01a0479c-d20c-7275-b8ac-8883b582e9e7",
    "type": "STOREFRONT",
    "typeDisplay": "Storefront photo",
    "fileName": "storefront.jpg",
    "contentType": "image/jpeg",
    "sizeBytes": 297431,
    "url": "/api/v1/mobile/depots/6100000017/documents/01a0479c-…/content",
    "publicUrl": "/files/depots/hAS_juvp1vHZ3V87WYfwnw",
    "isPubliclyVisible": true,
    "capturedAt": "2026-08-31T08:00:00Z",
    "uploadedAt": "2026-08-31T09:12:44Z"
  }
}
```

**400 codes:**
- `Depot.DocumentFileRequired`
- `Depot.DocumentTypeInvalid`
- `Depot.DocumentExtensionNotAllowed`
- `Depot.DocumentContentTypeMismatch`
- `Depot.DocumentTooLarge`

---

## 16 · Document checklist

`GET /mobile/depots/{depotId}/documents` · [depot-documents.md §The checklist](mobile/depot-documents.md#the-checklist)

**Response 200**

```json
{
  "success": true,
  "data": {
    "depotId": "01a0479c-…",
    "documents": [
      { "id": "…", "type": "STOREFRONT",   "fileName": "storefront.jpg", "url": "…", "publicUrl": "…" },
      { "id": "…", "type": "INSIDE_STORE", "fileName": "inside.jpg",     "url": "…", "publicUrl": "…" }
    ],
    "missingRequired": ["ID_CARD"],
    "isComplete": false
  }
}
```

Each item in `documents` has the same shape as `data` in #15.

---

## 17 · Delete a document

`DELETE /mobile/depots/{depotId}/documents/{documentId}`

**Response:** `204`, with no body. This also revokes the document's `publicUrl`.

---

## 18 · Stop information (visit screen)

`GET /mobile/depots/{depotId}/stop-information` · [backend-change-notice.md §2](mobile/backend-change-notice.md#2--the-endpoint-and-its-exact-keys)

**Request**

```
GET /api/v1/mobile/depots/01a03189-…/stop-information
```

**Response 200**

```json
{
  "success": true,
  "message": "…",
  "data": {
    "customer": {
      "id": "01a03189-…",
      "code": "6100000123",
      "name": "Sok Heng Hardware",
      "nameKh": "ហាង សុខ ហេង",
      "contact": "Sok Heng",
      "phone": "012345678",
      "address": "Street 271, Chamkarmon, Phnom Penh",
      "telegram": "phnom_penh_steel_outlet",
      "outletType": "Wholesaler"
    },
    "financial": {
      "creditLimit":      { "amount": 50000.00, "currency": "USD" },
      "creditLimitDate":  "2026-08-10T00:00:00+00:00",
      "creditBalance":    { "amount": 12500.00, "currency": "USD" },
      "availableCredit":  { "amount": 37500.00, "currency": "USD" },
      "currency":         "USD",
      "paymentTermCode":  "T030",
      "paymentTermLabel": "30 days due net",
      "paymentTermDays":  30
    }
  },
  "metadata": null,
  "traceId": "0HNO1GJO3S25K:00000001"
}
```

**404:** the outlet doesn't exist, or the caller can't see it.

---

## 19 · Depot agreements

`GET /mobile/depots/{depotId}/agreements` · [promotions-discounts-plan.md §8.1](../prom-discount/promotions-discounts-plan.md)

**Request:** no parameters.

**Response 200** (as documented)

```json
{
  "success": true,
  "data": [
    {
      "id": "AG-2026-0048",
      "category": "Roofing Profile",
      "percent": 3.0,
      "kind": "volumeTier",
      "status": "Active",
      "effectiveFrom": "2026-01-01T00:00:00Z",
      "endsOn": "2026-12-31T23:59:59Z",
      "depots": "Phnom Penh Central",
      "targetAmount": 3000.0,
      "rebateTiers": [
        { "minAmount": 0.0,    "maxAmount": 2000.0, "percent": 0.0 },
        { "minAmount": 2000.0, "maxAmount": 3000.0, "percent": 1.5 },
        { "minAmount": 3000.0, "maxAmount": null,   "percent": 3.0 }
      ]
    }
  ],
  "error": null
}
```

> The app reads `data.agreements` or `data.items` (an object). The doc shows `data` as a
> bare list. See [Open questions](#open-questions).

---

## 20 · Incentives feed

`GET /mobile/depots/{depotId}/incentives` · [promotions-discounts-plan.md §8.1](../prom-discount/promotions-discounts-plan.md)

**Request**

```
GET /api/v1/mobile/depots/{depotId}/incentives?shipment=Pickup
```

| Query | Notes |
|---|---|
| `shipment` | Optional: `Pickup` or `Delivery` |

**Response 200**

```json
{
  "success": true,
  "data": {
    "groups": [
      {
        "id": "depot_discount",
        "titleKey": "promotions.group.depot_discount",
        "badgeLabel": "Active Agreements",
        "promos": [
          {
            "id": "AG-2026-0045",
            "code": "AG-2026-0045",
            "title": "On-Invoice Discount — Rebar",
            "summary": "Applies to every rebar line on the quotation.",
            "kind": "onInvoice",
            "value": { "type": "percent", "percent": 2.0 },
            "status": "active",
            "startsOn": "2026-01-01T00:00:00Z",
            "endsOn": "2026-12-31T23:59:59Z",
            "category": "Rebar",
            "depots": "All Depots",
            "requires": []
          }
        ]
      },
      {
        "id": "free_goods",
        "titleKey": "promotions.group.free_goods",
        "badgeLabel": "Bonus Units",
        "promos": [
          {
            "id": "PROMO-FG-01",
            "code": "FG-CAMSTAR",
            "title": "Camstar Cement Promotion",
            "summary": "Free bags are added to the delivery, not the invoice total.",
            "kind": "buyXGetY",
            "value": { "type": "buyGet", "buy": 40, "get": 3, "unit": "BAGS" },
            "status": "active",
            "startsOn": "2026-09-01T00:00:00Z",
            "endsOn": "2026-10-31T23:59:59Z",
            "category": "Cement",
            "depots": "All Depots",
            "requires": []
          }
        ]
      }
    ],
    "activeAgreementsCount": 2,
    "pendingRequestsCount": 1
  },
  "error": null
}
```

Group ids are `depot_discount`, `cod_pickup`, `depot_requests` and `free_goods`.

---

## 21 · Depot promotions

`GET /mobile/depots/{depotId}/promotions`

**Request:** no parameters.

**Response 200:** **not documented.** The app reads a list of promotion objects from
`data.promotions`, `data.items` or `data` itself, and parses each one like a `promos[]`
item in #20. See [Open questions](#open-questions).

---

## 22 · Depot pricing

`GET /mobile/pricing/depots/{depotId}` · [order/pricing/api/mobile.md](../order/pricing/api/mobile.md)

**Request**

```
GET /api/v1/mobile/pricing/depots/{depotId}?materials=1100000000&materials=1100000003
```

| Query | Notes |
|---|---|
| `materials` | Repeat it once per material. Leave it out to get every price for the depot |

**Response 200**

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
    "source": { "recordsReturned": 1, "recordsUnmapped": 0, "erpAnswered": true }
  },
  "metadata": null,
  "traceId": "0HNOA7D1C66TK:00000001",
  "timestamp": "2026-09-04T04:16:30.6672159+00:00"
}
```

---

## Error response

The documented format is an RFC 9457 problem document:

```json
{
  "type": "https://docs.isigroup.com.kh/errors/Depot.NotFound",
  "title": "The requested resource was not found.",
  "status": 404,
  "detail": "No depot was found with identifier '…'.",
  "errorCode": "Depot.NotFound",
  "correlationId": "0HNNOE4PB87QD:00000001"
}
```

On 2026-10-08 staging answered a refused login with a different envelope:

```json
{
  "success": false,
  "error": { "code": "AUTH_INVALID_CREDENTIALS", "message": "…", "traceId": "…", "details": null }
}
```

Whether depot errors also use this envelope is not yet confirmed.

**403 with no `errorCode`:** the role is missing the permission. A depot outside the
caller's scope returns **404, not 403**.

---

## Documented, but the app doesn't call them

| Method | Path | Doc |
|---|---|---|
| PUT | `/mobile/depots/{id}` | [edit-depot.md](mobile/edit-depot.md). Same body as #5 without `depotCode` |
| DELETE | `/mobile/depots/{id}` | [api.md](api.md). Reps don't hold `depots.delete` |
| GET | `/mobile/depots/{depotId}/documents/{documentId}/content` | Document bytes. Reached through the `url` field in #15/#16 |
| GET | `/files/depots/{publicToken}` | Public photo, no auth. Reached through `publicUrl` |

## Open questions

These were checked against the code and docs only. Staging returned HTTP 502 on
2026-10-09, so the live shapes are not yet confirmed.

1. **List and detail payload key.**
   - The app reads `data.customers` and `data.customer` (ADR-0007).
   - `api.md` and `get-depot-by-id.md` show `data.depots` and `data.depot`.
2. **Agreements (#19).** The doc shows `data` as a list; the app expects an object holding
   `agreements` or `items`.
3. **Promotions (#21)** has no contract doc.
4. **Error envelope.** Staging's nested `error` object differs from the documented
   RFC 9457 format.
5. **`references?kinds=`.** The doc says the parameter is repeatable; the app sends one
   comma-joined value.
6. **Undocumented route in the app code.**
   - `POST /api/v1/depots/bp/{localId}/attachments` appears in `depot_datasources.dart`
     `uploadAttachment`.
   - It isn't documented and nothing calls it.
