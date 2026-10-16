# My Visits — Backend Integration Guide

> **Audience:** backend engineers building the API this feature runs on.
> **Purpose:** what My Visits actually does, which parts need a backend, how
> many endpoints that is, and what is still missing.
> **Code:** `lib/features/my_visits/`
> **Verified:** 2026-09-08 against branch `web`.
> **Backend status:** 2026-09-08 — **all five endpoints are implemented and
> deployed.** This document was written when three were. Every ❌ it used to carry
> is now resolved, and the remaining gaps are client-side (§6). Sections 5 and 7
> record what the backend chose, so the client work is unambiguous.

**This is the map. [api.md](api.md) is the territory.** That document is the
field-by-field specification for the three endpoints that already exist —
payloads, envelopes, vocabularies, validation rules. Do not re-derive any of
that here; it is deliberately not repeated so the two cannot drift apart.

Read this first to know *what to build and in what order*, then api.md to know
*exactly what each request and response looks like*.

---

## 1. The one property everything follows from

A rep is given a **route** for the day: an ordered list of **stops**, each at a
depot or depot. At each stop they check in (location-verified), do work, and
check out.

**The rep works with no connectivity for hours at a time.** Every action is
written to the device first and succeeds locally. Sync is opportunistic and
never on the critical path. If your API is down, the rep keeps working and the
data drains later — that is the design, not a degraded mode.

---

## 2. Feature inventory

Eleven capabilities live in this feature. **Seven touch the backend, and all
seven now have an endpoint.** The other four are local reads, an external maps
hand-off, and one thing that is device-only by design.

The last column is the one worth reading carefully: **several capabilities are
built end-to-end but have no UI wired to them today**, so the data never
arrives. See §6.

| # | Capability | What it does | Backend | Produces data today? |
|---|---|---|---|---|
| 1 | **Route sync (pull)** | Downloads the rep's routes, stops, and the depots they sit at | ✅ Endpoints 1 & 2 | ✅ Yes |
| 2 | **Stop dashboard** | Today's stops, nearest-first by live GPS; multi-day calendar | — Local read | n/a |
| 3 | **Stop information** | One stop's detail: contact, address, distance, actions | — Local read | n/a |
| 4 | **Navigate to stop** | Hands off to Google/Apple Maps | — None | n/a |
| 5 | **Geofenced check-in** | Verifies the rep is inside the shop radius, captures a proof photo, stamps time + position | ⬆️ Endpoint 3 | ✅ Yes |
| 6 | **Check-out** | Closes the visit, records duration | ⬆️ Endpoint 3 | ✅ Yes |
| 7 | **Notes & photos** | Free-text notes and proof photos — reached today via the *skip stop* flow | ⬆️ Endpoints 3 & 4 | ⚠️ Notes yes; photos **now have an endpoint** but need the client upload step (§5.1) |
| 8 | **Order lines / stock / returns / collections** | The four capture forms | ⬆️ Endpoint 3 | ❌ **No UI mounted** (§6) |
| 9 | **Depot stock count** | Standalone shelf audit from the Home quick action | ⬆️ Endpoint 3 | ❌ **Renders mock data** (§6) |
| 10 | **Location tracking + fraud detection** | GPS breadcrumb and mock-location / speed / accuracy / VPN flags | ⬆️ Endpoint 5 | ❌ **Client not wired yet** — endpoint is live, nothing calls it (§5.2) |
| 11 | **Resume / Continue Working** | Restores the exact screen after a crash or force-close | — Device-only **by design** (§4) | n/a |

---

## 3. Endpoint count: **5 total — all 5 implemented**

| # | Endpoint | Method | Server | Client |
|---|---|---|---|---|
| 1 | `/api/v1/mobile/visits/routes` | `GET` | ✅ Live — api.md §5.1 | ✅ Implemented |
| 2 | `/api/v1/mobile/visits/routes/delta` | `GET` | ✅ Live — api.md §5.2 | ✅ Implemented — **but see the `since` note below** |
| 3 | `/api/v1/mobile/visits/push` | `POST` | ✅ Live — api.md §6.1 | ✅ Implemented |
| 4 | `/api/v1/mobile/visits/photos` | `POST` | ✅ Live — api.md §6.2, multipart | ⬜ Needs the upload-then-push step (§5.1) |
| 5 | `/api/v1/mobile/visits/telemetry` | `POST` | ✅ Live — api.md §6.3 | ⬜ Not wired at all (§5.2) |

