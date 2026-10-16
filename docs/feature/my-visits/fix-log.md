# Fifth pass — check-in button stuck, screen laggy (iOS)

**Symptom.** "Check-in & Continue" stayed faded with a spinner forever; the
screen felt slow; the banner read "GPS {dist} m away"; the header chip text was
oddly letter-spaced.

| Cause | Fix |
|---|---|
| `_onCheckIn` returned **silently** when the stop was already checked in, no stop was selected, or a DB write threw. Bloc also never emits a state equal to the current one, so a second refusal with the same reason produced no emission. The screen waited for a state change that never came. | New `ActiveRouteReady.checkInAttempt` counter — every exit of `_onCheckIn` emits with it incremented (success, block, already-checked-in, save failure). The screen settles on "counter went up", not "state changed". Write failures now show "Could not save the check-in". |
| No timeout on the wait. | 15 s watchdog releases the spinner, re-checks the stop, and shows a snackbar if nothing landed. |
| Check-in targeted `currentStopIndex`, which a late `StopSelected` could move. | `CheckInRequested(stopId:)` — the bloc checks in the exact stop the screen shows. |
| Tapping on a stop that was already checked in did nothing. | Goes straight to the visit. If the route isn't loaded yet, reloads once, then says so. |
| Final emit was built from the pre-`await` snapshot, rolling back GPS updates. | Built on the latest state. |
| Whole page — Google Map included — rebuilt on every GPS sample and every bloc emission. | Page `buildWhen` ignores GPS-only fields; header, banner and map each have their own location builder; the map rebuilds only when the position changes and sits in a `RepaintBoundary`. |
| Fade/slide entrance animated over the native map view; Expand button used `BackdropFilter` over it. Both are expensive platform-view compositing on iOS. | Map excluded from the entrance animation; blur replaced with a near-opaque card. |
| `geo_matchedTemplate` rendered without filling `{dist}`. | Filled. |
| `FontFeature.tabularFigures()` renders letter-spaced with the app font. | Removed. |
| In debug the verdict uses the static test position, but the map drew the simulator's own location (another continent) — the dotted line across a grey map. | The map uses the same static position while `kUseStaticCheckInPosition` is on. |

Debug builds still use the fixed test position (`kUseStaticCheckInPosition`),
so "0 m • ~1 min" and "Inside shop area" are expected there. Build in
`--profile` or `--release` to exercise real GPS.

---

# Fourth pass — "Locating You" never resolved (GPS check-in dead end)

**Symptom.** On a real handset the check-in dialog sat on *Locating You —
Waiting for a GPS fix* with only **Cancel**, forever. The header above it read
"0 m • ~1 min". No rep could check in.

## Root causes (four, stacked)

1. **The shared position stream starved the check-in screen.**
   `GeolocatorTrackingService.observe()` handed every caller one broadcast
   stream, created with whatever distance filter asked first. The Stop
   Dashboard opens first (25 m) and consumes the first fix. Check-in then calls
   `observe(10)`, silently gets the *same* 25 m stream, and — broadcast streams
   do not replay — a rep standing still in a shop never receives a single
   sample. Leaving check-in also called `stopObserving()`, killing the
   dashboard's stream underneath it.
2. **No fast first fix.** Only a high-accuracy stream; no cached position, no
   one-shot request, no coarse (Wi-Fi/cell) fallback. Indoors a satellite fix
   can take minutes or never come. Stream errors (Location switched off) were
   swallowed, so "off" looked identical to "searching".
3. **The dialog was frozen.** It was given a verdict computed once at tap time.
   No fix at that instant → a dialog that could never change and had no action
   but Cancel — while the bloc underneath would actually have accepted the
   check-in as unverified.
4. **Two different geofence rules.** The dialog measured against the outlet
   source (demo pin, 100 m); the bloc bridge measured `GeofenceService` against
   the depot pin and territory radius (urban 50 m). The dialog could say
   "within" and the bloc refuse "outside the geofence".

## What changed

