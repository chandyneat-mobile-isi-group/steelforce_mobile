# Check-in & Check-out — Backend API Requirements

> **Status: PROPOSED — needs backend review.** Nothing in §4–§6 exists on the
> server yet. Field names marked **new** are proposals; confirm or rename them
> before the mobile app builds against them.
>
> **Audience:** backend engineers building the visit endpoints.
> **Related:** [api.md](api.md) (the current visits contract — §6.1 push,
> §7.3 CheckIn, §7.4 CheckOut, §8 server validation),
> [../quotation-orders/api/mobile.md](../quotation-orders/api/mobile.md)
> (quotations).

---

## 1. Why this is needed

Today check-in and check-out only reach the server inside the batch
`POST /api/v1/mobile/visits/push` (api.md §6.1). That works offline, but:

| Problem today | Effect for the rep |
|---|---|
| No endpoint answers "did my check-in land, and did it count?" | The app only knows what it saved on the phone. The stop's state on screen is local, not the server's. |
| No endpoint returns the server's view of a visit | After reinstalling or switching phones, past check-ins/outs for today are missing. A supervisor's correction never reaches the app. |
| Check-out has no **outcome** | The server cannot tell "visited and ordered" from "visited, no order". Sales reports cannot count conversion per visit. |
| Quotations carry no stop or visit link (`POST /quotations` takes `depotId`, `shipmentType`, `shipTo`) | An order taken at a shop cannot be tied to the visit it came from. |

**Goal:** check-in and check-out become real server records the app reads back.
They must keep working offline exactly as now, and a check-out must say whether
the visit ended **with an order** or **without an order**.

---

## 2. The visit flow these endpoints serve

```
Stop (planned on route)
   │
   ▼
CHECK-IN  ── GPS, accuracy, distance from shop, photo(s)
   │
   ├── rep takes order(s) → quotation / sales order (Order feature)
   │
   ▼
CHECK-OUT ── the rep picks one:
   ├── (A) Check out WITH order     → links the order(s) taken at this stop
   └── (B) Check out WITHOUT order  → required reason (+ optional note)
```

Rules the app already enforces, and the server should also hold to:

1. A stop has **at most one open visit** (checked in, not checked out).
2. Check-out requires a check-in on the same stop.
3. "With order" needs **at least one** order reference. "Without order" needs a
   **reason**.
4. The rep works one stop at a time: the app does not let them check in at
   stop B while stop A is still open. Server behaviour for this: §8, Q3.

---

## 3. Rules that carry over unchanged (api.md §3)

These are not new, but every endpoint below must follow them:

- **The client generates every id.** Check-ins, check-outs and quotations are
  created offline. The server stores the client id as the primary key.
- **Every write is idempotent on that id.** The same check-in sent twice (online
  call, then again in a later `/push`) returns success and the same record. It
  must never create a second row or return a duplicate-key error.
- **Arrival order is not event order.** A check-out may arrive before its
  check-in, and an order may arrive before or after the check-out. Store them
  all and reconcile by `stopId` and the timestamps.
- **The device timestamp is the event time.** Store it as sent, plus the
  server's receipt time. Never overwrite the device time.
- **Scope comes from the token.** A `stopId` that is not on a route assigned to
  the caller is refused (`Visit.StopNotFound`).

---

## 4. Endpoints

| # | Method & path | Purpose | Status |
|---|---|---|---|
| 4.1 | `POST /api/v1/mobile/visits/check-ins` | Check in at a stop (online) | **new** |
| 4.2 | `POST /api/v1/mobile/visits/check-outs` | Check out, with or without order (online) | **new** |
| 4.3 | `GET  /api/v1/mobile/visits/stops/{stopId}/visit` | The server's view of one stop's visit | **new** |
| 4.4 | `GET  /api/v1/mobile/visits/check-out-reasons` | "No order" reason list | **new** |
| 4.5 | `POST /api/v1/mobile/visits/push` | Offline batch — gains the new check-out fields | **change** |
| 4.6 | `GET  /api/v1/mobile/visits/routes` (+ `/delta`) | Each stop gains a `visit` object | **change** |
| 4.7 | `POST /api/v1/mobile/quotations` | Gains `stopId` + `clientId` so an order can be linked to a visit | **change** |

