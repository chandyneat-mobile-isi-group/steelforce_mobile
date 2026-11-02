# My Visits — Workflow & Structure

Route management and fraud-safe field-visit capture for sales reps. A rep is assigned a daily route with ordered depot stops, walks through each stop with geofence-verified check-in/out, captures market data, and can pivot straight into building a quotation.

## 0. Visits rebuild on the Plans API (in progress — 2026-10-27)

The Visits tab is being rebuilt on the backend's **Plans API**
(`/api/v1/mobile/plans…`), replacing the route-sync model described in §2–§11.
It is built in stages; each stage lands only after the previous one is verified.

| Stage | Scope | Endpoints | Status |
|---|---|---|---|
| 1 | Visits screen: today's list + month calendar | `GET /mobile/plans/today` (list), `GET /mobile/plans?period=ThisMonth` (calendar) | **Done** |
| 2 | Visit details + GPS check-in | `GET /mobile/plans/{id}`, `POST /mobile/plans/{id}/check-in` | **Done** (2026-10-28) — see §0.2 |
| 3 | Inventory photos, check-out, skip | `POST …/{id}/inventory-check-photo-upload`, `POST …/{id}/check-out`, `POST …/{id}/skip` | **Done** (2026-10-30) — see §0.1, §0.2 |
| 4 | Ad hoc start + cancel | `POST /mobile/plans/ad-hoc`, `POST …/{id}/cancel` | Start **done** (2026-10-30) from the depot card and detail — see §0.4; cancel not started |
| 5 | Check-in history + notification links | `GET /mobile/check-ins`, `GET /mobile/check-ins/{id}`, `/me/notifications…` | Not started |

### 0.1 Stage 1 — what is wired

**One endpoint per job:**

| Part of the screen | Endpoint | Cubit |
|---|---|---|
| Summary + visit list (today) | `GET /api/v1/mobile/plans/today` | `VisitPlansCubit` |
| Calendar day counts, and the list for any **other** picked day | `GET /api/v1/mobile/plans?period=ThisMonth` | `VisitPlanCalendarCubit` |

```
ShellTab.myVisits / Static.myVisits
  └─ VisitPlansScreen                       presentation/screens/visit_plans/
       ├─ StopCalendarSection (reused)       ← VisitPlanCalendarCubit → GetMyVisitPlans(ThisMonth)
       └─ today list / picked-day list       ← VisitPlansCubit       → GetTodayVisitPlans
            both → VisitPlanRepository → ApiVisitPlanRemoteDataSource (authenticated Dio)
                                          → VisitPlansModel (same MyPlansView parser for both)
```

- **Today is picked by default.** The summary card and the list come from
  `/plans/today`; today's calendar dot uses the same response, so the dot and
  the list cannot disagree.
- **Picking another day** lists that day's visits from the month the calendar
  already loaded — no extra request. Picking today returns to `/plans/today`.
- **Map (UI ready, waiting on backend):** the calendar's map button opens
  `VisitPlansMapScreen` with the visits the list is showing for the picked
  day. Items now carry `latitude`/`longitude` and they are parsed onto
  `VisitPlan` (`hasLocation`), but the server still sends them as `null`, so
  the map centres on Phnom Penh (and the rep's location when permission is
  already granted), shows a "locations are coming soon" notice, and lists the
  day's visits under it. **Next:** draw a pin for each plan with
  `hasLocation` — the button, route and screen stay as they are.
- **Calendar range:** the endpoint answers `Today`, `ThisWeek` or `ThisMonth`
  only, so the calendar knows the current month. Other months show no dots.
- **Nothing identifies the rep** but the bearer token — no territory or
  employee code is sent to either endpoint.
- **Response (`data`, both endpoints):** `period`, `from`, `to`, `total`,
  `completed`, `remaining`, `skipped`, `missed`, `adHoc`, `items[]`. Each item:
  `id`, `assignmentDate`, `visitType`, `outletType`, `depotCode`, `nonDepotId`,
  `outletName`, `depotName`, `status`, `depotType`, `depotTier`,
  `territoryCode`, `latitude`, `longitude` (the last five may be `null`).
