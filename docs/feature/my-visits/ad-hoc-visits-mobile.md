# Ad Hoc Visits — Mobile Build Guide

> **For:** the Flutter team, building the "add a depot to today" action in
> `lib/features/my_visits/`.
> **Backend status:** shipped and tested (40 new tests). Migration written, **not
> yet applied** — see §9.
> **Contract:** [api.md §5.3](api.md). This document is the build order; api.md is
> the reference.

---

## 1. What you are building

A rep is working their route. They decide to call on a depot nobody planned —
they were passing, a customer rang, a competitor's truck was outside. They add
it, and it appears at the bottom of today's visits, ready to check in to.

```
Today's Visits — 29 Sep

  1  Angkor Hardware        callPlan   ✓ checked out
  2  Mekong Steel Supply    callPlan   ● checked in
  3  Boeung Trabek Depot    callPlan     pending
  ─────────────────────────────────────────────────
  +  Toul Kork Yard         adHoc        pending     ← added 14:32
```

### The one rule

> **An ad hoc visit is an execution record, not a change to the Call Plan.**

Stops 1–3 keep their ids, their order and their planned times. Nothing about the
plan moves. The ad hoc visit sits beside them and walks the **same** lifecycle —
`pending → checkedIn → checkedOut` — through the **same** check-in, geofence,
photo, stock and push code you already have.

`visitSource` is *where the stop came from*. `status` is *what happened*. They are
different fields on purpose: "an ad hoc visit that has been checked out" has to be
representable, and a `status` of `adHoc` would have made it impossible.

---

## 2. ⚠️ Read this before anything else

**Your current parser will throw on an ad hoc stop.**

[`route_stop_model.dart`](../../../../frontend/lib/features/my_visits/data/models/route_stop_model.dart)
does this:

```dart
plannedArrival: DateTime.parse(json['plannedArrival'] as String),
plannedDeparture: DateTime.parse(json['plannedDeparture'] as String),
```

An ad hoc visit has **no planned window** — nobody scheduled it, and the backend
refuses to invent one. Those two fields arrive as `null`, the cast to `String`
throws, and **the whole route sync transaction fails** — not just that stop. The
rep loses their entire day, not one card.

So §3 is not optional and it is not part of the feature work. **Ship the parser
change first, on its own, before anyone taps anything.** Then the feature can land
whenever it lands.

You are safe until the first ad hoc visit exists, and one can only exist once
someone calls the endpoint — so there is no live incident waiting. But an old
build on a rep's phone will break the moment a colleague with a new build adds a
visit to a shared depot. Treat the parser fix as a forced update.

---

## 3. Step 1 — make the planned window nullable (do this first)

Three files, no feature code.

### 3.1 Domain entity

`lib/features/my_visits/domain/entities/route_stop.dart`

```dart
class RouteStop extends Equatable {
  const RouteStop({
    required this.id,
    required this.routeId,
    required this.customer,
    required this.sequence,
    required this.plannedArrival,     // now DateTime?
    required this.plannedDeparture,   // now DateTime?
    required this.status,
    this.visitSource = VisitSource.callPlan,   // ← new, defaulted
    this.actualArrival,
    this.actualDeparture,
  });

  /// Null on an ad hoc visit — nobody planned it. Always present on a
  /// callPlan stop, exactly as before.
  final DateTime? plannedArrival;
  final DateTime? plannedDeparture;

  /// Where the stop came from. Not a status: see [status].
  final VisitSource visitSource;

  bool get isAdHoc => visitSource == VisitSource.adHoc;
```

Keep `visitSource` defaulted to `callPlan` so every existing construction site
still compiles. That is deliberate — it is also what the server does for every row
written before this feature existed.

New file, `lib/features/my_visits/domain/entities/visit_source.dart`:

```dart
/// Where a stop came from. Decided once, never changes.
enum VisitSource { callPlan, adHoc }
```

### 3.2 Model

`lib/features/my_visits/data/models/route_stop_model.dart` — all three
serialisers:

```dart
// fromJson
plannedArrival: json['plannedArrival'] == null
    ? null
    : DateTime.parse(json['plannedArrival'] as String),
plannedDeparture: json['plannedDeparture'] == null
    ? null
    : DateTime.parse(json['plannedDeparture'] as String),
// Falls back to callPlan on anything unrecognised — the documented fallback.
// Reading an unknown origin as adHoc would show a planned call as one the rep
// invented, which is the worse way to be wrong.
visitSource: VisitSource.values.byNameOr(
    json['visitSource'] as String?, VisitSource.callPlan,
    context: 'stop.json.visitSource'),

// fromRow — same shape, snake_case keys, `visit_source`

// toRow
'planned_arrival': plannedArrival?.toIso8601String(),
'planned_departure': plannedDeparture?.toIso8601String(),
'visit_source': visitSource.name,
```

