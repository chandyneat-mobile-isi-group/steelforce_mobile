# My Visits — Backend API Specification

> **Status:** **implemented.** No longer a proposal — as of 2026-09-08 all five
> endpoints are live, and every item that was marked **OPEN** has been decided
> (§10). Where this document and the running API disagree, the API is right and
> this document is a bug; report it.
> **Audience:** engineers implementing the route/visit endpoints in the ISI API.
> **Source of truth:** this document is *derived from the shipped Flutter client*
> — the interfaces in `lib/features/my_visits/data/remote/` and the DTOs in
> `lib/features/my_visits/data/models/`. Where the client already parses a
> field, that field's name and type are a hard requirement, not a suggestion.
> Anything marked **OPEN** is a decision the backend team still needs to make.

---

## 1. What this feature is

A field sales rep is given a **route** for the day: an ordered list of **stops**,
each at a depot or depot. At each stop the rep checks in (location-verified),
performs work — a stock count, a quotation, notes, photos, a cash collection —
and checks out. The app then syncs everything.

The single most important property: **the rep works with no connectivity for
hours at a time.** Every action is written to the device first and succeeds
locally. Sync is opportunistic and must never be required for the rep to keep
working. Every decision below follows from that.

---

## 2. Conventions

These match the endpoints the app already consumes (auth, catalog); the visit
endpoints must not diverge.

| | |
|---|---|
| Base URL | `https://www.pnc-spts-stg-api.me` (staging) |
| Prefix | `/api/v1` |
| Auth | `Authorization: Bearer <access_token>` |
| Content type | `application/json; charset=utf-8` |
| Correlation | Echo `X-Correlation-Id`; expose it via `Access-Control-Expose-Headers` |
| Timestamps | ISO-8601 **with offset**, e.g. `2026-08-20T09:15:00+07:00` |
| Enums | Sent and received as the exact strings in §4 — never integers |

### 2.1 Success envelope

Wrapped, as elsewhere in the API (`ApiEnvelope.fromBody`):

```json
{ "data": { }, "message": null, "metadata": { } }
```

The deployed envelope also carries `success`, `traceId` and `timestamp` alongside
these. Read `data` and ignore the rest; the extra keys are additive and are not
part of what a client must parse.

### 2.2 Errors

RFC 7807 `application/problem+json`, matching the auth endpoints:

```json
{
  "type": "https://docs.isigroup.com.kh/errors/Visit.StopNotFound",
  "title": "Not found.",
  "status": 404,
  "detail": "Stop 'stop-91' is not on a route assigned to this rep.",
  "instance": "/api/v1/mobile/visits/push",
  "errorCode": "Visit.StopNotFound",
  "correlationId": "0HNNSTRGHBJR4:00000001"
}
```

---

## 3. The offline-first contract

Three rules the backend must honour. They are not negotiable client-side —
the app is already built this way.

**3.1 — The client generates all row ids.** Every captured row (check-in,
note, photo, order line…) is created offline with a client-side unique id. The
backend must accept that id as the primary key, not mint its own. There is no
moment at which the client can wait for a server id.

**3.2 — Every write is idempotent on that id.** A rep in a tunnel will retry.
The same batch may arrive twice. Re-posting a row the server already holds must
return success, not a duplicate-key error and not a second row.

**3.3 — Push is partially acceptable.** One bad row must not reject a day's
work. The push endpoint returns *which ids it took and which it refused*; the
client keeps refused rows pending and retries them. A 4xx for the whole batch
because one photo was malformed would strand every other capture on the device.

---

## 4. Vocabularies

Exact strings. The client parses unknown values to a documented fallback rather
than failing, but sending anything outside these sets is a bug.

| Enum | Values | Fallback on unknown |
|---|---|---|
| `RouteStatus` | `planned`, `published`, `inProgress`, `completed` | `published` |
| `VisitStatus` | `pending`, `enRoute`, `arrived`, `checkedIn`, `checkedOut`, `missed` | `pending` |
| `TerritoryType` | `urban`, `suburban`, `industrial`, … | first value |
| `StockLevel` | `low`, `medium`, `high` | `low` |
| `CollectionMethod` | `cash`, `check`, `bankTransfer` | — |
| `VisitNoteType` | `general`, `competitorActivity`, `survey` | — |
| `FraudFlagType` | `mockLocation`, `impossibleSpeed`, `poorAccuracy`, `vpnDetected` | `unknown`, **stored** — see §6.3 |