- **Name shown:** `depotName` only — `outletName` is parsed but not displayed.
- **Visit card** (styled like the stop card): depot name and address, status
  tag in the top-right corner, then `territory · channel · tier`, with a map
  and a skip action. The plans API sends no channel: it is the depot's own
  from the depots API, found on the device by `depotCode` (`nonDepotId` for a
  Non-BP depot) — the same line the depot card shows. Any value sent as `null` reads **Null**. Address has no field in
  the plans API yet, so it always reads Null. The map action opens the maps app
  and is dimmed while the plan has no coordinates. Depot code and visit type
  are not on the card.
- **Skip** — `POST /api/v1/mobile/plans/{id}/skip` with `{ "reason" }`
  (1–500 chars), `{id}` the plan id. The red × shows on **today's list only**,
  for Planned or CheckedIn visits that are not ad hoc (`VisitPlan.canSkip`).
  The rep picks one of four preset reasons (sent in English): Shop closed,
  Depot not available, No stock needed, Access denied — no free text.
  Online only; on success today's list and the calendar reload. Refusals:
  `PLAN_NOT_TODAY`, `PLAN_STATUS_CONFLICT`, `PLAN_NOT_FOUND`/404,
  `VALIDATION_FAILED`/400 each have their own message; 401/403 as for reads.
  The 200 body (`MyPlanDetail`) is not parsed — its schema is not documented.
  `territoryCode` is read only; it is never sent.
- **Location:** a pin needs both coordinates; one alone, or a value off the
  globe, is treated as no location.
- **Identifiers:** the item `id` is the **plan id** — the only id check-in,
  skip and complete accept. The depot code is never used as a plan id; cards
  are keyed by plan id.