**Online vs offline:**
- When online, the app calls 4.1 and 4.2 directly and shows the server's answer.
- When offline, the same records (same ids) go through 4.5 later.
- **The server must treat a record identically whichever way it arrives.**

---

### 4.1 `POST /api/v1/mobile/visits/check-ins`

**Request** — the same fields as api.md §7.3, plus `routeId`:

```json
{
  "id": "ci-6f1c2a",
  "stopId": "stop-1042",
  "routeId": "route-88",
  "timestamp": "2026-10-05T09:12:44+07:00",
  "latitude": 11.5621,
  "longitude": 104.9160,
  "accuracy": 8.5,
  "distanceFromDepot": 23.0,
  "isMocked": false,
  "overrideReason": null,
  "photoIds": ["ph-a1", "ph-a2"]
}
```

| Field | Type | Req. | Notes |
|---|---|---|---|
| `id` | string | ✔ | Client-generated. The idempotency key. **This is also the visit's id** (see 4.3). |
| `stopId` | string | ✔ | Must be on a route assigned to the caller. |
| `routeId` | string | – | **new**, optional. Lets the server reject a stale stop quickly. |
| `timestamp` | ISO-8601 with offset | ✔ | Device clock. |
| `latitude`, `longitude` | number | ✔ | Where the rep was. `(0,0)` = no fix → store as *unverifiable*, do not refuse. |
| `accuracy` | number | ✔ | Metres. |
| `distanceFromDepot` | number | ✔ | Metres from the shop pin. Evidence, not a verdict. |
| `isMocked` | bool | ✔ | Fraud signal. **Store and flag; never refuse.** |
| `overrideReason` | string | – | Present only when the rep checked in outside the geofence and gave a reason. Leave the field out otherwise; don't send `null`. |
| `photoIds` | string[] | – | **new**. Ids of shopfront photos uploaded through `POST /visits/photos` (api.md §6.2). A photo may arrive after the check-in. Link them when it does. |

**Response 200** — a `VisitDto` (§5):

```json
{
  "data": {
    "visitId": "ci-6f1c2a",
    "stopId": "stop-1042",
    "status": "checkedIn",
    "checkIn": {
      "id": "ci-6f1c2a",
      "timestamp": "2026-10-05T09:12:44+07:00",
      "receivedAt": "2026-10-05T09:12:46+07:00",
      "geofence": "inside",
      "flagged": false
    },
    "checkOut": null
  }
}
```

**Idempotency:**
- **Same `id` sent again:** return 200 with the stored visit, unchanged.
- **Different `id` on a stop that already has an open check-in:** return
  `409 Visit.AlreadyCheckedIn`, with the existing `VisitDto` in `error.details`.
  The app then adopts the server's visit instead of creating a second one.
- **Stop is already checked out today:** return `409 Visit.AlreadyCompleted`,
  with the `VisitDto`. Whether a second visit on the same day is allowed is
  question Q2 in §8.

---

### 4.2 `POST /api/v1/mobile/visits/check-outs`

There's one endpoint with two shapes. The **new** field `outcome` decides which
fields are required.

#### (A) Check out WITH order

```json
{
  "id": "co-91be07",
  "checkInId": "ci-6f1c2a",
  "stopId": "stop-1042",
  "timestamp": "2026-10-05T09:58:10+07:00",
  "latitude": 11.5622,
  "longitude": 104.9161,
  "durationMinutes": 45,
  "visitSummary": "Ordered rebar for next week",
  "outcome": "withOrder",
  "orders": [
    { "clientId": "qt-local-5521", "quotationId": "Q-2026-00981" },
    { "clientId": "qt-local-5522", "quotationId": null }
  ]
}
```

#### (B) Check out WITHOUT order

```json
{
  "id": "co-91be07",
  "checkInId": "ci-6f1c2a",
  "stopId": "stop-1042",
  "timestamp": "2026-10-05T09:58:10+07:00",
  "latitude": 11.5622,
  "longitude": 104.9161,
  "durationMinutes": 20,
  "visitSummary": null,
  "outcome": "withoutOrder",
  "noOrderReason": "stockStillEnough",
  "noOrderNote": null
}
```