`byNameOr` is the existing helper in `core/utils/enum_parse.dart` — same one
`status` already uses.

### 3.3 Local database

`lib/core/database/drift/tables/route_tables.dart`:

```dart
DateTimeColumn get plannedArrival => dateTime().nullable()();
DateTimeColumn get plannedDeparture => dateTime().nullable()();
TextColumn get visitSource => text().withDefault(const Constant('callPlan'))();
```

Then bump `kCurrentSchemaVersion` from **17 → 18** in
`lib/core/database/drift/migrations/schema_migrations.dart` and add the step.

> **⚠️ SQLite cannot drop a NOT NULL constraint with `ALTER TABLE`.** Adding
> `visit_source` is a plain `addColumn`; making the two datetime columns nullable
> needs a **table rebuild** via drift's `TableMigration`, which copies the rows.
> Do not reach for `_addColumnIfMissing` for that half — it will silently do
> nothing and the column will still reject nulls at runtime.

```dart
Future<void> _v17to18(Migrator m, AppDatabase db) async {
  // Additive: every existing stop is a Call Plan stop, which is what they all are.
  await _addColumnIfMissing(m, db, db.routeStops, db.routeStops.visitSource);

  // Not additive. SQLite has no DROP NOT NULL, so the table is rebuilt and the
  // rows copied. Nothing is transformed — the columns keep their values and
  // merely stop being required.
  await m.alterTable(TableMigration(db.routeStops));
}
```

Run `dart run build_runner build --delete-conflicting-outputs` after editing the
table, and **add a migration test that opens a v17 database with stops in it and
upgrades** — a rebuild that loses rows is the classic way to wipe a rep's day.

### 3.4 Anywhere that reads the fields

Search for `plannedArrival` and `plannedDeparture` across the feature. Every
read site now needs a decision, and the right one is almost always *show nothing*
rather than *show a substitute*:

| Site | Do |
|---|---|
| Stop card time label | `stop.plannedArrival?.let(format) ?? '—'`, or hide the row |
| "Running late" / ETA logic | Skip the check entirely when null — an unplanned visit cannot be late |
| Day-duration or capacity sums | Contribute **0**. The backend does the same: an ad hoc visit adds no *planned* minutes |
| Sorting by planned time | Fall back to `sequence` (§5) |

---

## 4. Step 2 — the endpoint

```http
POST /api/v1/mobile/visits/ad-hoc
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "sk": "1000123",
  "clientRequestId": "adhoc-7f3c1e9a-2b44-4d51-8c0f-19ab22d7e6f5"
}
```

| Field | Required | Notes |
|---|---|---|
| `sk` | ✅ | The depot's **SAP depot code**, ≤10 chars. Read it from `sapDepotsCode` on the depot payload — **not** `id`, and **not** `code`. |
| `clientRequestId` | ✅ | ≤128 chars. Generate **once per user tap** and persist it; reuse on every retry. |
| `visitDate` | ❌ | **Do not send it.** The server derives today. See §7. |

There is **no `repId` field**, and there never will be. The rep comes from the
bearer token.

### ⚠️ Two consequences of keying on the SAP code

**1. You need a new field locally.** `sapDepotsCode` is now on every
`CustomerStopInfo` the route sync sends — it was not there before. Add it to
`CustomerStopInfoModel`, the `customers` drift table and the entity in the same
pass as §3, or you will have nothing to put in `sk`.

**2. Depots SAP has not reported back cannot be added at all.** `sapDepotsCode`
is **null** for depots captured in the field. There is no value you could send
that would find one, so **disable the "add visit" action when
`depot.sapDepotsCode == null`** rather than letting the rep tap it and receive a
`Visit.DepotNotFound` for a depot sitting in their own list.

```dart
bool canAddAdHoc(CustomerStopInfo depot) => depot.sapDepotsCode != null;
```

### Response — 200

```json
{
  "data": {
    "stop": {
      "id": "0199a2f2-1d04-7a88-b3e1-6c5f2093ab77",
      "routeId": "0199a2f0-44ab-7c19-8f52-71de0c9b3a10",
      "customerId": "0199a2f1-6b3d-7c41-9e02-5d8b7a1c4e30",
      "sequence": 1001,
      "plannedArrival": null,
      "plannedDeparture": null,
      "status": "pending",
      "actualArrival": null,
      "actualDeparture": null,
      "departureInferred": false,
      "visitSource": "adHoc"
    },
    "visitDate": "2026-09-29",
    "depot": { "id": "…", "name": "Toul Kork Yard", "…": "full CustomerStopInfo" },
    "created": true
  },
  "message": "Ad hoc visit added to today.",
  "metadata": {}
}
```

