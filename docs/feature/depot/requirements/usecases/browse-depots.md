# UC-01 — Browse Depots

| | |
|---|---|
| **API** | `GET /api/v1/mobile/depots` |
| **Mobile use case** | `BrowseDepots` (`domain/usecases/browse_depots.dart`) |
| **Consumes into** | `DepotModel` → `Depot` |
| **Screen** | `DepotsScreen` via `DepotsBloc` |
| **User story** | [US-01](../user-stories/view-my-depots.md), [US-02](../user-stories/search-and-filter-depots.md) |

---

## Use case

**Description.** Return a paged, searchable, filterable list of the depots the
caller is permitted to see, for the browse screen and for the offline sync.

**Actor.** Sales Representative (also Supervisor / Manager, with a wider scope).

**Preconditions.** Caller is authenticated. Row-level scoping is applied
server-side — the app never sends "my territory".

**Trigger.** Opening the depots screen, pull-to-refresh, scrolling to the end of
the list, typing in search, or changing a filter.

### Main flow

1. `DepotsBloc` receives `DepotsLoadRequested`, emits `DepotsLoading`.
2. `BrowseDepots` is called with `page`, `pageSize`, `query`, `filter`.
3. The repository reads the **local database first** and emits it.
4. The remote call refreshes; rows are upserted locally.
5. `DepotsLoaded` is emitted with the rows and `hasMore`.

### Alternative flows

| Flow | Behaviour |
|---|---|
| `DepotsLoadMoreRequested` | Next `pageNumber`; append. Stops when `metadata.hasNextPage == false`. |
| `DepotsSearchChanged` | Re-query from page 1. |
| `DepotsFilterChanged` / `DepotsFiltersCleared` | Re-query from page 1. |
| No rows | `DepotsLoaded` with an empty list → empty state (distinct from error). |
| Offline | Local rows are served; no error is shown if the cache is non-empty. |

### Error flows

| Condition | Result |
|---|---|
| `4xx` | `ValidationFailure` — not retried. |
| `5xx` / transport, cache non-empty | Local rows shown; refresh silently fails. |
| `5xx` / transport, cache empty | `DepotsError` → `DepotErrorState` with retry. |

### Business rules