---

## 5. Pull — getting the rep their routes

Scope is always **the signed-in rep**: `repId` + `territory`. The server must
derive `repId` from the bearer token and must never return another rep's routes
even if the client asks.

### 5.1 `GET /api/v1/mobile/visits/routes`

Initial (full) sync. Paginated, because a first install pulls history.

| Query | Type | Notes |
|---|---|---|
| `territory` | string | From the rep's assignment |
| `page` | int | 1-based |
| `pageSize` | int | Client default 200; cap server-side |

```json
{
  "data": {
    "depots": [ /* DepotStopInfo, §7.1 */ ],
    "routes":    [ /* RoutePlan with nested stops, §7.2 */ ],
    "hasMore": false
  }
}
```

`depots` is a flat, de-duplicated list; each stop joins to it by
`depotId`. A depot appearing on three stops is sent **once**.

The client reads only `depots`, `routes` and `hasMore` from this body.
`generatedAt` and `territories` are also present at the top level.

**`generatedAt` is now the authoritative sync watermark** — the server clock when
the page was read. Store it and send it back as `since` on the delta pull (§5.2);
it is no longer optional to adopt. `territories` lists every territory on the page
and remains ignored by the client.

Two fields here are **additive to the original contract** and worth knowing:

- **`depots[].hasLocation`** — false when the depot has no recorded pin. The
  client cannot otherwise tell a genuine pin at `(0, 0)` from a missing one, and a
  check-in against a missing pin is recorded as *unverifiable* rather than as a
  failure.
- **`routes[].stops[].departureInferred`** — true when the stop was closed by the
  end-of-day sweep rather than by a real check-out, so `actualDeparture` is the
  planned time rather than an observed one. The visit still counts; the duration is
  a guess. A client that ignores this sees an ordinary `checkedOut`, which is
  correct.

### 5.2 `GET /api/v1/mobile/visits/routes/delta`

| Query | Type | Notes |
|---|---|---|
| `territory` | string | |
| `since` | ISO-8601 | Client's last successful sync watermark |

Same body shape. Note the client deliberately treats this as a **full re-pull of
the rep's current scoped set**, not an incremental diff — a rep has a handful of
routes per day, so the simplicity is worth more than the bytes saved. The
`since` parameter exists so the server *may* short-circuit with an empty page
when nothing changed.

Returning the complete current set every time is acceptable and expected.

> **⚠️ `since` must be the server's `generatedAt`, not the device clock.** A
> watermark more than five minutes in the future is now **rejected with a 400**.
> Left alone, a phone running fast would ask for changes since the future, receive
> an empty delta, store that timestamp and silently never sync again — a permanent
> failure that looks like success. Failing loudly on the first request is strictly
> better. `generatedAt` is on every response for exactly this purpose.

---

## 6. Push — sending captured work back

### 6.1 `POST /api/v1/mobile/visits/push`

**One request carries every pending row of every kind.** The client batches
because a rep coming back into signal should drain the whole device in one
round trip, not eight.

```json
{
  "checkIns":     [ /* §7.3 */ ],
  "checkOuts":    [ /* §7.4 */ ],
  "orderLines":   [ /* §7.5 */ ],
  "stockUpdates": [ /* §7.6 */ ],
  "returns":      [ /* §7.7 */ ],
  "collections":  [ /* §7.8 */ ],
  "notes":        [ /* §7.9 */ ],
  "photos":       [ /* §7.10 */ ]
}
```

Any list may be empty; the client does not send the request at all when every
list is empty.

**Response — 200, always, when the request itself was well-formed:**