| File | Change |
|---|---|
| `domain/services/location_fix_provider.dart` | **New.** `checkAvailability`, `lastKnownFix`, `currentFix(precise/coarse, timeout)`, service-status stream, open settings. Its own interface so existing `LocationTrackingService` fakes still compile. |
| `data/services/geolocator_tracking_service.dart` | Implements it. `observe()` is now per-listener, **replays** the last sample (≤ 2 min) to new listeners, runs the platform stream at the smallest filter requested, filters per listener, forwards errors, and is reference-counted — one screen closing cannot kill another's stream. |
| `presentation/bloc/state/location_tracking_state.dart` | `GpsFixStatus` (searching / acquired / servicesDisabled / permissionDenied(Forever) / unavailable), `searchStartedAt`, `currentReceivedAt`, `usableFix()` (≤ 5 min, measured by receipt time so GPS-clock skew cannot stale every fix). |
| `presentation/bloc/cubit/location_tracking_cubit.dart` | The **fix ladder**: cached fix + precise one-shot (8 s) + coarse one-shot (7 s) + live stream in parallel; 15 s watchdog → `unavailable`; auto-retry when Location is switched back on; `retryFix`, `refreshFix`, `openSettingsForStatus`. Picks the provider up from the tracking service — **no DI change**. |
| `presentation/models/check_in_gps_phase.dart` | **New.** One pure `CheckInGpsPhase.resolve(...)` + `CheckInReading`, rendered by header, banner and dialog alike. |
| `presentation/widgets/check_in_confirmation_dialog.dart` | **Rewritten, live.** Re-verifies on every fix, refreshes on open, and every phase has a way forward (table below). |
| `presentation/screens/stops_check_in_screen.dart` | Bloc bridge uses the **same** verifier as the dialog. Header chip says "Locating…" instead of a fake "0 m". Status banner gains retry / turn-on buttons. Re-searches on return from Settings. |
| `presentation/widgets/remote_check_in_sheet.dart` | Optional title / intro / presets / icon for the no-GPS variant; distance optional (never prints "0 m" for an unmeasured check-in). |
| `presentation/bloc/active_route_bloc.dart` | A reason given on an unverified (no-fix) check-in is **kept** on the row as `overrideReason` and logged as a `reasonedOverride` flag. |
| `domain/entities/fraud_policy.dart` | `maxAccuracyMeters` 30 → **50**. Indoor fused fixes report ±20–60 m; 30 refused reps standing inside the shop. Still half the 100 m radius. |
| `domain/services/outlet_location_source.dart` | ~~`kUseStopOutletPin`~~ — superseded: check-in now always measures against each stop's own pin; the office demo pin is an opt-in, debug-only shim (`--dart-define=USE_DEMO_OUTLET_PIN=true`, `kUseDemoOutletPin`). |

### Every dialog state now has an exit

| Phase | Primary action |
|---|---|
| Searching | waits, with progress bar, elapsed seconds, rotating tips |
| Within (or outlet has no pin) | **Confirm Check-In** |
| Weak signal / outside | **Continue with reason** (+ Refresh) |
| Location off | **Turn on location** → system settings, auto-resumes |
| Permission denied / blocked | **Allow location** / **Open settings** |
| No fix after 15 s | **Check in without GPS** — reason required, recorded unverified (+ Try again) |

### What did *not* change (anti-fraud)

No position is ever fabricated. Every fix is one the device reported, with its
own accuracy and mock flag. Mock-location and VPN rules are untouched and still
cannot be reasoned past. "Without GPS" is only offered after services are on,
permission is granted, and a full search found nothing — a rep cannot reach it
by denying permission. It always carries a written reason on the check-in row.

## UI / motion

- Dialog: scale-and-fade entrance with a soft overshoot; radar rings painted
  straight off the controller (no rebuilds at 60 fps); a celebratory ring +
  light haptic when the rep lands inside; distance counts up; a proximity track
  with a marker gliding to the rep's distance; animated signal bars; all
  content changes cross-fade and lift with one shared transition; the card
  resizes smoothly between states. No backdrop blur — animating blur is what
  stutters on mid-range Android.
- Screen: staggered entrance (header → map → board → CTA) on one ticker;
  header chip morphs between "Locating…" and the live distance; status pill
  shimmers while searching; CTA presses in under the finger.
- Reason sheet: preset chips highlight when selected; eased sheet entrance.

## Testing it

- Office test (debug only, opt-in): `flutter run --dart-define=USE_DEMO_OUTLET_PIN=true`.
  Stops are then measured against the demo pin (ISI office).
- Field test / default: stops are measured against their own synced pin in
  every build; `flutter run --release`.
- No-GPS path: switch Location off → dialog offers *Turn on location*; turn it
  on from the shade and it resumes by itself. For *without GPS*, test in a
  basement / airplane mode with Wi-Fi off and wait 15 s.

## Loose ends

- New strings are English literals marked `TODO(i18n)` (same convention as the
  reason sheet). Add en/km keys, then swap.
