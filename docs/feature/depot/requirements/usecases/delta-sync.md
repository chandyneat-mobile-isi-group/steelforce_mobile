# UC-06 — Delta Sync

| | |
|---|---|
| **API** | `GET /api/v1/mobile/depots?modifiedSince=…&includeDeleted=true` |
| **Mobile use case** | `RunDepotDeltaSync` |
| **Consumes into** | `DepotDeltaPage` → upserts + deletions |
| **Screen** | `DepotSyncStatusBanner` via `DepotSyncCubit` |
| **User story** | [US-08](../user-stories/work-offline.md) |

---

## Use case

**Description.** Fetch only what changed since the last successful sync,
**including tombstones**, so the device converges without re-reading everything.

**Actor.** System.

**Preconditions.** A watermark exists (an initial sync completed).

**Trigger.** App resume, pull-to-refresh, or a periodic refresh.

### Main flow

1. Read the stored `syncTimestamp` watermark.
2. `fetchDelta(since: watermark, page: 1, pageSize: 200)`.
3. Rows are **split by `deleted`**:
   - `deleted == false` → upsert
   - `deleted == true` → delete the local row by id
4. Page while `hasNextPage`.
5. Store the new `metadata.syncTimestamp`.

> The split happens once, in the datasource, so the repository can never forget
> to check the flag. **Dropping tombstones leaves deleted shops on the phone
> forever.**

### Alternative flows

| Flow | Behaviour |
|---|---|
| Nothing changed | Empty `customers[]`; watermark still advances |
| Interrupted | Watermark unchanged; the same window is re-fetched (upserts are idempotent) |

### Error flows

| Condition | Result |
|---|---|
| `modifiedSince` > 5 min ahead of server time | **Rejected outright** (BR-09) |
| 4xx | Not retried |
| 5xx | Retryable |

---

## API request

```http
GET /api/v1/mobile/depots
    ?modifiedSince=2026-09-25T04:00:00Z
    &pageNumber=1
    &pageSize=200
    &includeDeleted=true
    &sort=updatedAt HTTP/1.1
Authorization: Bearer <access_token>
```

| Parameter | Type | Required | Description | Validation |
|---|---|---|---|---|
| `modifiedSince` | ISO-8601 UTC | **Yes** | **Always the server's own previous `syncTimestamp`, never a device clock.** | Rejected if > 5 minutes ahead of server time |
| `includeDeleted` | boolean | Yes | Implied by `modifiedSince`, but sent explicitly — this call **must** return tombstones | — |
| `pageNumber` | integer | Yes | One-based | ≥ 1 |
| `pageSize` | integer | Yes | 200 | clamped to 200 |
| `sort` | string | Yes | `updatedAt` | — |

---

## API response

Same envelope as [UC-01](browse-depots.md#api-response). A tombstone row:

```json
{
  "success": true,
  "data": {
    "customers": [
      {
        "id": "8f14e45f-ceea-467a-9f1e-2b3c4d5e6f70",
        "shopName": "Sokha Steel Shop",
        "status": "Active",
        "updatedAt": "2026-09-25T06:14:00Z",
        "deleted": false
      },
      {
        "id": "b2c3d4e5-0000-4a1b-8c2d-3e4f5a6b7c80",
        "deleted": true,
        "updatedAt": "2026-09-25T05:58:00Z"
      }
    ]
  },
  "metadata": {
    "page": 1, "pageSize": 200,
    "totalRecords": 2, "totalPages": 1,
    "hasNextPage": false, "hasPreviousPage": false,
    "syncTimestamp": "2026-09-25T06:20:00Z",
    "isDeltaSync": true
  }
}
```

### Tombstone contract

| Backend field | Type | Required on a tombstone | Mobile handling |
|---|---|---|---|
| `id` | string | **Yes** | The only field that must be present — it is the delete key |
| `deleted` | boolean | **Yes** (`true`) | Routes the row to `deletedIds` |
| everything else | — | No | **A tombstone carries little more than an id**; every other field falls back rather than failing |

| Backend (`metadata`) | Mobile (`DepotDeltaPage`) | Purpose |
|---|---|---|
| `hasNextPage` | `hasMore` | paging loop |
| `syncTimestamp` | `syncTimestamp` | the next watermark |
| `isDeltaSync` | — | informational |

---

## Mobile compatibility notes

1. **Tombstones are mandatory** (BR-10). Without them, a depot deleted or moved
   out of the rep's scope stays visible on the handset indefinitely.
2. A tombstone must not require a full row. The mapper tolerates every field
   being absent except `id`.
3. **Scope changes count as deletes.** If a depot leaves the rep's territory it
   must arrive as a tombstone, or the device keeps data the rep may no longer see.
   **`TODO / Backend Confirmation Required`.**
4. `syncTimestamp` must advance monotonically and round-trip exactly.