```json
{
  "data": {
    "acceptedIds": ["ci-8f2…", "note-11c…"],
    "rejectedIds": ["photo-77a…"],
    "discardedIds": ["ci-bad-1"],
    "discarded": [
      {
        "id": "ci-bad-1",
        "errorCode": "Visit.StopNotFound",
        "reason": "This stop is not on a route assigned to you."
      }
    ],
    "syncedAt": "2026-08-20T09:41:02+07:00"
  }
}
```

- `acceptedIds` — durably stored. The client marks these synced and will not
  send them again. **A re-pushed row the server already holds is accepted**, not
  refused — from the device's point of view the outcome is identical, and saying
  otherwise would make it retry a row we already have.
- `rejectedIds` — **kept pending on the device and retried later.** Transient
  failures only.
- `discardedIds` — **permanently invalid. Stop sending them.** This is the
  resolution of OPEN-2. Every id here has an entry in `discarded` giving a stable
  `errorCode` and a developer-facing `reason` — log it, don't show it to a rep.
  A stop that is not the caller's, a blank id, a collection naming a payment
  method that does not exist.
- Ids the client sent that appear in none of the three are treated as rejected.

`discardedIds` is **additive and safe to ignore**: a client that does not read it
treats those ids as absent from both lists, which it already handles by retrying.
Nothing gets worse — and the moment the client does read it, permanently bad rows
stop cycling forever.

The bar for discarding rather than storing is deliberately high, because a capture
is evidence of fieldwork. A check-in with a mocked location is **stored and
flagged**; a check-in with no GPS fix at all is **stored as unverifiable**. What
gets discarded is what could not be attached to anything, or what would be a lie
if stored.

**Batch cap (OPEN-3): 5,000 rows** across every list, with request bytes bounded
separately at 32 MB. Set far above the documented worst case — "hundreds of rows"
after a full day offline — precisely because chunking is not implemented
client-side: a cap a rep could hit in normal use would strand their day
permanently. Exceeding it is a `400 Visit.PushBatchTooLarge`.

Reject the whole request (4xx) only when the *envelope* is unusable — malformed
JSON, bad auth, or more rows than one push may carry. Never because of an
individual row.

### 6.2 `POST /api/v1/mobile/visits/photos`

The binary half of a photo capture, which cannot travel inside the JSON batch.
The resolution of **OPEN-1**: multipart, not pre-signed URLs.

`Content-Type: multipart/form-data`, carrying the image plus these form fields:

| Field | Type | Notes |
|---|---|---|
| `id` | string | **The same id the batch carries for this photo.** This is how the two halves meet |
| `stopId` | string | The stop it was taken at |
| `takenAt` | ISO-8601? | Device clock at capture |
| `caption` | string? | |
| `isSignature` | bool | True for a signature rather than a photograph |

| | |
|---|---|
| Max size | **15 MB** |
| Accepted types | **JPEG, PNG, WebP, HEIC** |

```json
{
  "data": {
    "id": "photo-77a…",
    "url": "https://…",
    "uploadedAt": "2026-08-20T09:41:02+07:00"
  }
}
```

`url` is **time-limited** — the stored form is a storage key and a fresh URL is
minted on each read, so do not treat it as a permanent address.

**Unlike the batch, this answers 4xx on failure.** It carries one thing, and the
client needs to know whether to send those bytes again. Errors:
`Visit.PhotoFileRequired`, `Visit.PhotoContentTypeUnsupported`,
`Visit.PhotoTooLarge` (400), `Visit.StopNotFound` (404),
`Visit.PhotoStorageFailed` (502).

**Client flow:** upload first, rewrite the row's `url` with what came back, then
push. **Order does not matter** — a photo row pushed before its bytes is accepted
and records that the photo exists, and a later push carrying the caption the rep
typed updates that row rather than duplicating it.

### 6.3 `POST /api/v1/mobile/visits/telemetry`

The resolution of **OPEN-4**. Its own endpoint rather than two more lists on
`/push`, and the reason is throughput, not shape: a day's captures are tens of
rows and a day's breadcrumbs are thousands, so sharing one request would mean a
rep's check-ins could not reach the server until their entire GPS trail had been
accepted with them. Two endpoints let the small, urgent payload drain first.