- Not compiled in this environment (no Flutter SDK available to me). All
  APIs used target **geolocator 11.1.0** (the pinned version) and Flutter ≥
  3.27. `getCurrentPosition` uses the 11.x `desiredAccuracy`/`timeLimit`
  parameters — 11.x has no `locationSettings:` there. Run `flutter analyze`
  once after merging.
- ~~The map's destination marker is the depot pin while the default verdict
  uses the demo pin~~ — resolved: the verdict now uses the depot pin too.

---

# Fixes in this pass

Two problems, one shared symptom: the push endpoint 400s the whole batch, so
nothing syncs.

```
status=400 errorCode=General.Validation
invalidFields=[StockUpdates[0].DepotId … StockUpdates[15].DepotId]
```

---

## 1. The `DepotId` 400

**What happened.** `General.Validation` with an `invalidFields` list is ASP.NET
`ModelState` — binding/annotation validation, which runs before any handler. It
flagged `DepotId` on *every* row, not a few, so the field itself was wrong for
all of them. Two client-side causes, both real:

- `_persistStockUpdates` set `depotId: resolvedStopId == null ? depotId : null`.
  With no stop resolved it put a **depot** id in the depot field.
- `VisitStockUpdateApiJson.toApiJson` emitted `'depotId': null` explicitly on
  the in-visit branch. The endpoint binds `DepotId` as required, so an explicit
  null fails before anything reads it.

Row counts 12 → 16 across the two log lines are 3 then 4 completed audits × the
4 demo items — each audit appends new rows (ids are stamped per run), none is
ever accepted, so the queue grows and re-sends everything each time.

**Fixed:**

| File | Change |
|---|---|
| `data/models/visit_api_mapper.dart` | `stopId`/`depotId` are omitted when null instead of sent as null. Omission is what the exactly-one invariant actually means. |
| `presentation/navigation/open_inventory_visibility.dart` | Never fabricates a `depotId` from a `depotId`. A count with no stop and no depot is not persisted, and says so in the log. |
| `presentation/screens/inventory_visible/inventory_visible_screen.dart` | New `kInventoryCatalogIsMock` flag. While set, audit rows are not persisted at all — the four demo products have ids `'1'`–`'4'` and a `productId` of `'1'` is the same failure one field over. |
| `data/repositories/visit_sync_repository_impl.dart` | Pre-flight quarantine: rows already in Drift from the old writer are retired locally instead of jamming the batch. **This is one-time cleanup — delete it once no install still carries those rows.** |

## 2. Nothing after check-in should be mandatory

Orders were never required — `CompleteVisitCheckOut` guards on one thing, the
stop being `checkedIn`. The problem was reachability: the only live "Complete
Visit" control sat behind the stock audit, and the audit's submit button was
disabled until all four items were judged. A rep who checked in and found the
shop shut had to invent four stock judgements to get out of the visit.

(Orders cannot be required in any case — `OrderCaptureForm`, `StockUpdateForm`,
`CollectionsForm` and `ReturnsForm` have zero references outside
`presentation/widgets/`. None is mounted on any screen.)

**Fixed:**

| File | Change |
|---|---|
| `presentation/screens/stop_information/stop_information_screen.dart` | The bottom bar is now status-aware. Not checked in → **Start Visit**. Checked in → **Start Visit** + **Complete Visit**. Resolved → a flat "Completed" marker. Status is read live from `ActiveRouteBloc`, not from the `RouteStop` snapshot the screen was built with. |
| `presentation/screens/inventory_visible/inventory_visible_screen.dart` | Submit is always enabled. Partial counts stay honest — unjudged items are skipped on persist, so a blank rack records as unjudged rather than as a guess. |

Complete Visit delegates to `endVisitAndSync`, which already sequences the
check-out write ahead of batch assembly. Dispatching `CheckOutRequested`
directly would lose that ordering.

## 3. `discardedIds` (OPEN-2)

Unread, a permanently-bad row looks like "in neither list", which the client
treats as rejected and retries forever.

| File | Change |
|---|---|
| `data/remote/visit_push_result.dart` | Adds `discardedIds` and `discardReasons`. |
| `data/remote/api_visit_sync_remote_data_source.dart` | Parses `discardedIds` and the `discarded[].errorCode` array, defensively — absent on an older backend, which degrades to empty. |
| `data/repositories/visit_sync_repository_impl.dart` | Discarded rows are retired from the queue and logged at warning with their error codes. `pushedCount` still counts only accepted rows. |

## 4. An empty delta could never recover (second pass)

