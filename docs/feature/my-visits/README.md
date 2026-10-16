# My Visits

> **Purpose:** route execution — a rep is assigned a daily route of ordered
> depot stops, walks each one with geofence-verified check-in/out, captures
> market data, and can pivot straight into a quotation.
> **Code:** `lib/features/my_visits/`
> **Verified:** 2026-08-27, branch `web` @ `142de9b`.

The second-largest feature in the app (7 screens, 25 widgets, 10 blocs, 30 use
cases, 24 entities, 11 local data sources) and the one that most depends on the
app working with no signal.

---

## Documents

| Document | What it covers |
|---|---|
| [architecture.md](architecture.md) | The architecture report and redesign plan — every screen, bloc, nav helper, and the `WorkflowSession` resume path, traced from source. |
| [workflow.md](workflow.md) | Folder structure and the step-by-step visit workflow. |
| [fix-log.md](fix-log.md) | Field-bug fix passes (check-in stuck, iOS lag): symptom, cause, fix. Moved here from `lib/features/my_visits/FIXES.md`. |
| [backend-integration.md](backend-integration.md) | **Start here for integration work.** Which capabilities need an API, the endpoint inventory (5 total — **all 5 now live**), cross-team dependencies, which push lists actually carry data today, and the remaining client-side task list. |
| [api.md](api.md) | Backend API specification for routes and visits. **Status: implemented** — no longer a proposal. Every **OPEN** item is decided; §10 records each resolution and which ones imply client work. |
| [check-in-check-out-api.md](check-in-check-out-api.md) | **Proposed** backend requirements for live check-in / check-out endpoints, and check-out **with order** or **without order**. Needs backend review; the decisions below are its open questions. |

---

## Screens

| Screen | File |
|---|---|
| Stops check-in | `presentation/screens/stops_check_in_screen.dart` |
| Stop dashboard | `presentation/screens/stop_dashboard/stop_dashboard_screen.dart` |
| Stop information | `presentation/screens/stop_information/stop_information_screen.dart` |
| Order history (per stop) | `presentation/screens/stop_information/order_history_screen.dart` |
| Promotions (per stop) | `presentation/screens/stop_information/promotions_screen.dart` |
| Inventory visible (depot stock audit) | `presentation/screens/inventory_visible/inventory_visible_screen.dart` |
| Inventory completion | `presentation/screens/inventory_visible/inventory_completion_screen.dart` |

Reached via `MainShell` tab 2, or directly at `/my-visits` (which builds
`StopDashboardScreen` with its own providers).

---

## State

| Bloc / Cubit | Responsibility |
|---|---|
| `ActiveRouteBloc` | The route currently being executed |
| `RouteDashboardCubit` | Route-level summary |
| `StopDashboardCubit` | One stop's dashboard |
| `VisitCubit` | Check-in / check-out and visit capture |
| `LocationTrackingCubit` | Continuous telemetry during a route |
| `RouteSyncCubit` | Route pull and visit push |
| `ResumableVisitCubit` | Surfaces the "continue where you left off" banner; refreshed when the user returns to shell tab 0 |
| `NavigationStateCubit` | Persisted workflow position |
| `DepotSelectionCubit` | Depot chosen for the stock audit |
| `DepotStockCountCubit` | ⚠ **Registered in DI but consumed by no screen** — see Known gaps |

---

## Data

| Domain repository | Purpose |
|---|---|
| `RouteRepository` | Route plans and stops |
| `VisitRepository` | Visit records and check-in/out |
| `RouteSyncRepository` / `VisitSyncRepository` | Delta pull and batch push |
| `LocationSampleRepository` | Telemetry samples |
| `ActiveWorkflowRepository` | The resume pointer |

Tables: `route_tables.dart`, `visit_tables.dart`, `workflow_state_table.dart`.
DAOs: `route_dao.dart`, `visit_dao.dart`, `route_telemetry_dao.dart`,
`workflow_state_dao.dart`.

`data/local/` still holds both `*_local_data_source.dart` (legacy `sqflite`) and
`*_drift_local_data_source.dart` (current) — the legacy pair exists for the
one-time import path, not as a live persistence route.