| Field | Type | Req. | Notes |
|---|---|---|---|
| `id` | string | ✔ | Client-generated idempotency key. |
| `checkInId` | string | ✔ **new** | The visit being closed. Falls back to "the open visit on `stopId`" if a legacy client omits it. |
| `stopId` | string | ✔ | Must match the check-in's stop, else `422 Visit.StopMismatch`. |
| `timestamp`, `latitude`, `longitude` | | ✔ | As api.md §7.4. |
| `durationMinutes` | int | ✔ | Device-computed. The server may recompute from the two timestamps. Store both if they differ. |
| `visitSummary` | string? | – | Free text. |
| `outcome` | `"withOrder"` \| `"withoutOrder"` | ✔ **new** | See §6 for older rows that have no outcome. |
| `orders` | array | when `withOrder`, ≥ 1 | **new**. See below. |
| `orders[].clientId` | string | ✔ | The quotation's **client-generated** id: always known, even offline. |
| `orders[].quotationId` | string? | – | The server's quotation id, if the app already has it. `null` when the order was taken offline and hasn't synced. |
| `noOrderReason` | string | when `withoutOrder` | **new**. A code from 4.4. |
| `noOrderNote` | string? | when reason is `other` | **new**. Max 500 chars. |

**How order links resolve:** the quotation and the check-out can arrive in
either order.
1. **Quotation already on the server:** link it now.
2. **Quotation not on the server yet:** store the link as **pending**. Resolve it
   when a quotation arrives with that `clientId` (see 4.7).
3. **Still pending after a time limit** (proposal: 72 h): mark it
   `orderMissing` for the supervisor report. **Do not reject the check-out.**

**Response 200** — `VisitDto` with `status: "checkedOut"` and the `checkOut`
block filled in (§5).

**Errors:**

| Status & code | When |
|---|---|
| `422 Visit.OutcomeRequired` | `outcome` missing on this endpoint. |
| `422 Visit.OrderRequired` | `withOrder` with an empty `orders` list. |
| `422 Visit.NoOrderReasonRequired` | `withoutOrder` with no reason, or `other` with no note. |
| `422 Visit.UnknownNoOrderReason` | A code not in 4.4. |
| `422 Visit.StopMismatch` | `checkInId` belongs to a different stop. |
| `200`, with the visit stored as `checkOutBeforeCheckIn` | The check-in hasn't arrived yet. **Accept and reconcile; don't refuse** (api.md §8.3). |
| `409 Visit.AlreadyCheckedOut` | A *different* check-out `id` for a visit that's already closed. Body carries the existing `VisitDto`. The same `id` again → 200. |
| `404 Visit.StopNotFound` | The stop isn't on the caller's routes. |

---

### 4.3 `GET /api/v1/mobile/visits/stops/{stopId}/visit`

Returns the latest visit on that stop for the caller, as a `VisitDto`. If there's
no visit yet: `200` with `"data": { "stopId": "...", "status": "pending",
"checkIn": null, "checkOut": null }`. Use 200 here, not 404, because "not
visited" is a normal answer.

The app calls it when opening a stop that is "checked in" on the phone, to
confirm the server agrees.

---

### 4.4 `GET /api/v1/mobile/visits/check-out-reasons`

The "without order" reasons, managed by the admin so sales ops can change them
without an app release. The app caches the list for offline use.

```json
{
  "data": [
    { "code": "stockStillEnough",   "nameEn": "Shop still has enough stock", "nameKm": "…", "requiresNote": false, "sort": 1 },
    { "code": "ownerNotAvailable",  "nameEn": "Owner / buyer not available", "nameKm": "…", "requiresNote": false, "sort": 2 },
    { "code": "priceTooHigh",       "nameEn": "Price too high",             "nameKm": "…", "requiresNote": false, "sort": 3 },
    { "code": "orderedByPhone",     "nameEn": "Will order by phone later",  "nameKm": "…", "requiresNote": false, "sort": 4 },
    { "code": "boughtFromCompetitor","nameEn": "Bought from a competitor",  "nameKm": "…", "requiresNote": true,  "sort": 5 },
    { "code": "other",              "nameEn": "Other",                      "nameKm": "…", "requiresNote": true,  "sort": 99 }
  ]
}
```