`runDeltaSync` advanced the watermark on every successful call, including ones
that stored nothing. That made an empty route feed self-sustaining: each empty
pull moved `since` forward, the next delta asked about a narrower window, and a
delta cannot reach back past its own `since`. The only path back to a full pull
is `since == null`, which never happens again. A device that once pulled zero
routes pulls zero routes forever, with a 200 and a clean log every time.

| File | Change |
|---|---|
| `data/repositories/route_sync_repository_impl.dart` | An empty delta leaves the watermark where it was, so the window widens instead of creeping. If nothing is stored locally *either*, it escalates to `runInitialSync` — the only call that can see a route published before the watermark. |

Cost: one extra request per dashboard open while the rep genuinely has no
routes. An empty initial pull is a single page.

## 5. Check-in was refused every time (third pass)

`ActiveRouteBloc` registered a handler for `GeofenceStatusChanged` and **nothing
in the codebase ever dispatched it.** No screen or cubit bridged
`LocationTrackingCubit` to the bloc, and `GeofenceService.evaluate` was never
called against a live position.

Meanwhile `_onStopSelected` sets `insideGeofence: false` — and stop selection is
the step immediately before check-in. So by the time a rep tapped Check In the
flag was false with nothing in existence that could set it true, and
`validateCheckIn` refused with "You're outside the depot's geofence" at any
distance, including inside the shop.

Two things hid it. The banner OR'd in `kDebugForceInsideGeofence = true`, which
the bloc never read — green on screen, refused underneath. And `_submit`
dispatched and navigated in the same breath, so the rep advanced into the stock
count whether or not the check-in landed. That is the whole chain behind
`visit.checkout.skipped reason=noActiveWorkflow`: no check-in, so no workflow
pointer, so nothing to check out and nothing to push.

| File | Change |
|---|---|
| `presentation/screens/stops_check_in_screen.dart` | Adds the missing listener: every GPS sample is run through `GeofenceService` and dispatched as `GeofenceStatusChanged`. Seeded once in `initState` too, since the listener only fires on change and a stationary device may not produce one. |
| `presentation/screens/stops_check_in_screen.dart` | `_submit` now waits for the verdict. `_onCheckInSettled` navigates when the stop actually reaches `checkedIn`, and stays on the screen showing `blockedCheckInReason` when it does not. |
| `presentation/screens/stops_check_in_screen.dart` | `kDebugForceInsideGeofence` is now `false`. Nothing depends on it any more. |
| `presentation/bloc/events/active_route_event.dart` | `GeofenceStatusChanged` carries `depotLocationKnown`, so an ungeotagged shop is distinguishable from a rep who is genuinely elsewhere. |
| `presentation/bloc/state/active_route_state.dart` | Adds `repLatitude`, `repLongitude`, `depotLocationKnown`, `hasFix`. |
| `presentation/bloc/active_route_bloc.dart` | No GPS fix, or a depot with no pin, now records the visit as **unverifiable** (a warning on the row) instead of refusing it — which is what api.md §8.2 asks for. The geofence handler no longer requires `dayStarted`, another silent-block path. |

## 6. Check-in and check-out recorded the shop's position as the rep's

`latitude`/`longitude` on both records were `stop.depot.latitude/longitude`.
Those fields are the location evidence the server judges a visit on (api.md
§8.2), so every check-in arrived reading as exactly on-location, from anywhere,
by anyone. The anti-fraud check was structurally incapable of catching anything.

| File | Change |
|---|---|
| `presentation/bloc/active_route_bloc.dart` | Both records use the rep's tracked position, falling back to the depot pin only when there is no fix — and that row is already flagged unverified. |
| `domain/usecases/complete_visit_check_out.dart` | Takes an optional `FetchLocationSamples` and uses the newest sample on the route. **Needs one line in `my_visits_injection.dart`** to pass it, or every check-out keeps falling back to the pin and logs `visit.checkout.position_unavailable reason=notWired`. |

---

# New feature: reasoned check-in override

**The problem.** The geofence assumes two things a depot routinely breaks: that
the shop's recorded pin is somewhere the rep can stand, and that a handset can
get a clean fix there. A yard entrance a hundred metres from the office pin, or
a warehouse under a steel roof, fails both while the rep is demonstrably doing
their job. Before this, that rep simply could not check in.

**The shape.** Check in anyway, but say why — and the reason is mandatory, not
optional. A rep who taps past the geofence with no explanation destroys the only
evidence that the visit happened where it claims to and leaves nothing in its
place. A written reason does not prove presence — nothing on the device can —
but it makes the override attributable.