Endpoints 1–3 are what a rep needs to receive a route, check in, check out and
have that reach you, and both halves of those are done. Endpoints 4 and 5 are
what make the *evidence* — proof photos and the GPS trail — reach you as well,
and they are now waiting on client work rather than on us.

> **⚠️ One behaviour change on endpoint 2.** `since` is now **rejected with a 400
> if it is in the future** (beyond five minutes of clock-skew allowance). Send back
> the `generatedAt` from the previous response, never the device clock. A handset
> running fast used to ask for changes since the future, receive an empty delta,
> store that watermark and then silently never sync again; failing loudly on the
> first request is strictly better than that. Any client that already echoes
> `generatedAt` needs no change.

A sixth, a visit-history read, is **not required**: history screens exist in the
codebase but are wired to nothing. Do not build it until that UI is connected.

### Dependencies owned by other teams

The feature does not function without these. They are not yours to build here,
but route sync fails hard if they are wrong.

| Requirement | Why it matters |
|---|---|
| `GET /api/v1/mobile/depots` | **Hard prerequisite.** `route_stops.depot_id` is a live foreign key into the depot directory and route sync may never invent a depot (ADR-001). With an empty directory the whole route transaction aborts — not just the affected stop — and every Visit screen comes up blank. Depot sync must land before route sync. |
| `GET /auth/me` returning `territoryCode` | The route pull filters by territory (e.g. `PP-NORTH`). The client reads it from the auth profile. When it is absent the client omits the query parameter entirely and expects you to scope from the bearer token alone. |
| Product catalog | Stock counts and order lines name real SKUs. |

---

## 4. What the backend owns — and what it must not do

api.md §8 has the full list. The four that get missed most often:

1. **Stop ownership.** Every `stopId` must belong to a route assigned to the
   authenticated rep. The client does not send `repId` at all — deliberately,
   so nobody is tempted to trust it. Derive the rep from the token.
2. **The geofence verdict is yours.** `distanceFromDepot` and `isMocked` are
   *evidence submitted by a device*, not a decision.
3. **Accept out-of-order arrivals.** A check-out can reach you before its
   check-in if the batch was assembled oddly. Reconcile by `timestamp`.
4. **Store both clocks.** Keep the client timestamp *and* a server receipt time.
   Never overwrite the client's.

**Do not:**

- Reject a row because `isMocked` is `true`. That row is precisely the one worth
  investigating — store it and flag it.
- Hardcode `status: "pending"` on stops. Send the real execution state;
  hardcoding it made the dashboard read 0% complete regardless of the data, and
  that was a real production bug.
- Mint your own row ids. The client generates them offline (api.md §3.1).

### Explicitly device-only — do not build an endpoint for this

**Resume / Continue Working** (`ActiveWorkflow`) is navigation state: which
screen the rep was on and the arguments to rebuild it. At most one row exists
and it is meaningless anywhere else. Syncing it would mean restoring one rep's
half-finished visit onto a colleague's handset.

---

## 5. The two endpoints that were missing — now shipped

### 5.1 `POST /api/v1/mobile/visits/photos` — **built. Option A (multipart).**

`VisitPhoto.url` is a path on the *device*
(`/data/user/0/com.isi.app/cache/photo.jpg`). Binary cannot travel inside the
JSON batch and there is no upload endpoint, so the client sends
`"photos": []` **on every push** and holds each photo pending indefinitely.

That is deliberate. Sending the local path instead would have you accept the
row, the client mark it synced, and the image vanish the moment the app sandbox
is cleared — silent data loss that looks like success.

**The cost:** check-in requires a shopfront proof photo. It is the evidence the
visit happened. None of it reaches you today.

**Decision: Option A, multipart.** Pre-signed URLs were rejected as more moving
parts for no gain at this volume.

| | |
|---|---|
| Endpoint | `POST /api/v1/mobile/visits/photos` |
| Encoding | `multipart/form-data` — the file plus form fields `id`, `stopId`, `takenAt`, `caption`, `isSignature` |
| Max size | **15 MB** |
| Accepted types | **JPEG, PNG, WebP, HEIC** |
| Response | `200` with `{ id, url, uploadedAt }`. The `url` is time-limited — a fresh one is minted per read, so **do not persist it as permanent** |
| Failure | **4xx, unlike the batch.** This request carries one thing, so the client needs to know whether to send those bytes again |

