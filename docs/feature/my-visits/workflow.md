# My Visits — Workflow & Structure

Route management and fraud-safe field-visit capture for sales reps. A rep is assigned a daily route with ordered depot stops, walks through each stop with geofence-verified check-in/out, captures market data, and can pivot straight into building a quotation.

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
