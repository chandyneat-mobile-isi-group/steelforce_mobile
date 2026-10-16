# UC-03 — Create Depot

| | |
|---|---|
| **API** | `POST /api/v1/mobile/depots` |
| **Mobile use case** | `CreateDepot` |
| **Request model** | `DepotDraft.toJson()` |
| **Consumes into** | `DepotModel` → `Depot` |
| **Screen** | `DepotCreateScreen` / `AddDepotBloc` |
| **User story** | [US-04](../user-stories/register-new-depot.md) |

---

## Use case

**Description.** Register a new depot on the platform. This is the **direct**
create — distinct from the SAP business-partner registration
([UC-09](create-business-partner.md)), which goes through a resumable draft.

**Actor.** Sales Representative.

**Preconditions.** Authenticated. The depot code has been checked
([UC-04](lookup-depot-by-code.md)) and is absent.

**Trigger.** The rep completes the add-depot form and submits.

### Main flow

1. `AddDepotBloc` validates the form locally (§Validation).
2. `CreateDepot` is called with a `DepotDraft`.
3. `POST /mobile/depots` with `DepotDraft.toJson()`.
4. `201` → the created depot is mapped and written to the local database.
5. The rep is returned to the list, which now contains the depot as `Draft`.

### Alternative flows

| Flow | Behaviour |
|---|---|
| No GPS fix | `latitude`/`longitude` are **omitted entirely** — never sent as `(0,0)` |
| Offline | Queued locally as a pending submission; retried when connectivity returns |
| Contacts added | Sent inline in `contacts[]` |

### Error flows

| Condition | Result |
|---|---|
| Duplicate code | `409 Depot.DuplicateCode` → field error on `depotCode` |
| Half coordinates | `400` |
| `(0,0)` coordinates | `Depot.CoordinatesMissing` |
| Invalid `type` | `General.Validation` — **not** `Depot.TypeInvalid` (request validation runs before the domain sees the payload) |
| 4xx | `ValidationFailure`, not retried |
| 5xx | Retryable; submission stays queued |

### Business rules