```json
{
  "locationSamples": [ /* §7.11 */ ],
  "fraudFlags":     [ /* §7.12 */ ]
}
```

**Response is exactly `/push`'s** — `acceptedIds`, `rejectedIds`, `discardedIds`,
`discarded`, `syncedAt` — so the client's sync engine needs no second set of
rules. Same idempotency on the client's own ids. Either list may be empty or
absent.

**Rows are scoped to a `routeId`, not a `stopId`.** Most of this is recorded while
the rep is riding between depots, where there is no stop to attribute it to.
The route must be one assigned to the caller. A fraud flag *may* name a `stopId`,
but it must be a stop on the route it also names — otherwise the two identifiers
contradict each other and there is no fact to store.

| | |
|---|---|
| **Per-request cap** | **10,000 rows** across both lists. Over that: `400 Visit.TelemetryBatchTooLarge` |
| **Chunking** | **Required client-side.** Unlike OPEN-3 this is a cap an honest device *will* hit — a weekend offline is tens of thousands of rows |
| **Sampling** | **≥ 15 s between fixes, and ≥ 25 m of movement.** A handset parked in a shop for forty minutes should record one fix, not 160 |

Per-row discards specific to this endpoint:

| Code | Meaning |
|---|---|
| `Visit.Telemetry.RouteIdMalformed` | `routeId` is not a valid identifier |
| `Visit.RouteNotFound` | The route is not assigned to you. Deliberately does not distinguish "does not exist" from "belongs to someone else" — confirming an id is real would make this an enumeration oracle |
| `Visit.Telemetry.StopNotOnNamedRoute` | The flag's `stopId` is not on the route it names |
| `Visit.Telemetry.FixUnusable` | The sample carries no usable position — out of range, non-finite, or `(0, 0)`, which is what a handset reports when the fix failed. A position is the *entire* content of a location sample, so unlike a check-in there is nothing left to keep once it is gone |

**Nothing here is treated as a finding.** `isMocked` and every reported flag are
claims by the device — the same component that would be compromised first if the
rep were faking their day — so they are stored as testimony and are never a reason
to refuse a row.

---

## 7. Payload reference

Field names are exactly what the client reads. `?` marks nullable.

### 7.1 DepotStopInfo

| Field | Type | Notes |
|---|---|---|
| `id` | string | Referenced by stops |
| `name` | string | |
| `nameKh` | string? | `""` when absent — the documented "no Khmer name" value |
| `code` | string | Depot code |
| `contact` | string | Contact person |
| `phone` | string | |
| `address` | string | |
| `territory` | string | |
| `territoryType` | enum | §4 |
| `latitude` | number | Used for geofence verification |
| `longitude` | number | |
| `geofenceRadiusOverride` | number? | Metres; falls back to the app default |

### 7.2 RoutePlan

| Field | Type |
|---|---|
| `id`, `name`, `repId`, `repName`, `territory` | string |
| `visitDate`, `plannedStart`, `plannedEnd` | ISO-8601 |
| `status` | `RouteStatus` |
| `stops` | array of RouteStop |

**RouteStop**

| Field | Type | Notes |
|---|---|---|
| `id`, `routeId` | string | |
| `depotId` | string | Joins to §7.1 |
| `sequence` | int | Visit order |
| `plannedArrival`, `plannedDeparture` | ISO-8601 | |
| `status` | `VisitStatus` | **Send the real execution state.** Hardcoding `pending` makes the dashboard read 0% complete regardless of data — this was a real client bug. |
| `actualArrival`, `actualDeparture` | ISO-8601? | Null until it happens |

### 7.3 CheckIn

| Field | Type | Notes |
|---|---|---|
| `id`, `stopId` | string | |
| `timestamp` | ISO-8601 | |
| `latitude`, `longitude` | number | Where the rep actually was |
| `accuracy` | number | GPS accuracy, metres |
| `distanceFromDepot` | number | Metres from the depot pin — the geofence evidence |
| `isMocked` | bool | Device reported a mock location provider |

### 7.4 CheckOut