`data.stop` is the **ordinary `RouteStop`** shape you already parse — feed it
straight to `RouteStopModel.fromJson`. `data.depot` is a full `CustomerStopInfo`,
sent because the depot was not on the plan and so may not be in the device's
current route payload at all.

`routeId` may name a route you have never seen: a rep with no Call Plan for today
gets one opened for them. Upsert the stop and let the next delta fill in the route
header, or re-sync immediately — §6.

### Data source

Follow `ApiCustomerRemoteDataSource` — `Dio`, `ApiEnvelope.fromBody`, `ApiError`.

```dart
/// `POST /api/v1/mobile/visits/ad-hoc` — add a depot the Call Plan missed.
class ApiAdHocVisitRemoteDataSource implements AdHocVisitRemoteDataSource {
  const ApiAdHocVisitRemoteDataSource(this._client);

  final Dio _client;

  @override
  Future<AdHocVisitResult> create({
    required String depotId,
    required String clientRequestId,
  }) async {
    try {
      final response = await _client.post<Object?>(
        '/api/v1/mobile/visits/ad-hoc',
        // visitDate is deliberately absent: the server owns the day.
        data: {'depotId': depotId, 'clientRequestId': clientRequestId},
      );

      final envelope = ApiEnvelope.fromBody(response.data);
      final depot = CustomerStopInfoModel.fromJson(
          envelope.data['depot']! as DataMap);

      return AdHocVisitResult(
        stop: RouteStopModel.fromJson(
            envelope.data['stop']! as DataMap, customer: depot),
        depot: depot,
        visitDate: DateTime.parse(envelope.data['visitDate']! as String),
        // False when the server replayed an earlier attempt. Still a success.
        created: envelope.data['created'] as bool? ?? true,
      );
    } on DioException catch (error) {
      throw ServerException.fromApiError(ApiError.fromDioException(error));
    }
  }
}
```

Register it in `lib/features/my_visits/my_visits_injection.dart` alongside the
other sources.

---

## 5. Ordering — you need no special case

Ad hoc visits carry `sequence` **≥ 1001**; Call Plan stops occupy 1..100. The
band is above every planned position, so:

- **Sorting by `sequence` already puts ad hoc visits last.** No filter, no
  partition, no second list. This is why the backend uses a band rather than
  "next free number".
- **GPS-distance sorting is unaffected.** When a fix exists you already override
  sequence; keep doing that for both kinds alike. A rep parked outside an
  unplanned depot should see it first.
- **Do not render the raw number.** `1001` is an ordering device, not a position.
  Show `+` or an "Ad hoc" chip where a planned stop shows its number.

The backend guarantees a planned stop added *after* an ad hoc visit still lands
inside 1..100, so the plan never ends up behind an improvisation.

---

## 6. Sync — nothing new to build

The visit reaches other devices through the **existing** delta. A new stop is a
change to its route, so `GET /routes/delta` returns the whole current set as it
always has. There is no second sync path and no new watermark.

After a successful create, the cheapest correct thing is:

```
POST ad-hoc  →  200  →  upsert stop + depot locally  →  trigger RouteSyncCubit.refresh()
```

Upsert first so the card appears immediately; refresh so the route header for a
newly opened day arrives. Do not block the UI on the refresh.

---

## 7. Offline — the honest part

> **Creating an ad hoc visit requires connectivity. Nothing else about it does.**

This is the one place the offline-first contract does not hold, and it is a
property of the operation rather than a gap in the API: the server owns stop ids,
and the depot may not be in the downloaded route at all, so there is no id to
check in against until the server has issued one.

**Everything after creation is offline as usual** — check in, geofence, photos,
stock counts, check out, push. Once the stop exists it is an ordinary stop.

### What to build

```
tap "Add visit"
   → generate clientRequestId (uuid v4), persist it with the pending request
   → POST
       ├─ 200 .................. upsert, show the card, done
       ├─ network / 5xx / timeout ... keep queued, retry with the SAME id
       └─ 4xx business error ....... drop from the queue, tell the rep (§8)
```

- **Persist `clientRequestId` before the first attempt**, not per attempt. A new
  id on retry is a new visit, which is exactly the duplicate the field exists to
  prevent.
- **The queue is safe to drain twice.** Same id → the server returns the original
  visit with `created: false`. Treat that as success.
- **Do not show an optimistic card.** You have no stop id, so there is nothing to
  check in to; a card the rep can tap and that does nothing is worse than a
  spinner. Show the request as pending instead — "Adding Toul Kork Yard…" — and
  turn it into a real card on the 200.

---

## 8. Errors — branch on `errorCode`, never on status

All of these arrive as RFC 9457 problem documents, so `ApiError.code` is
populated the usual way.