BR-01, BR-02, BR-04, BR-05, BR-06 — see [`../README.md`](../README.md#10-business-rules).

---

## API request

```http
POST /api/v1/mobile/depots HTTP/1.1
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "depotCode": "KH-PP-00412",
  "shopName": "Sokha Steel Shop",
  "type": "Retailer",
  "phone": "012 345 678",
  "addressLine1": "No. 42, St. 271",
  "city": "Phnom Penh",
  "district": "Chamkar Mon",
  "province": "Phnom Penh",
  "ownerName": "Sokha Chan",
  "whatsapp": "+85512345678",
  "territory": "PP-CENTRAL",
  "latitude": 11.5449,
  "longitude": 104.8922,
  "creditLimit": 15000.0,
  "creditTermDays": 30,
  "enName": "Sokha Steel Shop",
  "khName": "ហាងដែក សុខា",
  "contacts": [
    { "name": "Bopha Lim", "phone": "098765432", "position": "Accounts", "isPrimary": false }
  ]
}
```

| Field | Type | Required | Description | Validation |
|---|---|---|---|---|
| `depotCode` | string | **Yes** | Business key. **Immutable once created** — renaming orphans every SAP document, order and statement | Unique; duplicate → `409 Depot.DuplicateCode` |
| `shopName` | string | **Yes** | Trading name | Non-empty |
| `type` | string | **Yes** | `Retailer` \| `Wholesaler` \| `Distributor` \| `KeyAccount` | Invalid → `General.Validation` |
| `phone` | string | **Yes** | `012 345 678`, `+855-12-345-678` and `012345678` are all accepted; server strips spaces, dashes, brackets | Non-empty |
| `addressLine1` | string | **Yes** | Street address | Non-empty |
| `city` | string | **Yes** | City | Non-empty |
| `district` | string | No | Omitted when null | — |
| `province` | string | No | Omitted when null | — |
| `ownerName` | string | No | Omitted when null | — |
| `whatsapp` | string | No | Omitted when null | — |
| `territory` | string | No | Omitted when null | — |
| `latitude` | number | No | **Both or neither** with `longitude` | \|lat\| ≤ 90; not `(0,0)` |
| `longitude` | number | No | **Both or neither** with `latitude` | \|lng\| ≤ 180; not `(0,0)` |
| `creditLimit` | number | No | **Scalar on write**, object on read | ≥ 0 |
| `creditTermDays` | integer | No | Payment terms in days | 0–180 |
| `enName` | string | No | English legal name | — |
| `khName` | string | No | Khmer shopfront name | — |
| `contacts[]` | array | No | Inline contacts — see below | — |

### `contacts[]` on write

Sent by `DepotContactDraft.toJson()`.

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | **Yes** | Contact name |
| `phone` | string | **Yes** | Contact phone |
| `position` | string | No | Job title. **Omitted entirely when null** |
| `isPrimary` | boolean | **Yes** | Always sent; defaults to `false` |

> **No `email` on write.** The create payload has no email field for contacts,
> although the detail response returns one. See §Mobile compatibility notes.

> **Asymmetry to note:** `creditLimit` is a **plain number on write** but a
> `{amount, currency}` **object on read**. This is what the client does today.

### Fields that must be rejected on write

`sapCustomerId`, `salesOrg`, `division`, `distributionChannel`, `customerGroup`,
`priceGroup`, `paymentTerms`, `status`. **SAP owns these** — letting a phone set
`salesOrg` lets the field invent master data the ERP then contradicts (BR-05).

---

## API response — 201 Created

```http
HTTP/1.1 201 Created
Location: /api/v1/mobile/depots/8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70
```

```json
{
  "success": true,
  "message": "Depot created",
  "data": {
    "customer": {
      "id": "8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70",
      "customerCode": "KH-PP-00412",
      "sapCustomerId": null,
      "shopName": "Sokha Steel Shop",
      "status": "Draft",
      "statusDisplay": "Draft",
      "createdAt": "2026-09-25T04:12:00Z",
      "updatedAt": "2026-09-25T04:12:00Z",
      "deleted": false
    }
  }
}
```

### Response mapping

Identical to [UC-02](get-depot-detail.md#response-field-mapping) — the response
is parsed by `DepotApiMapper.fromDetail`.

**Envelope tolerance:** the client reads `data.customer` **and falls back to
`data`** if that key is absent, rather than losing a depot the server has
already committed. Prefer `data.customer` for consistency.

Two rules the response must honour:

| Field | Requirement |
|---|---|
| `status` | Must be `"Draft"` — a created depot cannot trade until approved (BR-02) |
| `sapCustomerId` | Must be **`null`**, not `""` — the local column is UNIQUE and `""` collides on the second such depot |

---

## Error responses

| Status | Code | Field | Mobile behaviour |
|---|---|---|---|
| 400 | `General.Validation` | varies | `ValidationFailure(field)` — inline field error |
| 400 | — | coordinates | Half a coordinate pair |
| 409 | `Depot.DuplicateCode` | `depotCode` | Inline error; rep must change the code |
| 422 | `Depot.CoordinatesMissing` | `latitude` | `(0,0)` was sent |
| 422 | `Depot.Closed` | — | Editing a closed depot (BR-03) |
| 5xx | — | — | Retryable; stays queued |

Expected 4xx body:

```json
{
  "error": {
    "code": "Depot.DuplicateCode",
    "message": "A depot with this code already exists.",
    "fieldErrors": { "depotCode": "Already in use" },
    "correlationId": "…"
  }
}
```

`ApiError.fromDio` reads `fieldErrors`; the first key becomes
`ValidationFailure.field`. **`TODO / Backend Confirmation Required`** — confirm
the exact error body shape against `core/network/api/api_error.dart`.

---

## Mobile compatibility notes

1. `creditLimit` scalar-on-write vs object-on-read is asymmetric but matches
   the client. Changing either side needs a mobile change.
2. Coordinates are **omitted**, not nulled, when there is no fix.
3. **Contacts are asymmetric between write and read.** Write sends
   `{name, phone, position?, isPrimary}`; the detail response returns
   `{id, name, position, phone, email}`. So:
   - `isPrimary` is **sent but never read back** — the client infers primacy
     from the server's contact ordering instead (primary first).
   - `email` is **read but never sent** — a contact email cannot be set at
     create time.
   - The wire name is `position` in **both** directions; only the mobile model
     calls it `role` (`DepotContactModel.role`). See
     [UC-02](get-depot-detail.md#contact-mapping).

   `TODO / Backend Confirmation Required` — should create accept a contact
   `email`, and is `isPrimary` honoured or ignored?