`id`, `stopId`, `timestamp`, `latitude`, `longitude`, `durationMinutes` (int),
`visitSummary` (string?).

### 7.5 OrderLine
`id`, `stopId`, `productId`, `productName`, `quantity` (number), `unit`, `unitPrice` (number).

### 7.6 StockUpdate
`id`, `stopId`, `depotId`, `productId`, `productName`, `stockLevel` (`StockLevel`), `notes` (string?).

### 7.7 Return
`id`, `stopId`, `productId`, `productName`, `quantity` (number), `reason`.

### 7.8 Collection
`id`, `stopId`, `amount` (number), `method` (`CollectionMethod`), `reference` (string?), `notes` (string?).

### 7.9 Note
`id`, `stopId`, `type` (`VisitNoteType`), `text`, `createdAt`.

### 7.10 Photo
`id`, `stopId`, `url`, `caption` (string?), `takenAt`, `isSignature` (bool).

On the first push `url` is a *device-local* path, and the row is accepted anyway —
it records that the photo exists. The bytes follow through §6.2, which meets this
record on its `id`.

### 7.11 LocationSample

| Field | Type | Notes |
|---|---|---|
| `id` | string | Device-generated |
| `routeId` | string | The route that was running. **Not a `stopId`** |
| `latitude`, `longitude` | number | `(0, 0)` is treated as a failed fix and discarded |
| `accuracyMeters` | number | Radius of uncertainty. A negative value is clamped to 0 |
| `speedMps` | number? | **Send `null`, not `0`,** when the device has none — `0` reads as a measured standstill |
| `headingDegrees` | number? | Same. A stationary fix has no heading |
| `altitudeMeters` | number? | Same. An indoor fix often has none |
| `timestamp` | ISO-8601 | Device clock |
| `isMocked` | bool | Stored as reported, never acted on |

### 7.12 FraudFlag

| Field | Type | Notes |
|---|---|---|
| `id` | string | Device-generated |
| `routeId` | string | The route that was running |
| `stopId` | string? | Null for a flag raised between stops — where most are raised. When present, must be on `routeId` |
| `type` | `FraudFlagType` | An unrecognised value is **stored** under `unknown` with the raw string preserved, not refused: a flag is compliance evidence, and a newer client raising a new condition must not have it silently dropped |
| `detail` | string | The detector's own words. Truncated at 1,000 chars rather than refused — a verbose detector is not a lie |
| `timestamp` | ISO-8601 | Device clock |
| `blocked` | bool | Whether the client actually **stopped the rep from acting**, as opposed to only recording a suspicion. The most operationally useful field here: the first is a support call waiting to happen, the second is a compliance queue item, and only the device knows which it was |

---

## 8. Validation the backend owns

The client cannot enforce these; it is offline when the data is made.

1. **Stop ownership** — every `stopId` must belong to a route assigned to the
   authenticated rep. Reject cross-rep writes.
2. **Geofence** — `distanceFromDepot` and `isMocked` are *evidence submitted
   by the device*, not a verdict. The server decides whether a visit counts.
   Treat `isMocked: true` as a fraud signal, not a hard reject: the row still
   needs storing so it can be investigated.
3. **Ordering** — a check-out may arrive before its check-in if the batch was
   assembled oddly. Accept both and reconcile by `timestamp`, rather than
   rejecting on arrival order.
4. **Clock skew** — device clocks are wrong. Store the client timestamp *and*
   a server receipt time; never overwrite the client's.

---

## 9. Non-functional

- **Batch size** — **defined (OPEN-3): 5,000 rows per push** (§6.1), **10,000 per
  telemetry request** (§6.3). The push cap is set above anything an honest device
  will reach, because the client does not chunk; the telemetry cap is one the
  client *must* chunk against.
- **Latency** — the push runs in the background; a slow response is fine, a
  timeout that loses the accepted/rejected split is not. Measured: a full
  10,000-row telemetry chunk stores in ~1.1 s.
- **Retries** — the client retries the whole batch. Idempotency (§3.2) is what
  makes that safe, and it is cheap: the duplicate check runs before any row is
  constructed, so a re-pushed 10,000-row chunk answers in ~0.1 s and inserts
  nothing.