---

## Offline behaviour

This feature is the reason the app is offline-first. A rep on a rural route has
no signal for hours.

| Action | Offline |
|---|---|
| View today's route and stops | ✅ Fully |
| Check in / check out | ✅ Recorded locally; geofence verdict marked unverified when location is unavailable |
| Capture stock counts, market data, photos | ✅ Fully local |
| Resume an interrupted visit | ✅ From the local `workflow_state` row — survives a process kill |
| Location telemetry | ✅ Buffered locally, pushed on reconnect |
| Pull a new route | ❌ Needs connectivity |
| Push completed visits | ❌ Queued; drains on reconnect, in order (below) |

### Send order and the sync preview

Work saved offline is sent in this order, so for each stop the server sees
check-in → orders → check-out:

1. Depot registrations
2. Ad hoc visits, then visit check-ins (oldest first)
3. Orders & quotations
4. Visit check-outs (oldest first), then stock counts, notes and photos

A check-out whose check-in has not reached the server yet is held back and
goes right after it. The order is set by the list in
`lib/core/di/injection_container.dart` (`UnsentWorkService`).

The rep can see what is waiting in two places:

| Where | Shows |
|---|---|
| **Sync Center** (shell sync badge) | Depot registrations, a **Visits** section (one card per shop with its unsent check-in / check-out times), then orders & quotations |
| **"Can't log out yet"** dialog (Profile → Log out) | A count per kind, in send order, with how many need the rep's action |

---

## Check-out with or without order — open decisions

A check-out will record whether the visit ended **with an order** or **without
an order** ([check-in-check-out-api.md](check-in-check-out-api.md) §4.2). Four
decisions are needed before the backend builds it. Each has a recommended
answer; **business owner** marks who has to approve it.

### Q1 — The "no order" reasons

**Question:** what reasons can a rep pick when checking out without an order?

**Recommendation:** an admin-managed list, not a list in the app.

- Served by `GET /visits/check-out-reasons`, cached on the phone for offline
  use. Sales ops can change it without an app release.
- Each reason has a stable `code` and English + Khmer names. Old codes keep
  being accepted, because a check-out can arrive days later.
- Keep it to 5–7 one-tap options, so a rep picks one in under 3 seconds.
- Starting list:

  | Code | English | Note required |
  |---|---|---|
  | `stockStillEnough` | Shop still has enough stock | No |
  | `ownerNotAvailable` | Owner / buyer not available | No |
  | `priceTooHigh` | Price too high | No |
  | `orderedByPhone` | Will order by phone later | No |
  | `boughtFromCompetitor` | Bought from a competitor | Yes (which one) |
  | `other` | Other | Yes |

- Each reason is useful beyond the report:
  - `orderedByPhone` can open a follow-up task for the rep.
  - `priceTooHigh` and `boughtFromCompetitor` feed the pricing and competitor
    reports.

**Business owner:** sales ops, who confirm the list and its Khmer names.

### Q2 — Visiting the same stop twice in one day

**Question:** can a rep check in at the same planned stop a second time on the
same day?

**Recommendation:** no. One planned visit per stop per day; a return trip is an
**ad hoc visit**, which already exists (`POST /visits/ad-hoc`).

- **Why:** "planned vs. visited" stays one-to-one, so visit KPIs can't be
  inflated by checking in and out repeatedly. A real return trip is rare and is
  still recorded, as its own visit with its own GPS and time.
- **Server:** a second check-in on a completed stop returns
  `409 Visit.AlreadyCompleted`, with the existing visit in the response.
- **App:** shows "Visited at 09:58 — add an ad hoc visit?" and opens the
  existing ad hoc flow. No new screen is needed.

**Business owner:** sales management (it affects visit KPIs).

### Q4 — Does a draft quotation count as "with order"?

**Question:** if the rep saved a quotation but did not submit it, is the
check-out "with order"?

**Recommendation:** only a quotation the rep has **submitted** counts. That
includes one queued offline and not yet sent. A bare draft does not count.

- **Why:** a draft is often a price check that never becomes an order. Counting
  it would overstate conversion, and a quotation that is never submitted is
  invisible to the approver.