| `errorCode` | HTTP | What happened | What the rep should see |
|---|---|---|---|
| `Visit.DepotAlreadyPlanned` | 409 | Already on today's Call Plan | *"That depot is already on today's route."* — and **navigate them to the existing stop**. This is the most likely error in practice and the most recoverable |
| `Visit.AdHocAlreadyExists` | 409 | They already added it today | Same: take them to the card they already have |
| `Visit.DepotNotFound` | 404 | No depot with that SAP code, **or** not theirs | *"That depot isn't available to you."* Do not say "does not exist" — the two cases are deliberately conflated so the endpoint can't be used to probe codes. The **server log** says which, by correlation id |
| `Visit.DepotCodeAmbiguous` | 409 | Two depots share that SAP code | *"That depot needs to be fixed in the system."* Not something the rep can resolve — surface the correlation id for support |
| `Visit.DepotNotAccessible` | 403 | Theirs, but not trading | *"That depot is suspended and can't be visited."* |
| `Visit.AdHocDateInvalid` | 400 | You sent a `visitDate` that isn't today | A bug in the client — you should not be sending it at all |
| `Visit.RepNotAuthorized` | 403 | Signed in, but not a field rep | Hide the action for this account entirely. **A 403 must not sign the user out** |
| `Visit.TerritoryNotAssigned` | 422 | No territory on their profile | *"Ask an administrator to set your territory."* |
| `Visit.AdHocNotAllowed` | 422 | Day is at the 100-stop limit | *"Today's route is full."* |

The two 409s are **not failures from the rep's point of view** — the depot is on
their day either way. Treat them as "already done" and route to the stop, not as
red error toasts.

A lost race between two simultaneous retries can produce one 5xx; the next retry
with the same id returns the winner's visit. That is the queue working, not an
incident.

---

## 9. Before you can test end to end

Two things are outside the Flutter repo.

1. **The backend migration is written but not applied.**
   `20260929073827_AddAdHocVisits`. Until it runs, the endpoint 500s on the new
   columns. Coordinate with whoever owns the environment.

2. **Routes are still mock-only in this app.** There is no
   `ApiRouteRemoteDataSource` — `lib/features/my_visits/data/remote/` contains
   `MockRouteRemoteDataSource` and nothing else, and no file in `lib/` references
   `/api/v1/mobile/visits/routes`.

   > The backend's own [workflow.md §8](workflow.md) states that
   > `ApiRouteRemoteDataSource` is live and mock routes were removed. **That is
   > not true of the code as it stands** — it describes intended state. Flagging
   > it rather than quietly working around it, because it changes the plan: ad hoc
   > visits cannot be exercised against real data until the route pull is wired to
   > the API, and a mock route has no server-side route to attach a visit to.

   If you want the feature demoable sooner, `MockRouteRemoteDataSource` can serve
   ad hoc stops locally — but that proves the UI, not the integration.

---

## 10. Definition of done

**Parser hardening (ship separately, first):**

- [ ] `RouteStop.plannedArrival` / `plannedDeparture` nullable; `visitSource` added, defaulted
- [ ] All three serialisers in `route_stop_model.dart` handle null and read `visitSource`
- [ ] Drift schema 17 → 18: `visit_source` added, two columns rebuilt nullable
- [ ] **Migration test**: open a v17 database holding stops, upgrade, assert no rows lost
- [ ] Every `plannedArrival` read site handles null (§3.4) — no `!` anywhere
- [ ] Parsing a payload with `"plannedArrival": null` does not throw

**Feature:**

- [ ] Depot picker excludes depots already on today's route (both sources)
- [ ] `clientRequestId` generated once per tap and persisted before the first send
- [ ] Retry reuses the id; `created: false` is treated as success
- [ ] Offline: request queues, no optimistic card, drains on reconnect
- [ ] All eight error codes handled; both 409s navigate to the existing stop
- [ ] Ad hoc card shows a chip, not `1001`, and no planned time
- [ ] Sorting by sequence puts it last; GPS sorting still overrides
- [ ] **Check in and check out of an ad hoc visit** via the existing flow — no new code should have been needed
- [ ] Route delta after creation returns the visit and does not duplicate it

---

## 11. Reference

| | |
|---|---|
| Endpoint contract | [api.md §5.3](api.md) |
| Why it is built this way | [backend-integration.md §3.1](backend-integration.md) |
| Client-side behaviour notes | [workflow.md §8.1](workflow.md) |
| House API pattern to copy | `lib/features/customers/data/remote/api_customer_remote_data_source.dart` |
| Envelope / error helpers | `lib/core/network/api_envelope.dart`, `lib/core/network/api_error.dart` |
| DI | `lib/features/my_visits/my_visits_injection.dart` |
