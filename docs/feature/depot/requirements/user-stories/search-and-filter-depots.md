# US-02 — Search and Filter Depots

**Role:** Sales Representative
**Use case:** [UC-01 Browse Depots](../usecases/browse-depots.md)
**API:** `GET /api/v1/mobile/depots`
**Screen:** `DepotSearchBar`, `DepotFilterSheet`, `DepotAudienceFilter`

---

## Story

> As a **Sales Representative**,
> I want to **search and filter my depots**,
> so that **I can find one shop quickly instead of scrolling a long list**.

---

## Acceptance criteria

- [ ] The rep can type a search term and see the list narrow.
- [ ] The rep can filter by **status** (`Draft`, `PendingApproval`, `Active`, `Suspended`, `Closed`).
- [ ] The rep can filter by **territory**.
- [ ] The rep can clear all filters in one action.
- [ ] Changing search or a filter **resets paging to page 1**.
- [ ] Active filters are visible so the rep knows why the list is short.
- [ ] An empty result shows an empty state that mentions the active filters.
- [ ] Only selectable statuses are offered — the legacy `Dormant` and `Credit Hold` values are excluded, because the server would reject them.

## Main scenario

1. Rep taps search and types "Sokha".
2. `DepotsSearchChanged` → page 1 re-query.
3. Matching depots render.

## Alternative scenarios

| Scenario | Expected |
|---|---|
| Search matches nothing | Empty state, with a way to clear |
| Filter + search together | Both applied |
| `DepotsFiltersCleared` | Full list returns |
| Sort by nearest | Computed **on-device** from coordinates; depots without a fix (`0,0`) are excluded, not sorted to the Atlantic |

## Validation / error scenarios

| Condition | Expected |
|---|---|
| Status sent as a display label instead of `apiValue` | Server rejects — the client must send `Active`, not `សកម្ម` |
| Search term with only spaces | Trimmed; treated as empty |
| Request fails mid-filter | Previous results retained; error surfaced non-destructively |

## Open questions

- **Which fields does `search` cover?** shopName, depotCode, ownerName, phone? `TODO / Backend Confirmation Required` — see [UC-01](../usecases/browse-depots.md#api-request).
- **`productCategory`** exists in `DepotFilter` but is never sent to any endpoint. Dead client state, or a planned server filter? See [`../README.md`](../README.md#13-open-questions--todo--backend-confirmation-required) Q-10.
- **Sorting:** the client offers `recentOrder`, `nameAsc`, `nearest`, `valueDesc` but only ever sends `sort=updatedAt`. Should the server support the others?
