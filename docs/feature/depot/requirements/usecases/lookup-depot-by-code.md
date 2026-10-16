# UC-04 — Look Up Depot By Code

| | |
|---|---|
| **API** | `GET /api/v1/depots/by-code/{code}` |
| **Mobile use case** | `LookupDepotByCode` |
| **Consumes into** | `DepotCodeLookup` (sealed: Found / Absent / Unavailable) |
| **Screen** | Registration identity step via `DepotCodeLookupCubit` |
| **User story** | [US-06](../user-stories/check-depot-code.md) |

---

## ⚠ This is the portal surface, not the mobile one

Two things differ from every other endpoint in this feature:

1. **The route has no `mobile/` segment** — `/api/v1/depots/by-code/{code}`.
2. **The envelope is different** — `{ data, meta }`, not
   `{ success, data, metadata }`. `ApiEnvelope` insists on a `success`-shaped
   body and **would reject this response**, so a separate mapper
   (`PortalDepotMapper`) handles it.

The depot shape also differs: `code` not `depotCode`, and a **nested `address`
object**. See [`../README.md`](../README.md#13-open-questions--todo--backend-confirmation-required) Q-04.

---

## Use case

**Description.** Before registering a shop, check whether that depot code
already exists — in the platform or in SAP — so the rep does not create a
duplicate business partner.

**Actor.** Sales Representative.

**Trigger.** The rep enters a depot code in the registration identity step.

### Main flow

1. Rep types a code; the cubit debounces and calls the endpoint.
2. `200` → `DepotCodeFound(depot)` — the shop already exists; show it and do
   **not** offer registration.
3. `404` → `DepotCodeAbsent` — safe to offer registration.

### Alternative / error flows

| Status | Result | Why it matters |
|---|---|---|
| `200` | `DepotCodeFound` | Existing depot; registration must be blocked |
| `404` | `DepotCodeAbsent` | `Depot.NotFoundByCode` — neither platform nor SAP has it. **The only outcome where offering registration is safe** |
| `502` | `DepotCodeUnavailable` | **The ERP was unreachable. The depot may well exist.** Never present as "not found" — a registration offered here creates a duplicate BP in SAP (BR-17) |
| `200` with empty payload | `DepotCodeAbsent` | `PortalDepotMapper` returns null |
| other | `ApiException` | transport failure |

> The client sets `validateStatus` to accept `200`, `404` **and** `502` so all
> three reach the branching logic instead of being thrown as transport errors.

---

## API request

```http
GET /api/v1/depots/by-code/KH-PP-00412 HTTP/1.1
Authorization: Bearer <access_token>
```

| Path parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `code` | string | Yes | The depot code to check. URL-encoded. | Non-empty |

---

## API response — 200

```json
{
  "data": {
    "id": "8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70",
    "code": "KH-PP-00412",
    "name": "Sokha Steel Shop",
    "address": {
      "line1": "No. 42, St. 271",
      "city": "Phnom Penh",
      "district": "Chamkar Mon",
      "province": "Phnom Penh"
    },
    "status": "Active"
  },
  "meta": { "source": "sap" }
}
```

### Response field mapping

Mapped by `PortalDepotMapper.fromEnvelope` → `PortalDepot`.

| Backend field | Type | Required | Mobile model field | Mapping |
|---|---|---|---|---|
| `data.id` | string | Yes | `id` | direct |
| **`data.code`** | string | Yes | **`depotCode`** | **Renamed** — the mobile payload calls this `customerCode`; the portal calls it `code` |
| `data.name` | string | Yes | `name` | direct |
| **`data.address`** | **object** | No | flattened address fields | **Nested → flat.** The mobile surface sends a flat `addressLine1`/`city`/`district`/`province` |
| `data.status` | string | No | `status` | `DepotStatus.fromApi` |
| `meta` | object | No | — | not consumed |

> **`TODO / Backend Confirmation Required`:** the exact portal depot field
> names above are inferred from `AppConstants` comments and `PortalDepotMapper`.
> Confirm each one before implementing.

## Error responses

| Status | Body | Mobile result |
|---|---|---|
| 404 | `{ "error": { "code": "Depot.NotFoundByCode" } }` | `DepotCodeAbsent` |
| 502 | ERP unreachable | `DepotCodeUnavailable` |

---

## Mobile compatibility notes

1. **Do not unify this envelope with the mobile one without telling mobile** —
   `PortalDepotMapper` would break, and `ApiEnvelope` cannot parse `{data, meta}`.
2. **404 and 502 must stay distinguishable.** Collapsing 502 into 404 causes
   duplicate business partners in SAP. This is the highest-consequence rule in
   the feature.
