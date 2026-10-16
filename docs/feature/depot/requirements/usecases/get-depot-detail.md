# UC-02 — Get Depot Detail

| | |
|---|---|
| **API** | `GET /api/v1/mobile/depots/{id}` |
| **Mobile use case** | `GetDepotById` |
| **Consumes into** | `DepotModel` → `Depot` (full aggregate) |
| **Screen** | `DepotDetailScreen` via `DepotDetailCubit` |
| **User story** | [US-03](../user-stories/view-depot-detail.md) |

---

## Use case

**Description.** Return one depot in full — the summary plus contacts, the SAP
block and the denormalised metric cache.

**Actor.** Sales Representative.

**Preconditions.** Authenticated; the depot is within the caller's scope.

**Trigger.** Tapping a depot row, or a deep link into a depot.

### Main flow

1. `DepotDetailCubit` emits `DepotDetailLoading`.
2. The local row is read and emitted immediately (the list already synced it).
3. `GET /mobile/depots/{id}` refreshes the aggregate.
4. `DepotDetailLoaded` is emitted with the full depot.
5. `RecordDepotViewed` writes local view history (no API).

### Alternative flows

| Flow | Behaviour |
|---|---|
| Offline with a local row | Local row shown; detail-only fields (contacts, SAP block, metrics) are blank until a successful fetch |
| Offline with no local row | `DepotDetailError` |

### Error flows

| Condition | Result |
|---|---|
| `data.customer` missing | `ServerException("The depot response was missing its payload.")` |
| 404 | `DepotDetailError` — depot not found or out of scope |
| 4xx | `ValidationFailure` |
| 5xx | Retryable; local row retained |

---

## API request

```http
GET /api/v1/mobile/depots/8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70 HTTP/1.1
Authorization: Bearer <access_token>
Accept-Language: en
```

| Path parameter | Type | Required | Description |
|---|---|---|---|
| `id` | string (GUID) | Yes | The depot's platform id — **not** `customerCode`, not `sapCustomerId` |

No query parameters. No request body.

---

## API response

```json
{
  "success": true,
  "data": {
    "customer": {
      "id": "8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70",
      "sapCustomerId": "0001002345",
      "customerCode": "KH-PP-00412",
      "shopName": "Sokha Steel Shop",
      "ownerName": "Sokha Chan",
      "phone": "012345678",
      "email": "sokha@example.com",
      "whatsapp": "+85512345678",
      "addressLine1": "No. 42, St. 271",
      "city": "Phnom Penh",
      "district": "Chamkar Mon",
      "province": "Phnom Penh",
      "territory": "PP-CENTRAL",
      "latitude": 11.5449,
      "longitude": 104.8922,
      "currency": "USD",
      "creditLimit":   { "amount": 15000.00, "currency": "USD" },
      "creditBalance": { "amount":  4230.50, "currency": "USD" },
      "status": "Active",
      "statusDisplay": "Active",
      "assignedRepId": "rep-0091",
      "assignedRepName": "Dara Sok",
      "taxNumber": "K001-901234567",
      "salesOrg": "1000",
      "division": "10",
      "distributionChannel": "10",
      "customerGroup": "Z1",
      "priceGroup": "P2",
      "lifetimeValue": { "amount": 184320.00, "currency": "USD" },
      "totalOrders": 47,
      "openOpportunityCount": 3,
      "metricsCalculatedAt": "2026-09-25T02:00:00Z",
      "contacts": [
        { "id": "c-1", "name": "Sokha Chan", "position": "Owner",   "phone": "012345678", "email": "sokha@example.com" },
        { "id": "c-2", "name": "Bopha Lim",  "position": "Accounts", "phone": "098765432", "email": null }
      ],
      "createdAt": "2026-03-04T02:11:00Z",
      "updatedAt": "2026-09-21T08:45:12Z",
      "deleted": false
    }
  },
  "traceId": "…",
  "timestamp": "2026-09-25T04:00:00Z"
}
```

> Wrapped **one level deeper than the list**: `data.customer`, singular. The
> list is `data.customers`. Both keep SAP's noun (ADR-0007).

### Response field mapping — detail-only fields

Everything in [UC-01](browse-depots.md#response-field-mapping) applies. Mapped by
`DepotApiMapper.fromDetail`, which calls `fromSummary` then overlays:

| Backend field | Type | Required | Mobile model field | Mapping |
|---|---|---|---|---|
| `assignedRepName` | string | No | `assignedRepName` | Re-read at detail level (the summary leaves it `''`) |
| `taxNumber` | string \| null | No | `taxNumber` | direct |
| `salesOrg` | string \| null | No | `salesOrg` | **Read-only** (BR-05) |
| `division` | string \| null | No | `division` | **Read-only** |
| `distributionChannel` | string \| null | No | `distributionChannel` | **Read-only** |
| **`customerGroup`** | string \| null | No | **`depotGroup`** | **Renamed.** Read-only |
| `priceGroup` | string \| null | No | `priceGroup` | **Read-only** |
| `lifetimeValue` | **object** | No | `lifetimeValue` (**double**) | `Money.fromJson(...).amount` |
| `totalOrders` | number | No | `totalOrders` (int) | `0` fallback |
| `openOpportunityCount` | number | No | `openOpportunityCount` (int) | `0` fallback |
| `metricsCalculatedAt` | ISO-8601 | No | *(staleness display)* | Metrics are **never authoritative** |
| `contacts[]` | array | No | `contacts` (`List<DepotContact>`) | `[]` fallback |

### Contact mapping

| Backend | Type | Required | Mobile (`DepotContactModel`) | Mapping |
|---|---|---|---|---|
| `id` | string | Yes | `id` | `toString()`, `''` fallback |
| `name` | string | Yes | `name` | `''` fallback |
| **`position`** | string | Yes | **`role`** | **Renamed.** Accepts `position` **or** `role`; `position` wins |
| `phone` | string | No | `phone` | `''` fallback |
| `email` | string \| null | No | `email` | nullable |

> **Contact order is contractual.** Primary first, then alphabetical. A stable
> order stops the local diff showing phantom changes on every sync — and it is
> how the client knows which contact is primary, since the detail payload has no
> `isPrimary` flag (the create payload sends one; see
> [UC-03](create-depot.md#contacts-on-write)).

---

## Error responses

| Status | Code | Mobile behaviour |
|---|---|---|
| 200 but no `data.customer` | — | `ServerException` |
| 404 | `Depot.NotFound` *(TODO: confirm code)* | `DepotDetailError` |
| 403 | — | `DepotDetailError` |
| 5xx | — | Retryable; local row retained |

---

## Mobile compatibility notes

1. **`customerGroup` → `depotGroup`** is the one rename that is easy to miss;
   it exists only on the detail payload.
2. **Money objects → doubles** for `creditLimit`, `creditBalance`,
   `lifetimeValue`.
3. `metricsCalculatedAt` is read for staleness display. **`TODO / Backend
   Confirmation Required`** — confirm the key name; the mapper does not read it
   today, only the comment references it.
