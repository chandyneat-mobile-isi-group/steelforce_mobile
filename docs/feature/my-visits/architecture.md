# Visit Workflow — Architecture Report & Redesign Plan

> ISI Steel Sales Mobile · my_visits feature
> Method: Graphify dependency-graph orientation → source tracing of every screen, bloc, nav helper,
> and the WorkflowSession resume path.
> Rule honored: **plan before code** (`docs/skills/engineering-standard.md` §2 — module-by-module, never ahead of
> the dependency graph). This report is the plan; the increment shipped in this pass is scoped in §6.

---

## 0. Key finding — the new flow already largely exists

The requested "redesign" is **~80% already built and wired**. This is a *finishing/stabilizing* task, not a
greenfield rebuild. Blindly re-creating these screens would duplicate widgets and break working offline logic
(explicitly forbidden by the brief). What actually exists today:

| Requested step | Status in code | Evidence |
|---|---|---|
| Route Dashboard | ✅ Built | `route_dashboard_screen.dart` — cards, progress, opens the route |
| Route Information (NEW) | ✅ **Already built** | `route_information/route_information_screen.dart` + `widgets/route_info/*` (hero, stats row, map preview, timeline, objectives, quick actions, Start CTA) |
| Stop Information (NEW) | ❌ **Missing** — the one real gap | Route Info goes straight to Check-In today |
| Check-In | ✅ Built | `route_check_in_screen.dart` (perf notes in `docs/blueprint/performance-audit.md` §2) |
| Depot Count Stock | ✅ Built + **fixed last pass** | `depot_stock_count_screen.dart` — sync-on-empty, no blank screen (see that audit §1) |
| Quotation Builder handoff | ✅ Wired | `route_information_screen._openQuotation` → `QuotationBuilderScreen(leadId, leadDisplayName)` |
| Quotation Detail / Sales Order / Success | ✅ Built (order feature) | `order/presentation/screens/quotation/*`, `success_screen.dart` |
| WorkflowSession persist + resume | ✅ Built | `ActiveWorkflow` entity + `ActiveRouteBloc._persistWorkflow` (write) + `resume_workflow_dispatcher.dart` registry (read) |

## 1. Current navigation flow (traced)

```
Home Dashboard
  └─ Route tab → RouteDashboardScreen
        └─ tap route → openRouteInformation(routeId)         [route_dashboard_screen.dart:74]
              → RouteInformationScreen   (ActiveRouteBloc + LocationTrackingCubit + VisitCubit + RouteSyncCubit)
                    └─ tap stop / Start Visit → _start()
                          • bloc.add(StartDayRequested) if not started
                          • bloc.add(StopSelected(index))  → _persistWorkflow  ← WorkflowSession updated
                          └─ push RouteCheckInScreen  (same 3 blocs via .value)
                                └─ CheckInRequested → RouteStockCountScreen
                                      └─ Done → Build Quotation → QuotationBuilderScreen
                                            → QuotationDetail → SalesOrder → Success
```

Legacy path retained on purpose: `openRouteDispatch` → `RouteDispatchScreen` is still used by the
"Continue Working" resume deep-link (`resume_workflow_dispatcher.dart`), which lands on Dispatch/Stock.

## 2. Target flow (brief) vs current — the delta

```
Dashboard → Route Information → [ Stop Information ] → Check-In → Depot Count → Quotation Builder → …
                                 ▲ ONLY MISSING STEP
```
Everything else in the target chain already exists. The **single structural gap** is a dedicated
**Stop Information** review screen between selecting a stop and checking in.

## 3. Bloc / repository / data-flow map (as-is)

- **`ActiveRouteBloc`** — owns the route + selected stop + geofence + day-started; every mutation calls
  `_persistWorkflow` → `UpdateWorkflowStep` → `WorkflowStateLocalDataSource` (single-row `ActiveWorkflow`).
- **`LocationTrackingCubit`** — GPS stream, fraud (impossible-speed) screening; started `background:true` from Route Info.
- **`VisitCubit`** — per-stop visit captures (photos/orders/stock/collections/returns), Drift-backed.
- **`RouteSyncCubit`** — pull route plan; forwarded (not recreated) across the chain via `BlocProvider.value`.
- **Reads are local-first** (Drift); route/visit/stock are offline-capture with push telemetry
  (`docs/blueprint/offline-architecture.md` §4). No screen blocks on SAP.