- **CORS** — the Flutter *web* build calls these endpoints from a browser. Any
  deployed origin must be on the API's allowlist, or every request fails before
  it leaves the browser and surfaces to the client as a network error rather
  than a policy rejection.

---

## 10. Open questions — **all resolved**

Kept in full rather than deleted: the reasoning is why the endpoints are shaped
the way they are, and three of these still imply client work.

**OPEN-1 — Photo upload. ✅ RESOLVED: multipart.** Spec in §6.2. Pre-signed URLs
were rejected as more moving parts for no gain at this volume. → **Client work:**
upload, rewrite `url`, then push.

**OPEN-2 — Permanent rejection. ✅ RESOLVED: `discardedIds` added,** with a
`discarded` array carrying an `errorCode` and `reason` per row. See §6.1. Additive
and safe to deploy ahead of the client. → **Client work:** read it, and stop
resending those ids.

**OPEN-3 — Batch limits. ✅ RESOLVED: 5,000 rows per push,** 32 MB per request.
Set far above the documented worst case *because* chunking is unimplemented
client-side — a cap a rep could hit in normal use would strand their day
permanently. Note this is the opposite trade from the telemetry cap in §6.3, where
chunking is mandatory; the difference is that no single number is both above a
weekend's GPS trail and processable in one request.

**OPEN-4 — Fraud flags and location samples. ✅ RESOLVED: their own endpoint,**
§6.3. Not extra lists on `/push`, so a rep's check-ins never queue behind their
GPS trail. → **Client work:** wire it, and chunk.

**OPEN-5 — Route write-back. ✅ RESOLVED: derived server-side,** as recommended.
Stop and route status come from the check-ins and check-outs already pushed, so
there is deliberately **no field to push a status in**. One source of truth, and
what the client already assumes. Stops carry their real execution state — a
hardcoded `pending` was the shipped client bug this document called out, and the
server does not reproduce it.

`enRoute` and `arrived` remain in the vocabulary because the client models them,
but nothing in the push contract carries the evidence for either, so the server
never assigns them. They are kept rather than dropped: removing a value the client
parses would be a breaking change for no gain.

**OPEN-6 — Territory. ✅ RESOLVED both sides.** `RouteSyncScope` now reads the
rep's `territoryCode` from the auth profile (`GET /auth/me`), which does carry
it — e.g. `PP-NORTH`. The former hardcoded `"Phnom Penh"` matched only the
retired fixture data. Server side: `territory` is a **filter, never a scope** — passing another rep's
territory narrows the result and can never widen it, and scope always comes from
the bearer token. When the profile carries no territory the request fails with
`Visit.TerritoryNotAssigned` rather than falling back to "all routes", which would
hand a rep someone else's day.

---

## 11. Build order — **server side complete**

All five steps are done: `GET /routes`, `POST /push` (all eight lists), photos
(OPEN-1), delta sync, and telemetry (OPEN-4).

**Remaining work is client-side**, most valuable first:

1. **Echo `generatedAt` as `since`** on the delta pull — it is now a 400 to send a
   future watermark (§5.2).
2. **Photo upload** (§6.2) — the one that unblocks *evidence*. Check-in requires a
   shopfront proof photo, and none of it reaches the server today.
3. **Read `discardedIds`** (§6.1) — small change, stops permanently bad rows
   retrying forever.
4. **Wire the telemetry push** (§6.3), with chunking.
5. **Mount the four unmounted capture forms** — order lines, stock updates,
   returns, collections. The endpoint has accepted all four since day one; nothing
   arrives until a screen fills them. See backend-integration.md §6.

The client now calls these endpoints for real: `ApiRouteRemoteDataSource` and
`ApiVisitSyncRemoteDataSource` are the only implementations of the two
interfaces above. The bundled fixture sources they replaced have been removed,
so there is no longer a mock path that can make a missing or misbehaving
endpoint look healthy — the app shows what the API returns, or shows the
failure. Tests script the HTTP transport instead of substituting a fake feed.