- **App:**
  - "Check out with order" lists the quotations taken at this stop, with the
    submitted ones pre-selected.
  - If the stop only has drafts, the app asks: "You have an unsubmitted
    quotation — submit it now, or check out without order?"
- **Server:** every quotation linked to the visit is kept with its own status,
  so a quotation later rejected by the approver still shows the visit produced
  a quote. Conversion is reported by final status (approved / rejected), not at
  check-out time.

**Business owner:** sales management (defines "conversion").

### Q7 — Linking sales orders, not just quotations

**Question:** sales orders have no API today; they are saved only on the phone.
Should a check-out be able to link them?

**Recommendation:** design for it now, and link quotations only until the
sales-order API exists.

- Put `orders[].type` (`quotation` | `salesOrder`) in the contract from day one,
  defaulting to `quotation`. Adding sales orders later then doesn't break older
  app versions.
- A sales order made from a quotation is linked through that quotation, so most
  visit orders are covered even before the sales-order API exists.
- Backend to-do: a sales-order create endpoint with the same `clientId`
  (idempotency) and `stopId` fields as quotations (§4.7). The app then links
  them the same way and stops keeping sales orders only on the phone.

**Business owner:** backend lead, for the sales-order API timeline.

---

## Resumability

An interrupted visit resumes into the exact screen it left, driven by a single
registry in `presentation/navigation/resume_workflow_dispatcher.dart`. A builder
that cannot rebuild (stop reassigned, args stale) returns `null` and the
dispatcher degrades to guided stop resume rather than routing to a broken
screen. Adding a resumable screen is one registry entry.

Design rationale: [../../adr/ADR-0007-workflow-session.md](../../adr/ADR-0007-workflow-session.md).
Route table and dispatch flow: [../../blueprint/navigation-architecture.md](../../blueprint/navigation-architecture.md#resumable-workflows-my_visits).

---

## Device capabilities

Location (fine, coarse, and background), foreground service for telemetry, camera
and gallery for capture, gallery save via `gal`, and Google Maps for the transit
view. Permission table and failure behaviour:
[../../blueprint/device-integration.md](../../blueprint/device-integration.md).

---

## Tests

`test/features/my_visits/` — 19 files, the densest feature coverage in the repo:
route/visit Drift data sources, sync scope and failure paths, dashboard cubit,
stop distance sorting, stock level, inventory visibility, workflow step updates,
route feed fixtures, screen layout.

---

## Known gaps

- **`DepotStockCountCubit` and `DepotStockCountState` are dead wiring.** Both are
  registered in `my_visits_injection.dart`, but no screen consumes them.
  `inventory_visible_screen.dart` — which *is* the depot stock visual audit —
  renders **mock data** from its own file instead. Either wire the cubit or
  remove the registration; leaving both invites someone to "fix" the mock by
  duplicating the cubit's logic a third time.
- **Photo sync needs the client upload step.** The multipart endpoint is live
  (api.md §6.2), but the client still sends `"photos": []` on every push and holds
  each photo pending. Check-in requires a shopfront proof photo, so **no visit
  evidence reaches the server today.** Upload first, rewrite `url`, then push.
- **Telemetry is not wired.** The endpoint is live (api.md §6.3) and the app
  captures location samples and fraud flags on every route, but nothing calls it,
  so that compliance data still never leaves the device. Chunking is required.
- **`discardedIds` is unread.** The push response now distinguishes "retry later"
  from "never storable" (api.md §6.1). Until the client reads the new bucket, a
  permanently bad row keeps retrying forever.
- **No requirement documents** — geofence tolerance, fraud policy, and check-in
  rules are enforced in code without testable acceptance criteria.

---

## Related

- [../../blueprint/offline-architecture.md](../../blueprint/offline-architecture.md)
- [../../blueprint/sync-architecture.md](../../blueprint/sync-architecture.md) — the target engine; sync here is still per-feature
- [../../blueprint/performance-audit.md](../../blueprint/performance-audit.md) — the depot-stock and check-in findings
- [../order/README.md](../order/README.md) — where a stop pivots into a quotation