**The client change, unchanged from the original plan:** upload first, rewrite
`url` with what came back, then include the row in the next push.

The two halves meet on the client's `id` and **either may arrive first** — a photo
row pushed before its bytes is accepted and simply records that the photo exists,
and a re-push carrying the caption the rep typed afterwards updates the existing
row rather than duplicating it.

### 5.2 `POST /api/v1/mobile/visits/telemetry` — **built. Field spec in api.md §6.3.**

Two compliance-relevant datasets are captured on every route and never leave the
device.

**Location samples** — a GPS breadcrumb recorded continuously while a route is
active. Fields: `id`, `routeId`, `latitude`, `longitude`, `accuracyMeters`,
`speedMps`, `headingDegrees`, `altitudeMeters`, `timestamp` (ISO-8601),
`isMocked` (bool).

**Fraud flags** — raised by the on-device detector. Fields: `id`, `routeId`,
`stopId?`, `type` (`FraudFlagType`, api.md §4), `detail` (string), `timestamp`,
`blocked` (bool — whether the client actually stopped the action).

Same accepted/rejected/discarded id contract as `/push`, and the same idempotency
on the client's own ids. **Rows are attributed to a `routeId`, not a `stopId`** —
most of this is recorded while the rep is riding between depots, where there is
no stop to attribute it to. A fraud flag may carry a `stopId`, but it must be one
on the route it also names.

**The volume conversation, settled server-side.** It had to be, to unblock the
endpoint; these numbers are the contract, and are worth pushing back on now rather
than after the client ships against them.

| | |
|---|---|
| **Per-request cap** | **10,000 rows**, across both lists. Over that is a `400 Visit.TelemetryBatchTooLarge` |
| **Chunking** | **Required client-side.** Unlike OPEN-3, this is a cap an honest device *will* hit — a weekend offline is tens of thousands of rows. Send repeated requests until the queue drains, keeping anything unsent pending |
| **Sampling** | **No more than one fix every 15 s, and only after 25 m of movement.** A handset parked in a shop for forty minutes should record one fix, not 160 |

Measured: a full 10,000-row chunk stores in ~1.1 s, and re-pushing that same chunk
answers in ~0.1 s with no duplicate rows — the duplicate check runs before any row
is constructed, so retrying after a timeout is cheap as well as safe.

**Nothing in this payload is treated as a finding.** `isMocked` and every reported
flag are claims by the device that would be compromised first if the rep were
faking their day, so they are stored as testimony and are never a reason to refuse
a row. A flag type the server does not recognise is stored too — under `unknown`,
with the raw string preserved — so a newer client raising a new condition never has
that evidence silently dropped.

---

## 6. Reality check: which push lists carry data today

The push contract defines eight lists. **Four of them are always empty in the
shipped build** — not because the plumbing is missing, but because no screen is
wired to the use cases that fill them.

| Push list | Status today | Why |
|---|---|---|
| `checkIns` | ✅ Live | `stops_check_in_screen` dispatches `CheckInRequested` |
| `checkOuts` | ✅ Live | `CompleteVisitCheckOut`, from the inventory flow and the Continue-Working card |
| `notes` | ✅ Live | Written by the *skip stop* flow on the dashboard |
| `photos` | ⚠️ Captured, never sent | **No longer blocked** — endpoint 4 is live; needs the upload-then-push step in §5.1 |
| `orderLines` | ❌ Always empty | `OrderCaptureForm` is not mounted on any screen |
| `stockUpdates` | ❌ Always empty | `StockUpdateForm` unmounted; `DepotStockCountCubit` is registered in DI but consumed by nothing, and `inventory_visible_screen.dart` renders a hardcoded item list and persists nothing on submit |
| `returns` | ❌ Always empty | `ReturnsForm` is not mounted |
| `collections` | ❌ Always empty | `CollectionsForm` is not mounted |

**What this means for you.** Build the endpoint to accept all eight — the
contract is settled and the client already serialises all of them. But when you
test against a real device, expect only check-ins, check-outs and notes to
arrive. If you are waiting on a stock count to validate your handler, it will
never come until the client wires that UI.

These gaps are tracked in [README.md](README.md) → *Known gaps*. They are client
work, not backend work.

