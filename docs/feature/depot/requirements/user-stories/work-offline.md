# US-08 — Work Offline

**Role:** Sales Representative
**Use cases:** [UC-05 Initial Sync](../usecases/initial-sync.md), [UC-06 Delta Sync](../usecases/delta-sync.md)
**API:** `GET /api/v1/mobile/depots`
**Screen:** `DepotSyncStatusBanner` · `DepotSyncCubit`

---

## Story

> As a **Sales Representative**,
> I want to **browse and open depots with no signal**,
> so that **I can keep working in a steel yard where there is no coverage**.

---

## Acceptance criteria

- [ ] After sign-in, every depot the rep may see is synced into the encrypted local database.
- [ ] The browse and detail screens read from **local first**; the network only refreshes.
- [ ] Sync progress is visible and does not block the screen.
- [ ] Refreshes fetch only what changed since the last sync.
- [ ] Depots deleted or moved out of scope **disappear** from the device.
- [ ] An interrupted sync does not corrupt the local state or advance the watermark.
- [ ] The rep can see when data was last synced.
- [ ] A new depot registered offline is queued and submitted on reconnect.
- [ ] Nothing about connectivity blocks a read.

## Main scenario — first run

1. Rep signs in.
2. `RunDepotInitialSync` pages through `GET /mobile/depots` at 200 rows a page.
3. Rows are written to the encrypted Drift table.
4. `metadata.syncTimestamp` is stored as the watermark.
5. Browse now works with the radio off.

## Main scenario — refresh

1. App resumes.
2. `RunDepotDeltaSync` sends `modifiedSince=<watermark>&includeDeleted=true`.
3. Non-deleted rows are upserted; `deleted: true` rows are removed locally.
4. The watermark advances.

## Alternative scenarios

| Scenario | Expected |
|---|---|
| Sync interrupted | Watermark unchanged; the window is re-fetched. Upserts are idempotent |
| Nothing changed | Empty `customers[]`; watermark still advances |
| Rep offline all day | Local data serves every read; the banner shows the last sync time |
| Depot deleted server-side | Arrives as a tombstone and is removed locally |
| Rep's territory changes | Removed depots **should** arrive as tombstones — `TODO / Backend Confirmation Required` |

## Validation / error scenarios

| Condition | Expected |
|---|---|
| `syncTimestamp` missing | **Delta sync can never start** — the device re-runs a full sync forever |
| `hasNextPage` missing | Sync **silently stops after page 1**; the rep has a partial list with no error |
| Tombstones not returned | Deleted depots **stay on the handset forever** (BR-10) |
| `modifiedSince` > 5 min ahead of server time | Rejected — the client must send the server's own timestamp, never a device clock (BR-09) |
| `pageSize` clamped | Client reads `metadata.pageSize` back rather than assuming what it sent |
| Unstable sort order | Paged runs both **miss and duplicate** rows (BR-12) |
| One malformed row in a page | Degrades field by field; must not abort a 200-row sync |
