# List Depots — Mobile

**Purpose:** the paged depot list and the offline synchronisation contract.
**Scope:** `GET /api/v1/mobile/depots`.
**Status:** Active · **Last updated:** 2026-08-28

One endpoint serves two jobs: rendering a list screen, and replicating the
representative's depot book onto the device. The difference is one parameter,
`modifiedSince`.

---

## Contents

1. [The request](#the-request)
2. [The response](#the-response)
3. [Flow: SAP → backend → mobile](#flow-sap--backend--mobile)
4. [First sync](#first-sync)
5. [Delta sync](#delta-sync)
6. [Tombstones](#tombstones)
7. [The watermark rules](#the-watermark-rules)
8. [Local schema](#local-schema)
9. [Full implementation](#full-implementation)
10. [Checklist](#checklist)

---

## The request

```
GET /api/v1/mobile/depots?pageNumber=1&pageSize=200
Authorization: Bearer <access_token>
Accept-Language: km-KH
```

Requires `depots.read`. A representative sees the depots assigned to them; a
holder of `depots.readall` sees the whole territory. Scoping is applied in the
query handler, so it holds on every route and for background jobs too — the client
cannot widen it.

All parameters are in [filter-depot.md](filter-depot.md). This page covers
`pageNumber`, `pageSize`, `modifiedSince` and `includeDeleted`.

---

## The response

```json
{
  "success": true,
  "message": "ទាញយកបញ្ជីអតិថិជនបានជោគជ័យ។",
  "data": {
    "depots": [ { "…": "23 fields per row" } ],
    "syncTimestamp": "2026-08-28T08:31:52Z"
  },
  "metadata": {
    "page": 1,
    "pageSize": 200,
    "totalRecords": 6010,
    "totalPages": 31,
    "hasNextPage": true,
    "hasPreviousPage": false,
    "syncTimestamp": "2026-08-28T08:31:52Z",
    "isDeltaSync": false
  },
  "traceId": "0HNO1GJO3S25N:00000001",
  "timestamp": "2026-08-28T08:31:52Z"
}
```

`syncTimestamp` appears twice, in `data` and in `metadata`, with the same value. Read
whichever you prefer and be consistent.

**`pageSize` is clamped, not rejected.** Ask for 10,000 and you get 200 with no
error. Always read `metadata.pageSize` back rather than assuming you got what you
asked for — the page arithmetic depends on it.

### The row

23 fields, roughly a fifth of the full depot, chosen so a list row and a map pin
need no second request:

```json
{
  "id": "01a03189-9670-7599-98ac-45ebaf277899",
  "depotCode": "6100000017",
  "sapDepotId": "6100000017",
  "shopName": "ដេប៉ូ​​​ រស្មី សៀមរាប",
  "ownerName": null,
  "phone": "012345678",
  "city": "Siem Reap",
  "district": null,
  "territory": null,
  "latitude": null,
  "longitude": null,
  "type": "Retailer",
  "status": "Active",
  "statusDisplay": "សកម្ម",
  "canTrade": true,
  "creditLimit":   { "amount": 0.0, "currency": "USD" },
  "creditBalance": { "amount": 0.0, "currency": "USD" },
  "lastVisitDate": null,
  "lastOrderDate": null,
  "assignedRepId": null,
  "updatedAt": "2026-08-28T03:00:11Z",
  "deleted": false
}
```

`shopName` and `statusDisplay` are already localised — see
[mobile.md](mobile.md#localisation). Branch on `status`, render `statusDisplay`.

---

## Flow: SAP → backend → mobile

```mermaid
sequenceDiagram
    autonumber
    participant SAP as SAP ERP
    participant Job as sap-depot-sync (02:00 UTC)
    participant DB as PostgreSQL
    participant API as ISI API
    participant App as Flutter app
    participant SQLite as Device SQLite

    Note over SAP,DB: 1 — ingestion, nightly and unattended
    Job->>SAP: POST /api/Auth/Login
    SAP-->>Job: JWT (cached ~55 min)
    Job->>SAP: GET /api/Depot/GetCustByPaging/{conId}
    SAP-->>Job: rows — one per depot × sales area × company code
    Job->>Job: collapse to one row per depot number
    Job->>DB: upsert; sets updated_at via interceptor

    Note over App,SQLite: 2 — replication, on the rep's device
    App->>API: GET /mobile/depots?modifiedSince=<watermark>
    API->>DB: scoped + filtered query, projected in SQL
    DB-->>API: page
    API-->>App: rows + metadata.syncTimestamp (server clock)
    App->>SQLite: upsert live rows, delete tombstones
    App->>App: store watermark only after the run commits
```

**The two halves are independent.** SAP's clock never reaches the device: the
watermark you store is the *platform's* `updated_at` horizon, stamped by the API. A
depot changed in SAP becomes visible to the app only after the nightly job has
written it, which is why `updatedAt` on a row is the platform's timestamp and not
SAP's.

**Sync is one-directional for SAP-owned data.** The device never pushes a change back
to SAP through this endpoint. Field registration is a separate path — see
[create-depot.md](create-depot.md).

---

## First sync

Omit `modifiedSince`. Page with `pageSize=200`. At 6,010 depots that is 31
requests.

```dart
Future<void> firstSync() async {
  var page = 1;
  String? watermark;

  await db.transaction((txn) async {
    while (true) {
      final res = await api.get('/mobile/depots', queryParameters: {
        'pageNumber': page,
        'pageSize': 200,
      });
      final body = res.data;

      // Capture from the FIRST page. Later pages carry a later clock, and using
      // the last one would skip anything written mid-run.
      watermark ??= body['metadata']['syncTimestamp'];

      await txn.upsertAll(body['data']['depots']);

      if (body['metadata']['hasNextPage'] != true) break;
      page++;
    }
  });

  await prefs.setString('depots_watermark', watermark!);
}
```

> **Take the watermark from the first page, not the last.** A run over 31 pages takes
> time, and rows written while you were paging carry a timestamp between the first
> and last page's clocks. Storing the last page's clock silently skips them — they
> are never returned again. The first page's clock re-delivers a few rows you already
> have, which an upsert makes harmless.

---

## Delta sync

Send the stored watermark:

```
GET /api/v1/mobile/depots?modifiedSince=2026-08-28T08:31:52Z&pageSize=200
```

Returns only rows changed at or after that instant, **including soft-deleted ones**.
`metadata.isDeltaSync` is `true`, which is worth asserting on.

Two server behaviours you can rely on:

- **New records are matched on `createdAt` when `updatedAt` is null.** A depot
  registered since your last sync is included; you do not need a second query.
- **A delta is ordered by change time.** A client interrupted halfway can resume from
  the last row it stored rather than restarting.

After the nightly job runs, expect a large delta — the job touches every row it
reconciles, so `updated_at` moves even where nothing changed. Do not assume a delta
is small.

---

## Tombstones

A delta includes deleted depots with `deleted: true`. Act on them:

```dart
for (final row in body['data']['depots']) {
  if (row['deleted'] == true) {
    await txn.delete('depots', where: 'id = ?', whereArgs: [row['id']]);
  } else {
    await txn.upsert('depots', row);
  }
}
```

Without this a depot deleted on the server stops appearing in future deltas and
stays on the phone forever — the classic offline-sync data leak. It is also a real
disclosure problem: a shop removed because the relationship ended remains visible and
orderable on every device that synced before the deletion.

`includeDeleted=true` forces tombstones on a non-delta request. `modifiedSince`
implies it, so a delta always carries them.

---

## The watermark rules

Four rules. Each one exists because breaking it produces a silent failure.

**1 — It comes from the server, never the device.** A phone ten minutes fast would
store a future watermark, ask for changes since the future, get an empty delta
forever, and never sync again. Nothing would look broken. The server rejects a
`modifiedSince` more than five minutes ahead of its own clock:

```json
{ "status": 400, "errorCode": "General.Validation",
  "errors": { "parameters.modifiedSince": ["modifiedSince cannot be in the future. …"] } }
```

**2 — Store it only after the whole run commits.** Advance it per page and an
interrupted sync leaves a gap between the last committed page and the stored
timestamp.

**3 — Apply the run in one transaction.** A partially applied delta with an advanced
watermark is unrecoverable without a full resync.

**4 — Keep it verbatim.** Store the exact string. Re-formatting through a local
`DateTime` can lose sub-second precision and re-deliver or skip boundary rows.

```dart
// Correct
await prefs.setString('depots_watermark', body['metadata']['syncTimestamp']);

// Wrong — precision loss on the round trip
await prefs.setString('depots_watermark',
    DateTime.parse(body['metadata']['syncTimestamp']).toIso8601String());
```

---

## Local schema

```sql
CREATE TABLE depots (
  id             TEXT PRIMARY KEY,
  depot_code  TEXT NOT NULL,
  sap_depot_id TEXT,
  shop_name      TEXT NOT NULL,
  owner_name     TEXT,
  phone          TEXT,
  city           TEXT,
  district       TEXT,
  territory      TEXT,
  latitude       REAL,
  longitude      REAL,
  type           TEXT NOT NULL,
  status         TEXT NOT NULL,          -- branch on this
  status_display TEXT NOT NULL,          -- display only; language-dependent
  can_trade      INTEGER NOT NULL,
  credit_limit_amount   REAL,
  credit_limit_currency TEXT,
  credit_balance_amount REAL,
  last_visit_date TEXT,
  last_order_date TEXT,
  assigned_rep_id TEXT,
  updated_at      TEXT,
  synced_language TEXT NOT NULL          -- which locale the localised text came from
);

CREATE INDEX ix_depots_territory ON depots(territory);
CREATE INDEX ix_depots_status    ON depots(status);
CREATE INDEX ix_depots_shop_name ON depots(shop_name);
```

**`synced_language` is not optional.** `shop_name` and `status_display` are
server-localised, so a book synced under `en-US` holds English names. If the user
switches language you must re-sync from scratch — a delta will not rewrite rows that
have not changed on the server:

```dart
if (prefs.getString('synced_language') != currentLocale) {
  await prefs.remove('depots_watermark');   // force a full resync
}
```

---

## Full implementation

```dart
Future<SyncOutcome> syncDepots({bool force = false}) async {
  if (force || prefs.getString('synced_language') != currentLocale) {
    await prefs.remove('depots_watermark');
  }

  final watermark = prefs.getString('depots_watermark');
  var page = 1;
  String? nextWatermark;
  var upserted = 0, removed = 0;

  try {
    await db.transaction((txn) async {
      while (true) {
        final res = await api.get('/mobile/depots', queryParameters: {
          'pageNumber': page,
          'pageSize': 200,
          if (watermark != null) 'modifiedSince': watermark,
        });

        final body = res.data;
        nextWatermark ??= body['metadata']['syncTimestamp'];

        for (final row in body['data']['depots']) {
          if (row['deleted'] == true) {
            await txn.delete('depots', where: 'id = ?', whereArgs: [row['id']]);
            removed++;
          } else {
            await txn.insert('depots', toLocal(row),
                conflictAlgorithm: ConflictAlgorithm.replace);
            upserted++;
          }
        }

        if (body['metadata']['hasNextPage'] != true) break;
        page++;
      }
    });
  } on DioException catch (e) {
    // 400 on modifiedSince means a poisoned watermark. Clear it and full-resync.
    if (e.response?.statusCode == 400 &&
        (e.response?.data?['errors']?['parameters.modifiedSince'] != null)) {
      await prefs.remove('depots_watermark');
      return syncDepots(force: true);
    }
    rethrow;   // transaction rolled back; watermark untouched; safe to retry
  }

  await prefs.setString('depots_watermark', nextWatermark!);
  await prefs.setString('synced_language', currentLocale);
  return SyncOutcome(upserted: upserted, removed: removed);
}
```

Note the recovery path. A rejected watermark is self-healing: clear it, resync fully,
and the device recovers without the user knowing.

---

## Checklist

- [ ] `pageSize=200` for sync, 25 for browsing
- [ ] `metadata.pageSize` read back, not assumed
- [ ] Watermark taken from the **first** page
- [ ] Watermark stored **after** the run commits, verbatim
- [ ] Whole run applied in one transaction
- [ ] `deleted: true` rows removed locally
- [ ] `synced_language` recorded; language change forces a full resync
- [ ] 400 on `modifiedSince` clears the watermark and resyncs
- [ ] Paging follows `hasNextPage`, not a computed page count
- [ ] `Accept-Language` sent on every request

---

## See also

- [filter-depot.md](filter-depot.md) — every filter, sort key and paging rule
- [search-depot.md](search-depot.md) — free-text search
- [get-depot-by-id.md](get-depot-by-id.md) — the full depot record
