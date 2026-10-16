# US-01 — View My Depots

**Role:** Sales Representative
**Use case:** [UC-01 Browse Depots](../usecases/browse-depots.md)
**API:** `GET /api/v1/mobile/depots`
**Screen:** `DepotsScreen` · `DepotsBloc`

---

## Story

> As a **Sales Representative**,
> I want to **view the depots assigned to me**,
> so that **I can manage the shops and customers I am responsible for**.

---

## Acceptance criteria

- [ ] The rep can open the Depots screen from the main shell.
- [ ] The screen loads the depots the signed-in rep is permitted to see — scoping is applied **server-side**; the app sends no territory filter.
- [ ] Each row shows shop name, depot code, status and location.
- [ ] Status is rendered from `statusDisplay` (localised) but all logic branches on `status`.
- [ ] A **loading** state is shown while the first page loads.
- [ ] An **empty** state is shown when the rep has no depots — visually distinct from an error.
- [ ] An **error** state with a retry action is shown when the load fails and there is no cached data.
- [ ] Scrolling to the end loads the next page while `metadata.hasNextPage` is true.
- [ ] Pull-to-refresh re-reads page 1.
- [ ] Rows are served from the local database first, so the screen is usable offline.
- [ ] All labels are localised in English and Khmer.

## Main scenario

1. Rep signs in and opens Depots.
2. `DepotsLoading` → skeleton list.
3. Local rows render immediately.
4. `GET /mobile/depots?pageNumber=1&pageSize=50&sort=updatedAt` refreshes them.
5. `DepotsLoaded` → the list, with `hasMore` driving load-more.

## Alternative scenarios

| Scenario | Expected |
|---|---|
| Rep has no depots | Empty state: "No depots assigned yet" |
| Offline, cache present | List renders from cache; no error banner |
| Offline, cache empty | Error state with retry |
| Last page reached | Load-more stops; no spinner left spinning |
| Rep's scope changed server-side | Removed depots arrive as tombstones on the next delta sync ([UC-06](../usecases/delta-sync.md)) |

## Validation / error scenarios

| Condition | Expected |
|---|---|
| `4xx` | Error state; **not** retried automatically |
| `5xx` with cache | Cached list retained; refresh fails silently |
| `5xx` without cache | Error state with retry |
| `data.customers` missing/renamed | **Empty list with no error** — a silent failure mode; see [UC-01](../usecases/browse-depots.md#mobile-compatibility-notes) |
| Unknown `status` value | Degrades to `Draft` (cannot trade), never crashes |