- **Counts are the server's.** The summary shows `total/completed/remaining/
  skipped/missed/adHoc` from `/plans/today` as sent; never recomputed.
- **Dates:** `assignmentDate` is read as the calendar day in its text
  (`yyyy-MM-dd`), never shifted through a time zone.
- **Status:** `Planned`, `CheckedIn`, `Completed`, `Skipped`, `Missed`, plus
  ad hoc `Draft`, `Cancelled`, `Expired`. An unrecognised value is shown as the
  server's word. Each status has its own colour **and** icon.
- **Parsing is tolerant:** missing counts read as 0, missing names as null,
  numbers sent as strings still parse. An item without an `id` is dropped.

**States (today list):** loading (card skeleton) · loaded · empty (counts +
"No visits today") · error (message + Retry) · refresh (pull-to-refresh
reloads both endpoints; a failed refresh keeps the list and shows a SnackBar
with Retry). **Calendar:** a failed load while today is picked only costs the
dots, so it is a SnackBar with Retry; with another day picked it is the error
view. A picked day with nothing planned says "No visits on this day".

**Errors:** offline → `NetworkFailure` without a request (ADR-005 reachability);
401 → the auth interceptor refreshes once and replays, and only a 401 that
survives that reaches the screen, as "session ended"; 403 → "only available to
sales employees" (**never** a sign-out); anything else → the server's message
or a generic one; an unreadable 200 → its own message, never a crash.

**Duplicate requests:** each cubit joins a second `load`/`refresh` onto the
one in flight. Opening the screen sends exactly one request to each endpoint;
picking a day sends none.

**Offline (v30):** each successful read of `/plans/today` and
`/plans?period=ThisMonth` replaces a copy in `visit_plan_snapshots`.
Offline, the copy is answered — today's only on the same calendar day, the
month's only within the same month — and the list says "saved at HH:mm". The
shell prefetch (`offline-architecture.md` §4.1) fills it on every start.
Cards were display-only in this stage; Stage 2 (§0.2) wired them.
The old `StopDashboardScreen` flow (§11) is no longer mounted on the tab but is
still in the code; it is removed once Stages 2–3 replace check-in and
check-out.

### 0.5 Offline plan visits (2026-10-30)

Check-in, inventory photos and check-out work offline; **ad hoc start does
not** (online only — offline the rep is told at the tap, before the dialog).

- **Outbox (schema v32):** `plan_visit_outbox`, one row per step, keyed by
  the id the step is sent with (`checkInId` / `uploadId` / `checkOutId`), so
  a resend after a lost answer is the same request. Photos are copied to
  `<documents>/plan_outbox/<stepId>/` when saved, and deleted once sent.
- **When a step queues:** offline; or the visit already has steps waiting
  (it goes behind them); or online but no answer came (network, timeout).
  Otherwise it goes live exactly as before.
- **Sending:** `PlanVisitUnsentWorkSource` (sync engine — reconnect, resume,
  launch, after each save). Each visit strictly oldest first: check-in →
  photos → check-out. No network / timeout / 401 / 429 / 5xx → kept and
  retried. `PLAN_INVENTORY_PHOTO_LIMIT` counts as sent. **Any other refusal
  holds the visit** ("Needs attention") with the server's reason; nothing is
  lost. The rep can **Resend** or **Discard** (confirmed) from the card; a
  new check-in for the visit (e.g. with a reason) replaces the refused one
  and releases the rest.
- **Zone offline:** each successful `GET /plans/{id}` is kept (snapshot key
  `target:<planId>`), and today's startable visits are fetched ahead while
  online. Offline the kept copy drives the same zone check; a visit never
  fetched falls back to today's plan item with no radius — the server judges
  the zone when the check-in is sent.
- **What the rep sees:** a check-in saved offline makes the visit read
  CheckedIn on the phone (Continue card included), a check-out Completed,
  each with a "Waiting to sync" chip until the server agrees. Messages say
  "will be sent when you're back online". The lists reload after each drain.
- **Sign-out** is refused while any step is left (as for quotations).

### 0.4 Stage 4 — ad hoc start from Depots

`POST /api/v1/mobile/plans/ad-hoc` with `{ visitId, outletType, depotCode | nonDepotId }`,
called from the depot card's Add visit button and the depot detail screen
(confirm dialog first; its note stays a local depot activity). Replaces the old
`POST /mobile/visits/ad-hoc` call on those two entry points.

- **Outlet:** a `Depot` row is sent as `outletType: 1` + `depotCode`; a
  `NonDepot` row as `outletType: 2` + `nonDepotId` (its `depotId`). Rows
  awaiting approval (`Draft`, `NonDepotDraft`) have no button. The 1/2 values
  are read from the Swagger example — **to be confirmed by the backend.**
- **visitId:** a v4 uuid kept per outlet in memory until the server answers
  for good — reused after no network, timeout, 429, 5xx or an unreadable 200
  (the server answers 200 with the same visit); dropped after success or any
  other refusal, so the next tap is a new visit. Not persisted across restarts.
- **Answer:** 201 new / 200 replay — `data` is read as a plan item (the id
  falls back to the sent `visitId`). The SnackBar offers **Start visit**, which
  checks in like any plan (`VisitPlan.canStart` now includes `Draft`).
- **Refusals:** 403 `PLAN_EMPLOYEE_CODE_REQUIRED` → "sales employees only"
  (never a sign-out); 404 `PLAN_OUTLET_NOT_FOUND`; 409
  `PLAN_ALREADY_VISITED_TODAY` → "already on today" (a success, `details.planId`
  kept); 409 `PLAN_AD_HOC_LIMIT_REACHED`; 409 `PLAN_ID_IN_USE` → try again with
  a new id; 429 → wait. Online only.

### 0.2 Stage 2 — card tap, Start Visit, check-in

Contract: backend `features/visit-check-in/api-contract.md`.

- **Card tap** opens the depot's `DepotDetailScreen`. The plan carries only a
  `depotCode`, so it is resolved to the platform id: the local depot book
  first (`BrowseDepots`, exact code), then `LookupDepotByCode`. Neither knows
  it → a SnackBar, no navigation.
- **Start Visit** is not on the card. It sits at the bottom of the depot
  details opened from today's list (`VisitPlanStartBar`), for Planned or
  CheckedIn plans. CheckedIn reads *Continue visit* and skips the check-in.
- **Check-in** (`VisitPlanCheckInScreen` / `PlanCheckInCubit`) is the route
  check-in UI — header, map, geofence banner, proof-photo dropzone, bottom
  bar — as `part`s of `stops_check_in_screen.dart`, titled "Visit Plan
  Check-in". It reads `GET /mobile/plans/{id}` for `depotLocation` +
  `radiusMeters`, streams the fix from `LocationTrackingCubit`, takes 1–5
  stamped photos (`ProofPhotoService`), and — when
  the fix is outside the radius, or the server answers
  `PLAN_CHECK_IN_REASON_REQUIRED` — a reason code + description. Sent as
  multipart to `POST /mobile/plans/{id}/check-in`. `checkInId` is made once
  per screen and reused on retry. Online only; each refusal code has its own
  message.
- **After check-in** the visit goes to Inventory Visibility with the plan's
  id (`openInventoryVisibilityForDepot(planId:)`).
- **Inventory photos** — Submit sends the three photos as multipart to
  `POST /mobile/plans/{id}/inventory-check-photo-upload` (`photos` +
  `uploadId`) instead of the local route-stop store
  (`planInventoryUploader`). The `uploadId` stays the same while the photos
  do, so a retry after a lost answer adds them once. A retaken photo gets a
  new id. A refusal keeps the rep on the step with its message.
  `PLAN_INVENTORY_PHOTO_LIMIT` counts as done, because the visit already
  holds photos. Online only.
- **Check out** — the completion screen shows *Check out*
  (`PlanCheckOutButton` / `PlanCheckOutCubit`) where a route visit shows
  *Complete visit*. It reads a GPS fix (fresh, else one at most 2 min old)
  and posts JSON `{checkOutId, latitude, longitude, accuracyMeters}` to
  `POST /mobile/plans/{id}/check-out`. `checkOutId` is made once per screen
  and reused on retry. No notes are sent yet. On success the app goes back
  to the Visits list, the lists reload, and a "Visit checked out" SnackBar
  shows. With no fix, nothing is sent and the rep is told to turn location
  on. Each refusal code has its own message. Online only.
- A plan visit writes no route resume pointer: *Continue Working* does not
  resume it. The server's status does — a CheckedIn plan reads *Continue
  visit*.
- **Not yet:** the Quotation Builder's *Complete visit*, reached from this
  screen, still runs the legacy route path. It does not check the plan
  out.

## 1. Folder structure (clean architecture)

```
my_visits/
├── data/
│   ├── local/        # sqlite/drift local DB, route + visit local data sources
│   ├── mock/          # mock route generator (dev backend)
│   ├── models/        # DTOs / JSON-serializable models
│   ├── remote/        # RouteRemoteDataSource + paginated RouteSyncPage
│   ├── repositories/  # repository implementations (impl of domain/repositories)
│   └── services/      # GeolocatorTrackingService (real GPS stream)
├── domain/
│   ├── entities/       # RoutePlan, RouteStop, VisitStatus, CheckInRecord, FraudFlag, ...
│   ├── repositories/    # abstract repository contracts
│   ├── services/       # GeofenceService, FraudDetectionService (pure business rules)
│   └── usecases/        # one class per action (CheckIn, AddOrderLine, RunRouteInitialSync, ...)
├── presentation/
│   ├── bloc/            # ActiveRouteBloc, LocationTrackingCubit, RouteDashboardCubit, RouteSyncCubit, VisitCubit
│   ├── screens/         # see workflow below
│   ├── widgets/         # stop cards, maps, capture bottom sheets, timeline, etc.
│   ├── models/          # VisitRecord (history UI model)
│   └── services/        # CameraProofPhotoService (stamped proof photo)
└── my_visits_injection.dart   # DI wiring
```

## 2. Two navigation paths

There are two ways into this feature — they share the same blocs/entities but are separate UI flows.

### A. Guided field flow (current / canonical)
`MyVisitsDashboardScreen` → `RouteDispatchScreen` → `RouteTransitScreen` → `RouteCheckInScreen` → `RouteStockCountScreen` → hands off to the **Order** feature's `ShopListScreen`.

Entered from `HomeScreen`'s "Start Route" CTA. Uses classic `Navigator.push` with `RouteSettings(name: ...)` (not go_router) so screens can `popUntil` a named route.

### B. Legacy / alternate single-screen flow
`ActiveRouteScreen` → `StopDetailScreen`, wired via `AppPages.onGenerateRoute` under `Static.myVisits` (`lib/routes/app_page.dart`), currently loading a hardcoded `'routeId'`. Same underlying blocs, but check-in/out and all capture types (order/stock/return/collection/note/photo/signature) happen on one screen via bottom sheets, instead of the 4-step guided flow. Appears to be an earlier iteration — confirm with the team whether to deprecate.

### C. Visit history (read-only, mock data only)
`MyVisitsHistoryScreen` → `VisitHistoryDetailScreen`, reached via "View History" on the dashboard. Not wired to any bloc/repository/DB — pure UI backed by static mock data.

## 3. Step-by-step: guided flow

| Step | Screen | What happens | Next |
|---|---|---|---|
| 0 | `MyVisitsDashboardScreen` | Syncs routes (`RouteSyncCubit.syncIfNeeded()`), shows today's routes + summary cards | Tap a route → Step 1 |
| 1 | `RouteDispatchScreen` | Ordered stop list, live distance, status pills. Starts GPS tracking. Keeps a `BlocListener<LocationTrackingCubit>` alive underneath child screens to keep geofence status live | Tap a stop / CTA → dispatches `StartDayRequested` + `StopSelected` → Step 2 |
| 2 | `RouteTransitScreen` | Live map + distance/ETA to the stop. "I've Arrived" is locked until `insideGeofence == true` | Tap "I've Arrived" → Step 3 |
| 3 | `RouteCheckInScreen` | Geofence status banner + fraud warnings; captures one or more GPS/time-stamped shopfront photos — each capture writes straight into `VisitCubit` state (Drift-persisted immediately, list-based) instead of being staged in widget state, so photos survive rebuilds/navigation/app kill; dispatches `CheckInRequested` (runs fraud validation) once at least one photo exists | On success (`VisitStatus.checkedIn`) → Step 4. On block, shows the reason via snackbar |
| 4 | `RouteStockCountScreen` | Rapid on-shelf SKU counter, flags out-of-stock items as quotation opportunities. "Done" persists stock updates, dispatches `CheckOutRequested` (completes the visit), then `popUntil` back to Step 1 and pushes `ShopListScreen` (Order feature) pre-filtered by stop/territory | Rep either returns to Dispatch for the next stop or builds a quotation immediately |

Ending the day (`EndDayRequested`, found in the legacy `ActiveRouteScreen`) marks the route `completed`.

## 4. State machines

**`RouteStatus`** (route-level): `planned → published → inProgress → completed`
- `inProgress` set on `StartDayRequested`; `completed` set on `EndDayRequested`.

**`VisitStatus`** (stop-level): `pending → enRoute → arrived → checkedIn → checkedOut`, or `→ missed`
- `pending → checkedIn`: on `CheckInRequested`, gated by geofence + fraud validation.
- `checkedIn → checkedOut`: on `CheckOutRequested`, only if currently `checkedIn`.
- `→ missed`: on `NextStopRequested`, if the rep advances past a stop never checked out.
- Only `checkedOut` counts as complete (`VisitStatus.isComplete`).

## 5. State management (bloc/cubit)

- **`ActiveRouteBloc`** — the central state machine: Start Day → Navigate → Arrive → Geofence Validation → Check In → Visit → Check Out → Next Stop → End Day. Runs fraud validation on check-in, persists `CheckInRecord`/`CheckOutRecord`, drives `currentStopIndex`.
- **`LocationTrackingCubit`** — starts/stops the GPS stream, persists samples, flags "impossible travel speed" fraud.
- **`RouteDashboardCubit`** — drives the dashboard off a live stream (`WatchTodayRoutes`); recomputes progress/summary as check-ins happen anywhere in the app. `RouteDashboardScreen` appends a `RouteCardSkeleton` shimmer below the list while a sync is in-flight, instead of leaving trailing space blank.
- **`RouteSyncCubit`** — mirrors the Order feature's sync cubit: `syncIfNeeded()` runs full initial sync if never synced, `refresh()` always runs delta sync. `RouteDashboardScreen`'s listener reacts to both `RouteSyncSucceeded` (reload) and `RouteSyncFailed` (SnackBar with the failure message) — a sync failure is no longer silently swallowed.
- **`VisitCubit`** — manages offline capture data for the checked-in stop (order lines, stock updates, returns, collections, notes, photos), optimistic local updates + local persistence. `RouteCheckInScreen` writes each captured photo here immediately (`addPhoto` per shot), not just at final submit.

## 6. Domain usecases (grouped)

- **Route lifecycle**: `GetRoute`, `FetchTodayRoutes`, `WatchTodayRoutes`, `UpdateRouteStatus`, `UpdateStopStatus`
- **Check-in / check-out**: `CheckIn`, `CheckOut`
- **Visit capture**: `AddOrderLine`, `AddStockUpdate`, `AddReturn`, `AddCollection`, `AddVisitNote`, `AddVisitPhoto`, `FetchVisitData`
- **Location & fraud**: `RecordLocationSample`, `FetchLocationSamples`, `RecordFraudFlag`
- **Sync**: `GetRouteLastSyncedAt`, `RunRouteInitialSync`, `RunRouteDeltaSync`

## 7. Geofence & fraud

- **`GeofenceService`** — Haversine distance vs. a stop's `geofenceRadiusMeters` → `insideGeofence`/`distanceMeters`.
- **`FraudDetectionService`** — `validateCheckIn()` combines geofence + GPS accuracy (default max 30m) + mock-location + VPN heuristic into a pass/fail (or allowed-with-warning) result. `isImpossibleTravel()` flags GPS pairs implying > 150 km/h.
- **`FraudPolicy`** — configurable thresholds; currently permissive by default (`blockOnMockLocation: false`, `blockOnVpn: false`) for dev/testability — flip before shipping.
- **`FraudFlag` types**: `mockLocation`, `impossibleSpeed`, `poorAccuracy`, `vpnDetected`.

## 8. Sync

- `RouteSyncRepositoryImpl` mirrors the Order feature's sync repository. Initial sync pages through the backend (`pageSize = 50`), upserting depots + routes each page. Delta sync fetches everything changed since the last-synced timestamp in one call (falls back to full initial sync if never synced).
- Backed by `ApiRouteRemoteDataSource` (`GET /api/v1/mobile/visits/routes` and `.../routes/delta`, see `docs/feature/my-visits/api.md`) — **the only source of routes.** There is no mock route feed any more: the bundled fixtures were removed once the endpoints landed, because routes are rep- and day-scoped (a committed fixture set is wrong as soon as the calendar moves) and because a feed that always answers made a broken one look healthy. Territory comes from the signed-in rep's `AuthProfile.territoryCode` via `SessionManager` (was a hardcoded `'Phnom Penh'`, which returned an empty day for any rep not in that territory); `repId` is never sent, the server derives the rep from the bearer token.
- Local DB is the single source of truth for the UI; `RouteDashboardCubit` reads from it via a live stream, and the dashboard re-subscribes whenever `RouteSyncSucceeded` fires.
- **Hard cross-feature ordering dependency: depot sync must run before route sync.** `route_stops.depot_id` is a real foreign key into `depots` (`PRAGMA foreign_keys = ON`, `core/database/drift/migrations/schema_migrations.dart`), and `RouteDriftLocalDataSource.upsertDepots` only *updates* an existing depot row (ADR-001 — Depots is SAP-owned, route sync may never invent one). If the depot directory hasn't synced yet, every stop's depot is unknown, the `route_stops` insert throws a FK violation, and the **entire** `upsertRoutesWithStops` transaction aborts — zero routes persist, not just the affected stops. `DepotSyncCubit.syncIfNeeded()` is triggered at app-shell startup (`main_shell.dart`'s `initState`, alongside `ResumableVisitCubit.refresh()`) specifically to win this race as early as possible; a Depots-tab visit still runs its own `syncIfNeeded()` too (idempotent, checked against the persisted watermark).
- **`visit_date` must be anchored to the UTC calendar day, not local time.** `RouteDao.fetchRoutesForDay`/`watchRoutesForDay` filter by `DateTime.utc(day.year, day.month, day.day)`. This bit the deleted fixtures repeatedly, and still binds every sync and test path that writes a `visitDate` — in a positive-UTC-offset zone (Cambodia, UTC+7), a naive local-midnight date lands on the *previous* UTC day and silently falls outside every "today" query. Any new sync/seed/test code touching `visitDate` must follow the same convention.

## 9. Known dev-only shims (flag before release)

- `kDebugForceInsideGeofence = true` in `route_transit_screen.dart` — forces "I've Arrived" unlocked regardless of real geofence. TODO in code to flip to `false`.
- ~~Debug-only fixture seeding on the dashboard~~ — **removed.** `seedIsiTowerTestRoute` and `seedMockRoutesForDates` wrote hardcoded routes straight into the live Drift database on every debug launch. Once written, a seeded row is indistinguishable from a synced one, so the fixtures sat on top of real API data and made an empty or wrong route feed look populated. Mock routes now have exactly one entry point — `--dart-define=USE_MOCK_DATA=true`, which swaps the *remote* source and leaves the database honest about where its rows came from.
- `FraudPolicy` defaults intentionally permissive (won't block on mock location / VPN).
- Hardcoded `'routeId'` in the legacy `Static.myVisits` route (`lib/routes/app_page.dart`) — it also provides the wrong blocs for the screen it renders, so entering it throws `ProviderNotFoundException`. Unreachable today; still a defect.

## 10. Known bugs fixed (root causes, for future reference)

1. **Tab switch destroyed all tab state, including this feature's sync cubits.** Fix lives outside this folder (`lib/features/shell/presentation/main_shell.dart`) but explains why My Visits looked broken/reset on every tab switch: the shell's `IndexedStack` was wrapped in a `KeyedSubtree` keyed on the active tab index, so switching tabs gave Flutter a new widget identity and tore down + rebuilt *every* tab — including recreating the factory-registered `RouteDashboardCubit`/`RouteSyncCubit` from scratch, re-running sync each time. Fixed by dropping the per-tab key so `IndexedStack` actually preserves state as intended.
2. **Check-in photo lost on rebuild/navigation/app kill.** `RouteCheckInScreen` stored the captured proof photo in a local `StatefulWidget` field (`_proof`), singular, only pushed into `VisitCubit`/persistence at final submit. Fixed by writing each capture straight into `VisitCubit` (already Drift-persisted, already list-based) as soon as it's taken — see §3/§5.
3. **Route sync silently failing, dashboard permanently stuck on "No local data found."** Root cause: the depot/route sync FK ordering dependency described in §8, combined with the dashboard only listening for `RouteSyncSucceeded` and silently dropping `RouteSyncFailed`. Fixed by triggering depot sync at shell startup and surfacing sync failures via SnackBar.
4. **Seeded test routes invisible to "today."** The since-deleted `seed_isi_tower_test_route.dart` built `visitDate` from local midnight instead of UTC (the same class of bug §8's UTC day-window note describes). Fixed at the time by anchoring to `DateTime.utc(...)`; the seeders themselves are now gone (§9), but the UTC-anchoring rule still binds every sync and test path that touches `visitDate`.

## 11. Stop-centric dashboard (current primary flow)

The primary My Visits entry is now `StopDashboardScreen` (stop-centric), not the
route-centric dashboard. Flow: **Stop Dashboard → Stop Information → Check-In →
Quotation Builder** (the shelf/stock-count step was removed from the visit path; the
depot stock-count feature still lives on the Home Quick Action).

- **Daily schedule comes from the API.** Whatever routes the backend returns for the
  rep and day are what the dashboard shows — there is no generator and no committed
  fixture to regenerate. Per-stop **province variety still shows** because the displayed
  shop comes from the joined depot directory (`DepotRowStopInfoMapper.toStopInfo`),
  not from the route payload. An empty dashboard now means the feed is genuinely empty
  (or failed, which surfaces as a SnackBar) rather than a stale asset.
- **Multi-day + calendar.** `StopDashboardCubit` watches **all** routes (`WatchAllRoutes`)
  and holds a `selectedDate` (default today). The collapsible calendar shows **per-day
  STOP-count dots** (`StopDashboardLoaded.stopCountForDay`); picking a day calls
  `setSelectedDate` and the list re-filters. Post-sync re-read uses `FetchAllRoutes`
  (`reload()`), since sync writes through the data source and the watch stream doesn't
  observe it.
- **Sorting is domain, not UI.** Ordering lives in `StopDistanceSorter`
  (`domain/services/stop_distance_sorter.dart`, returns `RankedStop`): with a GPS fix →
  nearest-first (Haversine); without → **planned order** (by sequence), distances null. The
  cubit only orchestrates the route + location streams and calls it.
- **GPS fallback (never blocks).** `LocationTrackingService.observe` is a foreground-only
  position stream (no foreground-service notification). If permission is denied **or** no
  fix lands within an 8 s timeout (emulator / GPS off / failure), the cubit sets
  `locationUnavailable`, keeps the planned order, hides distances, and the screen shows
  *"Current location unavailable. Showing planned visit order."* A later fix upgrades to
  distance sort. Stop details / check-in / the whole workflow stay reachable with no GPS.

## 12. Open question

`ActiveRouteScreen` / `StopDetailScreen` (legacy flow) still exist alongside the guided 4-step flow. Worth confirming with the team whether they should be removed, kept as a fallback, or documented as deprecated.