**The codes above are a proposal; sales ops must confirm them (Q1).**
- Codes are stable. Names can change.
- A retired code must still be **accepted** on old check-outs that arrive late
  through `/push`.
- `other` must always exist.

---

### 4.5 `POST /api/v1/mobile/visits/push` — change

`checkOuts[]` (api.md §7.4) gains the same new fields as 4.2: `checkInId`,
`outcome`, `orders`, `noOrderReason`, `noOrderNote`. `checkIns[]` gains
`routeId` and `photoIds`.

Validation follows api.md §6.1, so a bad row never fails the whole batch:

| Row problem | Bucket |
|---|---|
| Missing `outcome` (older app version) | **accepted**: store `outcome = "unknown"` (§6). |
| `withOrder` with no orders, or `withoutOrder` with no reason | **accepted**: store it and flag `incompleteOutcome`. The visit really happened; refusing it loses evidence. |
| Unknown reason code | **accepted**: keep the raw code and flag it. |
| Stop not on the caller's routes | **discarded**: `Visit.StopNotFound`, as today. |

> The online endpoint 4.2 is strict (422) because the rep is looking at the
> screen and can fix it. The batch is lenient because the rep may have
> captured that row days ago.

---

### 4.6 Route pull — each stop gains `visit`

`GET /visits/routes` and `/routes/delta` (api.md §5): each
`routes[].stops[]` gains a **`visit`** object, the same `VisitDto` as §5, or
`null` when the stop hasn't been visited.

This is what makes the app dynamic. After a reinstall, a phone switch or a
supervisor fix, the app shows the server's check-in/out state. Today it only
shows its own copy.

Stop `status` stays derived on the server from check-ins and check-outs, as
api.md OPEN-5 decided. There is still no field for the app to push a status.

---

### 4.7 `POST /api/v1/mobile/quotations` — change

Two optional fields are added so an order can be tied to the visit:

```json
{ "depotId": "…", "shipmentType": "Pickup", "shipTo": null,
  "clientId": "qt-local-5521", "stopId": "stop-1042" }
```

| Field | Notes |
|---|---|
| `clientId` | **new**. The client-generated quotation id. **Idempotency key**: the same `clientId` again returns the existing quotation (`200`, not `201`). It also resolves pending links from 4.2. |
| `stopId` | **new**, optional. Set when the order was taken during a visit. `null` for an off-visit order, which keeps its existing `offVisitReason`. |

---

## 5. `VisitDto`

| Field | Type | Notes |
|---|---|---|
| `visitId` | string | = the check-in `id`. |
| `stopId` | string | |
| `status` | `pending` \| `checkedIn` \| `checkedOut` \| `missed` | Uses the existing `VisitStatus` values. |
| `checkIn` | object? | `id`, `timestamp` (device), `receivedAt` (server), `geofence` (`inside` \| `outside` \| `unverifiable`), `flagged` (bool), `overrideReason?`, `photoIds[]` |
| `checkOut` | object? | `id`, `timestamp`, `receivedAt`, `durationMinutes`, `outcome` (`withOrder` \| `withoutOrder` \| `unknown`), `orders[]` (`clientId`, `quotationId?`, `linkStatus`: `linked` \| `pending` \| `orderMissing`), `noOrderReason?`, `noOrderNote?`, `departureInferred` (bool) |
| `updatedAt` | ISO-8601 | Server time of the last change, for the delta pull. |

`departureInferred` is the existing flag (api.md §5.1) for a stop closed by the
end-of-day sweep. Its `outcome` is `unknown`.

---

## 6. Older app versions

Builds released before this change send check-outs with no `outcome`,
`checkInId` or `orders`. These must keep working:

- Store `outcome = "unknown"`. Reports show these as "not recorded", not as
  "no order".
