# UC-05 — Initial Sync

| | |
|---|---|
| **API** | `GET /api/v1/mobile/depots` (paged, no `modifiedSince`) |
| **Mobile use case** | `RunDepotInitialSync` |
| **Consumes into** | `DepotInitialPage` → `DepotModel[]` → local Drift table |
| **Screen** | `DepotSyncStatusBanner` via `DepotSyncCubit` |
| **User story** | [US-08](../user-stories/work-offline.md) |

---

## Use case

**Description.** Fill an empty device with every depot the rep may see, so the
browse screen works with no connectivity.

**Actor.** System (triggered on first run / after a reset).

**Preconditions.** Authenticated; the local depot table is empty or has no
sync watermark.

**Trigger.** First launch after sign-in, or a manual re-sync.

### Main flow

1. `DepotSyncCubit` starts; the banner shows progress.
2. `fetchInitial(page: 1, pageSize: 200)`.
3. Rows are mapped and upserted into the encrypted Drift table.
4. While `metadata.hasNextPage`, increment `pageNumber` and repeat.
5. On the final page, store `metadata.syncTimestamp` as the watermark.
6. The banner clears; the list is served from local.

### Alternative flows

| Flow | Behaviour |
|---|---|
| Interrupted mid-run | The watermark is **not** advanced; the next run restarts the initial sync |
| Zero depots | Completes with an empty table; browse shows the empty state |

### Error flows

| Condition | Result |
|---|---|
| Any page fails | Sync aborts; watermark unchanged; retry later |
| 4xx | Not retried |

### Business rules

BR-11 (pageSize clamp), BR-12 (stable sort) — mandatory here.

---

## API request

```http
GET /api/v1/mobile/depots?pageNumber=1&pageSize=200&sort=updatedAt HTTP/1.1
Authorization: Bearer <access_token>
```

| Parameter | Value | Required | Notes |
|---|---|---|---|
| `pageNumber` | 1, 2, 3 … | Yes | **One-based.** `0` is silently treated as `1` |
| `pageSize` | 200 | Yes | `AppConstants.maxPageSize`. **Clamped, not rejected** — read `metadata.pageSize` back |
| `sort` | `updatedAt` | Yes | **Mandatory.** Without a stable order a paged run both misses and duplicates rows (BR-12) |

No `modifiedSince`, no `includeDeleted` — this is a full read.

---

## API response

Identical to [UC-01](browse-depots.md#api-response). The fields this use case
depends on:

| Backend (`metadata`) | Type | Required | Mobile (`DepotInitialPage`) | Purpose |
|---|---|---|---|---|
| `hasNextPage` | boolean | **Yes** | `hasMore` | Drives the paging loop. Missing → `false` → **sync stops after page 1** |
| `syncTimestamp` | ISO-8601 UTC | **Yes** | `syncTimestamp` | Stored as the delta watermark. Missing → delta sync can never start |
| `pageSize` | integer | **Yes** | `pageSize` | Read back because the request value may have been clamped |

Rows map through `DepotApiMapper.fromSummary` — see
[UC-01](browse-depots.md#response-field-mapping).

---

## Mobile compatibility notes

1. **`hasNextPage` and `syncTimestamp` are load-bearing.** Omit either and the
   device silently ends up with one page and no delta capability.
2. `syncTimestamp` must be the **server's clock**, and must round-trip exactly
   when sent back as `modifiedSince` (BR-09).
3. A 200-row page must not fail on one bad row — the mapper degrades every
   field, but the server should still avoid nulls in `id`.
