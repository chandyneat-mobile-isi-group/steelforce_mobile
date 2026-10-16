# US-03 — View Depot Detail

**Role:** Sales Representative
**Use case:** [UC-02 Get Depot Detail](../usecases/get-depot-detail.md)
**API:** `GET /api/v1/mobile/depots/{id}`
**Screen:** `DepotDetailScreen` · `DepotDetailCubit`

---

## Story

> As a **Sales Representative**,
> I want to **open one depot and see everything about it**,
> so that **I can check its credit position and contacts before I sell to it**.

---

## Acceptance criteria

- [ ] Tapping a row opens the detail screen.
- [ ] The cached row renders immediately; the full aggregate replaces it when fetched.
- [ ] The rep sees identity (shop name, depot code, SAP id), address, contacts, credit limit and balance, status, and assigned rep.
- [ ] Contacts appear **primary first, then alphabetical** — the server's order is preserved.
- [ ] The SAP block (`salesOrg`, `division`, `distributionChannel`, `depotGroup`, `priceGroup`) is shown **read-only**.
- [ ] Metrics (`lifetimeValue`, `totalOrders`, `openOpportunityCount`) are shown with their staleness, never as authoritative figures.
- [ ] Loading, loaded and error states are each designed.
- [ ] Opening a depot records local view history (no API call).
- [ ] Money is rendered with the depot's own `currency`.

## Main scenario

1. Rep taps a depot.
2. `DepotDetailLoading` → cached row renders.
3. `GET /mobile/depots/{id}` returns `data.customer`.
4. `DepotDetailLoaded` → contacts, SAP block and metrics populate.

## Alternative scenarios

| Scenario | Expected |
|---|---|
| Offline with a cached row | Summary fields render; contacts/SAP block/metrics stay blank until a fetch succeeds |
| Offline with no cached row | Error state |
| Depot has no contacts | Contacts section shows an empty state, not a blank gap |
| Depot not yet in SAP | `sapDepotId` is `null` → "Pending SAP" rather than an empty field |
| Depot is `Closed` | Edit actions disabled (BR-03) |

## Validation / error scenarios

| Condition | Expected |
|---|---|
| `data.customer` missing | `ServerException` → error state |
| 404 | "Depot not found or no longer in your territory" |
| 403 | Error state |
| `creditBalance` stale | Shown with `metricsCalculatedAt`; **never** used to build a credit block |
| `customerGroup` not mapped to `depotGroup` | Group renders blank — an easy-to-miss rename; see [UC-02](../usecases/get-depot-detail.md#response-field-mapping--detail-only-fields) |