Applies BR-07, BR-08, BR-11, BR-12 from [`../README.md`](../README.md#10-business-rules).

---

## API request

```http
GET /api/v1/mobile/depots?pageNumber=1&pageSize=50&sort=updatedAt HTTP/1.1
Authorization: Bearer <access_token>
Accept-Language: km
```

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `pageNumber` | integer | Yes | **One-based.** Sending `0` is treated as `1` and silently re-fetches page 1. | ≥ 1 |
| `pageSize` | integer | Yes | Rows per page. **Clamped to 200, not rejected** — read `metadata.pageSize` back. | 1–200 |
| `sort` | string | Yes | Mobile always sends `updatedAt`. Required for stable paging (BR-12). | `updatedAt` |
| `search` | string | No | Free text. `TODO / Backend Confirmation Required` — which fields it covers (shopName, depotCode, ownerName, phone?). |
| `status` | string | No | One of `Draft`, `PendingApproval`, `Active`, `Suspended`, `Closed`. Must be the `apiValue`, not the display label. |
| `territory` | string | No | Territory code. |
| `modifiedSince` | ISO-8601 UTC | No | Delta mode — see [UC-06](delta-sync.md). |
| `includeDeleted` | boolean | No | Delta mode; returns tombstones. |

> **Not sent today:** `DepotFilter.productCategory` exists in the client but
> reaches no endpoint. See [`../README.md`](../README.md#13-open-questions--todo--backend-confirmation-required) Q-10.

### Sorting

`DepotSortBy` has four client values — `recentOrder`, `nameAsc`, `nearest`,
`valueDesc` — but only `updatedAt` is ever sent. `nearest` is computed on-device
from coordinates. **`TODO / Backend Confirmation Required`:** should the server
support the other three sorts, or do they stay client-side?

---

## API response

```json
{
  "success": true,
  "message": "Depots retrieved",
  "data": {
    "customers": [
      {
        "id": "8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70",
        "sapCustomerId": "0001002345",
        "customerCode": "KH-PP-00412",
        "shopName": "ហាងដែក សុខា",
        "enName": "Sokha Steel Shop",
        "khName": "ហាងដែក សុខា",
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
        "statusDisplay": "សកម្ម",
        "assignedRepId": "rep-0091",
        "assignedRepName": "Dara Sok",
        "createdAt": "2026-03-04T02:11:00Z",
        "updatedAt": "2026-09-21T08:45:12Z",
        "lastOrderDate": "2026-09-18T00:00:00Z",
        "lastVisitDate": "2026-09-20T03:12:00Z",
        "deleted": false
      }
    ]
  },
  "metadata": {
    "page": 1,
    "pageSize": 50,
    "totalRecords": 318,
    "totalPages": 7,
    "hasNextPage": true,
    "hasPreviousPage": false,
    "syncTimestamp": "2026-09-25T04:00:00Z",
    "isDeltaSync": false
  },
  "traceId": "0f9c2a1b-...",
  "timestamp": "2026-09-25T04:00:00Z"
}
```

> The array key is **`customers`**, not `depots`. `ApiEnvelope.list('customers')`
> reads it literally; renaming it returns zero rows silently. The route feed made
> exactly this mistake and shipped empty lists.

### Response field mapping

Mapped in `DepotApiMapper.fromSummary` → `DepotModel`.

| Backend field | Type | Required | Mobile model field | Mapping / fallback |
|---|---|---|---|---|
| `id` | string | Yes | `id` | `toString()`; `''` if absent |
| `sapCustomerId` | string \| null | No | **`sapDepotId`** | **Renamed.** Must stay `null`, never `''` — the local column is UNIQUE and `''` collides across rows, aborting the sync batch |
| `customerCode` | string | Yes | **`depotCode`** | **Renamed.** `''` fallback |
| `shopName` | string | Yes | `shopName` | Server-localised via `Accept-Language`; fallback chain requested → English → legal name |
| `enName` | string \| null | No | `enName` | Returned regardless of language |
| `khName` | string \| null | No | `khName` | Returned regardless of language |
| `ownerName` | string | No | `ownerName` | `''` fallback |
| `phone` | string | No | `phone` | `''` fallback |
| `email` | string \| null | No | `email` | nullable |
| `whatsapp` | string \| null | No | `whatsapp` | nullable |
| `addressLine1` | string \| null | No | `address` | **Not in the summary DTO.** Falls back to `"{district}, {city}"`; blank street until the depot is opened |
| `city` | string | No | — | used only in the `address` fallback |
| `province` | string | No | `province` | `''` fallback |
| `district` | string | No | `district` | `''` fallback |
| `territory` | string | No | `territory` | `''` fallback |
| `latitude` | number \| null | No | `latitude` | **`(0,0)` means absent.** Null, half-pair, or out of range → `(0,0)`. Local schema is non-null; use `hasCoordinates` to tell real from unknown |
| `longitude` | number \| null | No | `longitude` | as above |
| `currency` | string | No | `currency` | `'USD'` fallback; one currency per depot, shared by all money fields |
| `creditLimit` | **object** `{amount, currency}` | No | `creditLimit` (**double**) | `Money.fromJson(...).amount` — **object → scalar** |
| `creditBalance` | **object** | No | `creditBalance` (**double**) | as above. Only as fresh as the last SAP run — do not build a credit block on it |
| `status` | string | Yes | `status` (`DepotStatus`) | `DepotStatus.fromApi`; unknown → `draft` (BR-08) |
| `statusDisplay` | string | Yes | *(render only)* | **Not stored.** Localised; never branch on it (BR-07) |
| `assignedRepId` | string | No | `assignedRepId` | `''` fallback |
| `assignedRepName` | string | No | `assignedRepName` | `''` in the summary; supplied by the detail payload |
| `createdAt` | ISO-8601 | No | `createdAt` (`DateTime?`) | `parseUtc` |
| `updatedAt` | ISO-8601 | Yes | `updatedAt` (`DateTime`) | `parseUtc`, else `createdAt`, else `now()` |
| `lastOrderDate` | ISO-8601 \| null | No | `lastOrderDate` | `parseUtc` |
| `lastVisitDate` | ISO-8601 \| null | No | `lastVisitDate` | `parseUtc` |
| `deleted` | boolean | No | `deleted` | `false` fallback; `true` = tombstone (UC-06) |

### Metadata mapping

| Backend | Type | Mobile (`ApiMetadata`) | Use |
|---|---|---|---|
| `page` | int | `page` | — |
| `pageSize` | int | `pageSize` | **Read back** — the request value may have been clamped |
| `totalRecords` | int | `totalRecords` | — |
| `totalPages` | int | `totalPages` | — |
| `hasNextPage` | bool | `hasNextPage` | drives `hasMore` / load-more |
| `hasPreviousPage` | bool | `hasPreviousPage` | — |
| `syncTimestamp` | ISO-8601 | `syncTimestamp` | stored as the next `modifiedSince` (BR-09) |
| `isDeltaSync` | bool | `isDeltaSync` | — |

### Type transformations required

```text
creditLimit:  { "amount": 15000.0, "currency": "USD" }  →  double 15000.0
createdAt:    "2026-03-04T02:11:00Z"                    →  DateTime (UTC)
status:       "Active"                                  →  DepotStatus.active
latitude/longitude: null or (0,0)                       →  (0,0) sentinel = "unknown"
```

---

## Error responses

| Status | Code | Mobile behaviour |
|---|---|---|
| 400 | `General.Validation` | `ValidationFailure`; not retried |
| 401 | — | Token refresh, then retry once |
| 403 | — | `DepotsError` |
| 422 | — | `ValidationFailure` |
| 5xx | — | Retryable; local cache still served |

---

## Mobile compatibility notes

1. **`data.customers` is load-bearing.** Renaming to `depots` returns an empty
   list with no error.
2. **Money must be an object.** A bare number does not break `Money.fromJson`
   (`TODO / Backend Confirmation Required` — verify), but the object form is what
   the client documents and expects.
3. **`sapCustomerId` must be `null`, not `""`,** when the depot is not yet in
   SAP. Most rows in a fresh territory are `PendingApproval` with no SAP id.
4. **Every field except `id`, `status` and `updatedAt` tolerates absence** — the
   mapper degrades rather than throwing, because one unexpected null in a 200-row
   page would otherwise abort an entire sync.