- Missing `checkInId`: attach the check-out to the open visit on that `stopId`.
- Don't make `outcome` required on `/push` until every installed app version
  sends it.

---

## 7. Offline scenario the server must handle

A rep works 5 stops with no signal, then reconnects. The app already sends in
this order (one request per step):

1. `/push` with **all 5 check-ins**, oldest first.
2. Every queued quotation (`POST /quotations` …), each with `clientId` + `stopId`.
3. `/push` with **all 5 check-outs**, oldest first, each with `outcome`.

Expected server state afterwards:

| Stop | Check-in | Check-out | Outcome | Order links |
|---|---|---|---|---|
| 1 | stored | stored | withOrder | `linked` (quotation arrived in step 2) |
| 2 | stored | stored | withoutOrder / `stockStillEnough` | – |
| 3 | stored | stored | withOrder | `pending` → `linked` once the late quotation arrives |
| 4, 5 | stored | stored | … | … |

Repeating any of the three steps changes nothing (idempotency). If step 1 partly
fails, the app holds that stop's check-out until its check-in is accepted. The
server must still tolerate the reverse order, because older apps don't do this.

---

## 8. Open questions — need an answer before build

Recommendations and reasoning for Q1, Q2, Q4 and Q7:
[README.md — Check-out with or without order](README.md#check-out-with-or-without-order--open-decisions).

| # | Question | Proposed answer |
|---|---|---|
| Q1 | Final list of "no order" reasons and Khmer names? | §4.4 list. Sales ops to confirm. |
| Q2 | Can a rep visit the same stop twice in one day? | No. A second check-in returns `409 Visit.AlreadyCompleted`; use an ad hoc visit for a return trip. |
| Q3 | Server reaction to a check-in while another stop is still open? | Accept it. Auto-close the old visit with `departureInferred = true`, `outcome = unknown`, and flag it. Never refuse; the app already blocks this. |
| Q4 | Does a **draft** (not submitted) quotation count as "with order"? | No. Only a submitted quotation (including one queued offline) counts; a bare draft does not. Keep every linked quotation with its own status, and report conversion by final status. |
| Q5 | Time limit before a pending order link becomes `orderMissing`? | 72 h. |
| Q6 | Must the check-out position be inside the geofence? | No. Store `distanceFromDepot` on check-out as evidence, like check-in (would add one optional field). |
| Q7 | Sales orders have no API today, only quotations. Will sales orders get one, and should `orders[]` accept them too? | Add `orders[].type` (`quotation` \| `salesOrder`) now, defaulting to `quotation`. |

---

## 9. Backend acceptance checklist

- [ ] 4.1 and 4.2 return the same `VisitDto` whether the record arrived there
      or through `/push`.
- [ ] Re-posting any check-in, check-out or quotation (same id / `clientId`)
      returns success and creates nothing new.
- [ ] Check-out before check-in, and check-out before its quotation, both end
      in a correct, linked visit.
- [ ] `withOrder` without orders and `withoutOrder` without a reason: `422` on
      4.2, accepted and flagged on `/push`.
- [ ] Check-outs with no `outcome` (older apps) are stored as `unknown`.
- [ ] Route pull returns `stops[].visit` matching 4.3.
- [ ] A stop belonging to another rep is refused on every endpoint.
- [ ] Mocked or no-GPS check-ins are stored and flagged, never refused.
- [ ] Device time and receipt time are both stored; device time is never overwritten.

---

## 10. Mobile work once this ships (for planning)

1. Call 4.1 / 4.2 when online, and show the server's verdict. Offline, keep
   queueing through `/push`; that already works and sends in order.
2. Check-out screen: two choices, **"Check out with order"** (pick the
   quotations taken at this stop, pre-selected) and **"Check out without
   order"** (reason list from 4.4, cached).
3. Send `clientId` + `stopId` when creating a quotation during a visit.
4. Read `stops[].visit` from the route pull, and let the server state replace
   the local copy once the local rows are sent.
5. Add `outcome`, `checkInId`, `orders`, `noOrderReason` and `noOrderNote` to
   the local check-out table. This is a Drift migration.