---

## 7. Open decisions — **all resolved**

Every one of these is now settled server-side. Three of them imply client work,
marked below.

| | Decision | Resolution |
|---|---|---|
| **OPEN-1** | Photo upload shape | ✅ **Multipart** (Option A). Live. Spec in §5.1. → **client work: upload, rewrite `url`, then push.** |
| **OPEN-2** | No "permanently invalid" bucket | ✅ **Third bucket added.** The push response now carries `discardedIds` plus a `discarded` array giving an `errorCode` and `reason` per row. **Additive and safe to ignore** — a client that does not read it treats those ids as absent from both lists, which it already handles by retrying. → **client work: stop resending discarded ids**, and permanently bad rows stop cycling forever. |
| **OPEN-3** | Batch limits | ✅ **5,000 rows per push**, across every list; request bytes bounded separately by Kestrel at 32 MB. Deliberately set far above the "hundreds of rows" worst case so an honest device never meets it — because chunking is still unimplemented client-side, a cap a rep could hit in normal use would strand their day permanently. |
| **OPEN-4** | Telemetry endpoint | ✅ **Built** as its own endpoint rather than extra lists on `/push`, so a rep's check-ins are not stuck behind their GPS trail. Caps and sampling in §5.2. → **client work: wire it, and chunk.** |
| **OPEN-5** | Route/stop status write-back | ✅ **Derived server-side** from check-ins and check-outs, as recommended — one source of truth, and what the client already assumes. There is deliberately no field to push a status in. Stops carry a real execution state, never a hardcoded `pending`. |
| **OPEN-6** | ~~Territory~~ | ✅ Resolved both sides. The client reads `territoryCode` from `/auth/me`; the server treats `territory` as a **filter, never a scope** — passing another rep's territory narrows the result and can never widen it. Scope always comes from the bearer token. |

---

## 8. Build order — **server side complete**

The original order, with where each step landed:

1. ~~**`GET /routes`**~~ — ✅ done.
2. ~~**`POST /push`**~~ — ✅ done, and it accepts all eight lists, not just the
   three that carry data today (§6).
3. ~~**Resolve OPEN-1**, then photos~~ — ✅ done, multipart.
4. ~~**`GET /routes/delta`**~~ — ✅ done. Still a full re-pull of the rep's current
   scoped set, exactly as the client expects; `since` only lets the server
   short-circuit to an empty set when nothing has moved.
5. ~~**`POST /telemetry`**~~ — ✅ done.

**What is left is all client-side**, in the order that recovers the most value:

1. **Echo `generatedAt` as `since`** on the delta pull, if the client does not
   already — it is now a 400 to send a future watermark (§3).
2. **Photo upload** (§5.1) — this is the one that unblocks *evidence*. Check-in
   requires a shopfront proof photo and none of it reaches the server today.
3. **Read `discardedIds`** (OPEN-2) — small change, stops permanently bad rows
   retrying forever.
4. **Wire the telemetry push** (§5.2), with chunking.
5. **Mount the four unmounted capture forms** (§6) — order lines, stock updates,
   returns, collections. The endpoint has accepted all four since day one; nothing
   will arrive until a screen fills them.

---

## 9. Testing against the client

There is no mock route feed any more. The bundled fixtures were deleted when the
real endpoints landed, so no code path can make a missing or misbehaving
endpoint look healthy — the app shows what the API returns, or shows the
failure.

```bash
# Point a build at a different host without rebuilding config
flutter run --dart-define=API_BASE_URL=https://your-tunnel.example.com

# Log real request/response bodies (redacted; ignored in release builds)
flutter run --dart-define=API_LOG_BODIES=true
```

`test/features/my_visits/route_feed_fixture.dart` builds the exact JSON the
client expects to parse, and drives the real `ApiRouteRemoteDataSource` over a
scripted transport. It is the fastest way to check a payload shape against the
client without a device.

---

## Related

- [api.md](api.md) — the field-level specification. **The contract.**
- [README.md](README.md) — feature entry point, screens, state, known gaps.
- [architecture.md](architecture.md) — every screen, bloc and nav helper.
- [../../skills/api-integration.md](../../skills/api-integration.md) — how the
  client's HTTP layer works: envelope, error dialects, paging, the
  0-based/1-based conversion, and why timestamps carry an explicit offset.