- **WorkflowSession**: `currentScreen` + JSON `navigationArguments` → resume registry rebuilds the exact screen;
  falls back to guided Choose-Stop on any missing/invalid arg (defensive, per `docs/blueprint/offline-architecture.md` §3.2).

## 4. Root-cause notes (from the brief's concerns)

- **Depot products sometimes empty** → root-caused and **fixed** last pass: the local catalog was empty and the
  flow did a one-shot read with a dead empty state; now it reads local-first → syncs-on-empty → shows skeletons →
  products, or an actionable offline-empty with Retry. Full write-up: `docs/blueprint/performance-audit.md` §1.
- **Check-In slow** → not a blocked isolate; it's the first-GPS-fix + permission dialog + map warm-up, masked by
  `kDebugForceInsideGeofence`. Roadmap in the performance audit §2 (skeleton-first + progressive overlays).

## 5. Design of the missing screen — Stop Information

**Single responsibility:** review the selected depot *before* committing to check-in.

- **Data source:** the already-loaded `RouteStop` from `ActiveRouteBloc` (offline, instant — no new fetch).
  Available fields: depot name, code, contact person, phone, address, territory, GPS, live distance
  (computed from `LocationTrackingCubit` position). Fields the entity does **not** model (outstanding balance,
  last-visit date, per-stop notes/objectives) are intentionally **omitted, not fabricated** — added later when
  the read-model grows.
- **Quick actions:** *View Depot Profile* → real (`DepotDetailScreen`, already used by the resume registry);
  Call / Open Maps / Previous Orders / Previous Visits → the same graceful "coming soon" affordance the existing
  `RouteInfoQuickActions` already uses (no new dependency added — `url_launcher` is not in `pubspec`, and the
  playbook requires vetting a dep before adding it).
- **CTA:** *Start Visit* → pushes `RouteCheckInScreen` with the **same** `ActiveRouteBloc`/`VisitCubit`/
  `LocationTrackingCubit` via `BlocProvider.value` (identical to today's direct hop — check-in behavior unchanged).
- **WorkflowSession:** entering Stop Info dispatches `StopSelected(index)` (already persists the selected stop via
  `_persistWorkflow`). The review screen holds **no business state**, so it deliberately gets no separate resume
  registry entry — a kill here safely resumes to the route (nothing captured yet). This *respects* "don't bypass
  persistence": there is nothing new to persist until check-in, which is already persisted.
- **UI:** Material 3, ScreenUtil-responsive, `AppThemeColors` extension (light/dark), `SafeArea`, large touch
  targets, one subtle fade/slide entrance. No heavy animations.

## 6. Increment shipped in this pass (scoped, non-breaking)

**Only the missing screen + its single wiring point** — additive, reversible, zero change to check-in/stock/
quotation logic, SAP, or offline behavior:

1. New `stop_information/stop_information_screen.dart` (+ nothing else new).
2. `route_information_screen._start()` retargeted: Route Info → **Stop Info** → Check-In (was Route Info → Check-In).
   The bloc dispatches (`StartDayRequested`, `StopSelected`) are unchanged and still fire before the hop.
3. Localization keys (en + km, full parity).

**Deliberately deferred (own PRs, per §2 + playbook §3/§8 — high blast radius, not blind-rewritten here):**
- Check-in perf refactor (skeleton-first + progressive GPS/permission overlays) — `docs/blueprint/performance-audit.md` §2.
- Startup: move legacy import off the pre-`runApp` path — `docs/blueprint/performance-audit.md` §3.
- `cart_items.customization_json` duplicate-column migration bug — `docs/blueprint/performance-audit.md` §6.
- Enriching the stop read-model (balance / last-visit / notes / objectives) once the data source exists.

## 7. Guardrails verified against the brief's "DO NOT"
- ✅ SAP integration untouched (no order/sync code changed). ✅ Offline-first preserved (local-first reads).
- ✅ No business validation removed (geofence/skip/deviation logic intact). ✅ No hardcoded navigation
  (goes through the existing typed push helpers). ✅ No duplicated widgets (reuses `AppThemeColors`,
  the quick-action pattern, and existing blocs). ✅ Workflow persistence not bypassed (`StopSelected` still persists).