| File | Change |
|---|---|
| `domain/entities/fraud_policy.dart` | `allowReasonedCheckInOverride` (default on) and `minOverrideReasonLength` (default 10). Turn the first off for a territory where every stop is reliably geotagged. |
| `domain/services/fraud_detection_service.dart` | `CheckInValidation` now separates `overridableReasons` (geofence, accuracy) from `integrityReasons` (mock location, VPN), with `canOverrideWithReason` on top. |
| `presentation/bloc/events/active_route_event.dart` | `CheckInRequested({overrideReason})`. |
| `presentation/bloc/state/active_route_state.dart` | `checkInOverridable`, so the screen knows whether to offer the sheet without matching on message text. |
| `presentation/bloc/active_route_bloc.dart` | Accepts a reason of sufficient length past the location rules only, and records a `FraudFlag(reasonedOverride)` when it does. |
| `domain/entities/fraud_flag.dart` | New `reasonedOverride` type. Safe to add — both readers resolve the name defensively. |
| `presentation/widgets/remote_check_in_sheet.dart` | **New.** The reason sheet: four one-tap prefills, a free-text field, and a CTA disabled until the minimum length is met. |
| `presentation/screens/stops_check_in_screen.dart` | Offers the sheet when the block is overridable, writes the reason as a `VisitNote` **before** re-dispatching check-in, then retries with the reason. |

**What reaches the server.** The reason rides on the check-in row itself as
`overrideReason`, beside the verdict it explains — not as a separate note. Two
rows would put the verdict and its explanation in different tables, and a
reviewer asking "which overrides happened and why" would be joining a flagged
check-in to free text somebody hoped was there.

| File | Change |
|---|---|
| `domain/entities/check_in_record.dart` | `overrideReason` (nullable). |
| `data/models/check_in_record_model.dart` | Row mapping both ways. |
| `data/local/visit_drift_mappers.dart` | Drift companion + row mapping. |
| `data/models/visit_api_mapper.dart` | Emits `overrideReason` only when set — absent means "nobody was asked to explain this row", which is not the same as an override whose reason went missing. |

The check-in row still reports its true `distanceFromDepot`, and the server
recomputes its own `GeofenceVerdict` from the coordinates regardless. **The
server was already storing out-of-geofence check-ins rather than refusing them**,
so the client was the only thing refusing them first.

### ⚠️ One change is outside this folder and this will not compile without it

`visit_tables.dart` (the Drift table definitions) is not in this archive. Add a
nullable text column to `VisitCheckIns`:

```dart
TextColumn get overrideReason => text().nullable()();
```

then `dart run build_runner build --delete-conflicting-outputs` and bump the
Drift schema version with a migration step. `visit_drift_mappers.dart` already
reads and writes it.

**What the override cannot do.** It never clears an integrity block. A mock
location provider or a VPN keeps the check-in refused however good the
explanation — those are claims about whether the device is telling the truth,
and a free-text box cannot answer them.

**Note on the offline framing.** Check-in already worked with no internet — every
capture is local-first and `/push` drains later. The rule that actually blocked
reps at depots was the geofence, and poor GPS underneath it. That is what this
addresses.

**Loose end:** the sheet's strings are English literals with a `TODO(i18n)`.
Written that way on purpose — `.tr` on a key that does not exist yet renders the
key itself on a rep's screen. Add the en/km entries, then swap them.

---

## Not fixed here

- **Retiring a row reuses `markSynced`, which overstates what happened** — the
  row left the queue but never reached the server. An honest
  `sync_status = 'discarded'` needs a table migration in the DAO layer, which is
  outside this folder.
- **The server 4xxs the whole envelope on a row-level fault.** api.md §6.1
  reserves 4xx for an unusable envelope and says explicitly: never because of an
  individual row. Until that is corrected server-side, one bad capture can still
  stall an entire day's sync. Everything above reduces the odds of producing one;
  none of it removes the failure mode.
- **`DepotStockCountCubit` is still dead wiring**, and the audit screen still
  renders mock data. Wiring it is what makes `kInventoryCatalogIsMock = false`
  possible, and until then stock counts do not sync at all.
- **`NavigationStateCubit.checkOut()` and `ResumableVisitCubit.checkOut()` are
  still uncalled.** The new bar uses `endVisitAndSync` instead. Wire or delete
  them; two dead check-out paths invite a third.
- Photo upload (§6.2), telemetry (§6.3) and `depots[].hasLocation` are
  untouched.
