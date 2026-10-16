# Mobile Depot API

The depot surface consumed by the Flutter application, at
`/api/v1/mobile/depots`.

It exists alongside `/api/v1/depots` rather than replacing it. The mobile
client needs a flat, fully localised, sync-aware contract; the admin portal needs
the normalised one. Serving both from one set of routes means every change for one
client risks the other — which is the whole reason this is a second controller and
not a set of query parameters on the first.

---

## Contents

1. [Endpoints](#endpoints)
2. [Registration: helpers, draft, submit](#registration-helpers-draft-submit)
3. [Response envelope](#response-envelope)
4. [Localisation](#localisation)
5. [Filtering, paging and sorting](#filtering-paging-and-sorting)
6. [Offline and incremental sync](#offline-and-incremental-sync)
7. [Design decisions](#design-decisions)
8. [Migration plan](#migration-plan)
9. [Breaking change report](#breaking-change-report)
10. [Recommendations for v2](#recommendations-for-v2)

---

## Endpoints

| Method | Route | Permission | Returns |
|---|---|---|---|
| `GET` | `/api/v1/mobile/depots` | `depots.read` | `DepotListResponse` |
| `GET` | `/api/v1/mobile/depots/{id}` | `depots.read` | `DepotDetailsDto` |
| `POST` | `/api/v1/mobile/depots` | `depots.create` | `DepotDto` (201) |
| `PUT` | `/api/v1/mobile/depots/{id}` | `depots.update` | `DepotDto` |
| `DELETE` | `/api/v1/mobile/depots/{id}` | `depots.delete` | 204 |

Registration — see [the next section](#registration-helpers-draft-submit):

| Method | Route | Permission | Returns |
|---|---|---|---|
| `GET` | `/api/v1/mobile/depots/references` | `depots.read` | `DepotReferenceCatalogueResponse` |
| `POST` | `/api/v1/mobile/depots/draft` | `depots.create` | `DepotDraftResponse` |
| `POST` | `/api/v1/mobile/depots/update` | `depots.create` | `DepotDraftResponse` |
| `POST` | `/api/v1/mobile/depots/submit` | `depots.create` | `DepotSapStatusDto` |
| `GET` | `/api/v1/mobile/depots/drafts` | `depots.create` | `DepotDraftResponse[]` |
| `GET` | `/api/v1/mobile/depots/draft/{draftId}` | `depots.create` | `DepotDraftResponse` |
| `DELETE` | `/api/v1/mobile/depots/draft/{draftId}` | `depots.create` | 204 |
| `POST` | `/api/v1/mobile/depots/business-partner` | `depots.create` | `DepotSapStatusDto` |

**Row-level scoping.** A representative sees the depots assigned to them; a
holder of `depots.readall` sees the whole territory. Enforced in the query
handler, not the controller, so it applies equally to background jobs.

**404 rather than 403** for a depot outside the caller's scope. Distinguishing
the two confirms that a given depot exists, which is exactly what a competitor
probing the API wants to learn.

---

## Registration: helpers, draft, submit

The Sales Rep "Register New Business Partner" flow. Four calls, in order.

```
GET  references   → the nine SAP dropdowns          (4.5 KB, ~98 ms)
POST draft        → server-side form, 8 fields prefilled
POST update       → patch, called on every field blur
POST submit       → depot created, sapStatus = Submitted
```

Full contract in
[`feature/depot-mobile-registration/api.md`](registration/api.md).
The three things that most affect the client:

**The draft lives on the server.** `POST draft` returns a `draftId` and the whole
46-field SAP payload already part-answered from configuration. Bind the form to
`fields`; a handset that dies mid-form loses nothing.

**`update` is a patch.** Omit a field → unchanged. Send `""` → cleared. Send a value →
set. That distinction is load-bearing: without it a rep could never delete a value they
mistyped. Only send what changed.

**Sales employees are a search box, not a dropdown.** There are 5,809 of them, so they
are excluded from `GET references` — which would otherwise be 252 KB — and fetched with
`?kinds=SalesEmployee&search=leng`.

Submitting never calls SAP. The depot is written locally with
`sapStatus: "Submitted"` and delivered by the next
`POST /api/v1/depots/sap/push-pending`. A rep at a counter has no route to the ERP
and their registration still has to succeed.

The nine catalogues are synced from SAP daily at 03:00 UTC and served from the
database, because several `CustHelper` endpoints take seconds to minutes to answer and
one has timed out entirely. See
[`docs/feature/depot/registration/sap-helpers.md`](registration/sap-helpers.md)
for every verified response shape — including `GetPaymentTerm`, which returns
`PayTerm`, not `PaymentTerm`.

---

## Response envelope

Success:

```json
{
  "success": true,
  "message": "Depots retrieved successfully.",
  "data": { "depots": [], "syncTimestamp": "2026-08-05T07:46:06Z" },
  "metadata": {
    "page": 1,
    "pageSize": 25,
    "totalRecords": 320,
    "totalPages": 13,
    "hasNextPage": true,
    "hasPreviousPage": false,
    "syncTimestamp": "2026-08-05T07:46:06Z",
    "isDeltaSync": false
  },
  "traceId": "0HNNIOM3JVMIA:00000001",
  "timestamp": "2026-08-05T07:46:06Z"
}
```

Failure — **not** wrapped in the envelope. Errors are RFC 9457
`application/problem+json`:

```json
{
  "type": "https://docs.isigroup.com.kh/errors/Depot.NotFound",
  "title": "The requested resource was not found.",
  "status": 404,
  "detail": "No depot was found with identifier '...'.",
  "errorCode": "Depot.NotFound",
  "correlationId": "0HNNIOM3JVMIA:00000001"
}
```

Two envelopes look inconsistent, and it is deliberate. A gateway, a log processor
or a generated client already understands `problem+json`; making them learn a
bespoke error shape to discover that something failed buys nothing. **Branch on
the HTTP status code, not on `success`** — the flag is there because the Flutter
model expects it, not because reading it is the correct way to detect failure.

`errorCode` is the field to switch on. It is stable, and the Flutter app localises
from it — so a Khmer-speaking user never sees an English string from the server.

---

## Localisation

Send `Accept-Language: km-KH` or `en-US`.

`shopName`, `description` and `statusDisplay` arrive **already translated**. The
client never sees `shopNameEn` / `shopNameKm` and never chooses between them.

```
Accept-Language: en-US   →  "shopName": "Sok Heng Hardware", "statusDisplay": "Draft"
Accept-Language: km-KH   →  "shopName": "ហាង សុខ ហេង",        "statusDisplay": "សេចក្ដីព្រាង"
```

`enName` and `khName` are also returned, regardless of the requested language.
That is a deliberate exception, not a leak of the internal columns: a delivery note
carries the Khmer shopfront name and the English legal name together.

Language resolution is four-tier — `Accept-Language` header → JWT claim → user
profile → platform default. The response echoes `Content-Language` and
`X-Language-Source` so "why am I getting English?" is answerable without server
logs.

Fallback chain for any localised field: **requested → English → legal name**. The
last step guarantees a non-empty name; an untranslated depot shows its legal
name, which always beats a blank row.

---

## Filtering, paging and sorting

| Parameter | Type | Notes |
|---|---|---|
| `pageNumber` | int | One-based. Below 1 is treated as 1. |
| `pageSize` | int | Default 25, clamped to 200. |
| `search` | string | Matches name, code, city, SAP number and phone. |
| `sort` | string | `-updatedAt,name`. A `-` prefix descends. |
| `status` | enum | `Draft`, `PendingApproval`, `Active`, `Suspended`, `Closed` |
| `type` | enum | `Retailer`, `Wholesaler`, `Distributor`, `KeyAccount` |
| `territory` | string | Exact match. |
| `province` / `district` | string | Exact match. |
| `assignedRepId` | guid | Ignored unless the caller holds `depots.readall`. |
| `linkedToSapOnly` | bool | Only depots that already have a SAP number. |
| `modifiedSince` | date-time | Incremental sync. See below. |
| `includeDeleted` | bool | Include tombstones. Implied by `modifiedSince`. |

`pageSize` is **clamped rather than rejected**. A mobile client on a flaky
connection asking for 10 000 rows is a mistake to absorb quietly, not a request to
fail — but it will not be allowed to table-scan the database either.

Sortable columns are an allow-list. Translating an arbitrary client string into an
`ORDER BY` lets a caller sort by an unindexed column and is one short step from
being an injection vector.

---

## Offline and incremental sync

**First sync.** Omit `modifiedSince`, page through with `pageSize=200`. Store
`metadata.syncTimestamp` from the last page.

**Delta sync.** Send the stored value back:

```
GET /api/v1/mobile/depots?modifiedSince=2026-08-05T07:46:06Z
```

Returns only records changed at or after that instant, **including soft-deleted
ones as tombstones** with `deleted: true`. A device drops its local copy when it
sees one. Without tombstones a record deleted on the server would simply stop
appearing in the delta and linger on the phone forever — the classic offline-sync
data leak.

Three details that are load-bearing:

- **`syncTimestamp` comes from the server clock, never the device's.** A phone
  running ten minutes fast would otherwise ask for changes since the future,
  receive an empty delta, store that timestamp, and never sync again. A silent,
  permanent failure. A `modifiedSince` more than five minutes ahead of server time
  is rejected with a 400 rather than accepted.
- **New records are matched on `CreatedAt` when `UpdatedAt` is null.** A depot
  registered since the last sync would otherwise never reach the device.
- **A delta is ordered by change time**, so a client that stops halfway can resume
  from the last record it stored.

---

## Design decisions

### Status: flat code plus a separate display field

Returned as `"status": "Active"` alongside `"statusDisplay": "សកម្ម"` — **not** as
a nested `{ "code": ..., "displayName": ... }` object.

The brief asked for a recommendation between the two, and this is it. Client logic
must branch on a stable code and must never branch on a localised string; keeping
them as two flat fields makes that separation obvious at the call site, keeps
`DepotModel.fromJson` trivial, and matches what Microsoft Graph does. The nested
object costs a level of traversal on every client to express a relationship that
the field names already make clear.

### Money: value object in the domain, `{ amount, currency }` on the wire

Recommended, and implemented. A decimal on its own is not an amount of money — it
is a number someone remembers the currency of, and that memory is where currency
bugs live. A credit limit in USD compared against a balance in KHR is a silent
4000× error that nothing in the type system objects to.

**Storage is deliberately different from the model.** A depot trades in one
currency, so the table has a single `currency` column and bare `numeric(18,4)`
amounts. Storing `(amount, currency)` per field would repeat the code three times
and invite the columns to drift apart. `Money` is rehydrated by the aggregate.

`Add` and `Subtract` refuse to operate across currencies rather than converting —
conversion needs a rate and a rate date, which are an application concern.

### Mapping: Mapster, not AutoMapper

The brief asked for AutoMapper profiles. Two facts argued against it: Mapster is
already this solution's mapping library, and **AutoMapper moved to a commercial
licence at v15** — the same trap already avoided by pinning MediatR to 12.5.0.
Adding it would mean two mapping conventions and a licence decision to revisit.

The equivalent Mapster configuration is in `DepotMobileMappingRegister`, one
file, trivially swappable for an AutoMapper 14.x profile if that call goes the
other way.

**The list projection is a hand-written `Expression` regardless of mapper.** A
list query must project inside the database, and three things here defeat
convention-based mapping: the localised column is chosen per request, money is
assembled from two columns, and `assignedRepName` lives in a different `DbContext`.
A mapper's failure mode on a read path is a performance cliff with no compiler
error.

### `assignedRepName` and the N+1 it would have been

Users live in `ISI.Identity` behind their own `DbContext`, so a depot query
cannot join to them. The name is resolved afterwards through `IUserDirectory`,
whose method takes a **set** of ids — a page of fifty depots resolves in one
round trip, not fifty.

### SAP fields are read-only on this surface

`sapDepotId`, `salesOrg`, `division`, `distributionChannel`, `depotGroup`,
`priceGroup` and `paymentTerms` are returned but never accepted. SAP owns that
data; letting a phone set `salesOrg` would let the field invent master data the ERP
then contradicts.

`paymentTerms` (the SAP key, e.g. `NT30`) and `creditTermDays` (the day count the
platform enforces) are separate on purpose. The mapping between them lives in SAP
customising and can change there without this platform being redeployed.

### Metrics are a cache and the API says so

`lifetimeValue`, `totalOrders`, `openOpportunityCount`, `lastOrderDate` and
`lastVisitDate` are denormalised onto the depot, because the list screen shows
them on every row and deriving them per row would mean an aggregate over the orders
table for each of fifty depots on a 3G connection.

They are stamped with `metricsCalculatedAt` so a client can tell how stale they
are, and **they are never used to make a decision inside the domain** — a credit
check reads the orders. Treating a projection as authoritative is how a depot
ends up blocked by a figure a failed job left behind three weeks ago.

### Contacts replace wholesale; null and empty differ

On `PUT`, omitting `contacts` leaves them untouched; supplying an array replaces
the set. A contact with an `id` is updated, one without is added, one previously
present but now absent is removed. An empty array therefore clears them — which is
intended, and is why the two cases mean different things.

The aggregate guarantees at most one primary contact by demoting the previous one
rather than rejecting the second. Rejecting it would force clients into a two-call
swap with a window where the depot has no primary.

---

## Migration plan

### What shipped

One migration, `20260805073845_AddMobileDepotFields`:

- **22 columns** added to `depots` — `sap_depot_id`, `sales_org`, `division`,
  `distribution_channel`, `depot_group`, `price_group`, `payment_terms`,
  `tax_number`, `territory`, `whatsapp`, `origin_lead_id`, `currency`,
  `credit_balance`, `district`, `products_purchased` (jsonb), `lifetime_value`,
  `total_orders`, `open_opportunity_count`, `last_order_date`, `last_visit_date`,
  `metrics_calculated_at`
- **1 table** — `depot_contacts`
- **5 indexes** — `ix_depots_sap_depot_id` (unique, filtered),
  `ix_depots_territory`, `ix_depots_updated_at`,
  `ix_depot_contacts_depot_id`, `ix_depot_contacts_primary` (unique,
  filtered)

Every added column is nullable or carries a default, so **the migration is
backward compatible**. Existing rows keep working; `currency` defaults to `USD`,
counters to `0`.

### Applying it

```bash
set -a; . ./.env; set +a
dotnet ef database update --project src/ISI.Persistence --startup-project src/ISI.Api
```

Verified applied against local PostgreSQL 17: `depots` now has 52 columns and
`depot_contacts` exists.

### Rollback

```bash
dotnet ef database update <previous-migration> --project src/ISI.Persistence --startup-project src/ISI.Api
```

Non-destructive in the forward direction; **rolling back drops
`depot_contacts` and every contact in it.** Take a dump first if the table has
real data:

```bash
pg_dump -U postgres -d ISIPlatform -t depot_contacts > contacts-backup.sql
```

### Backfill, in order

None of this is required for the API to work — every field degrades to null — but
the mobile app shows blanks until it runs.

1. **`territory`** — from the assigned representative's `territory_code`, or by
   district mapping. Needed first; it drives the list filter.
2. **SAP block** — from the next full depot master interface run. Match on
   `code` ↔ SAP's reference field, then populate `sap_depot_id` and the
   classification columns.
3. **`currency`** — already `USD` by default. Only change rows that genuinely
   trade in KHR.
4. **`credit_balance`** — from SAP accounts receivable. Until then it reads zero,
   which makes `availableCredit` optimistic; do not enable a client-side credit
   block before this lands.
5. **Metrics** — a projection job over orders and visits. Run it nightly.
6. **`contacts`** — seed one contact per depot from the existing
   `contact_person` and `phone` columns, marked primary.

### Deployment order

1. Apply the migration (backward compatible — safe with old code running).
2. Deploy the API.
3. Release the Flutter build.

Steps 1 and 2 are independent of the client; nothing existing breaks between them.

---

## Breaking change report

### For existing clients: none

`/api/v1/depots`, `ApiResponse<T>`, `DepotResponse` and `DepotListItemResponse`
are untouched. The new surface is new routes with new types. The portal and any
current consumer keep working with no change.

This was the main design constraint. Applying the brief's envelope to the shared
`ApiResponse<T>` would have broken every existing consumer to suit one client.

### For the Flutter `DepotModel`: field-level changes

The Dart model was not copied literally. Differences to expect:

| Flutter field | API field | Change |
|---|---|---|
| `creditLimit` (num) | `creditLimit` (object) | **Breaking.** Now `{ amount, currency }`. |
| `creditBalance` (num) | `creditBalance` (object) | **Breaking.** Now `{ amount, currency }`. |
| `lifetimeValue` (num) | `lifetimeValue` (object) | **Breaking.** Now `{ amount, currency }`. |
| `address` (string) | `address` (string) | Compatible — now a composed single line. |
| — | `addressLine1`, `addressLine2`, `city`, `district`, `province`, `postalCode` | Added, for forms that edit parts. |
| `status` (string) | `status` (string) | Compatible. `statusDisplay` added alongside. |
| `contacts` | `contacts` | Compatible. `isPrimary` and `email` added. |
| `deleted` | `deleted` | Compatible. `deletedAt` added. |
| — | `canTrade`, `availableCredit`, `metricsCalculatedAt`, `statusDisplay` | Added, computed server-side. |
| — | `sapStatus` | **Added to the list row and the detail.** `NotSubmitted` / `Submitted` / `Registered` / `Rejected`. |

**Three money fields are the only genuine break.** Migration in Dart:

```dart
// Before
creditLimit: (json['creditLimit'] as num).toDouble(),

// After
creditLimit: (json['creditLimit']['amount'] as num).toDouble(),
currency:    json['creditLimit']['currency'] as String,
```

If that is unacceptable on your release schedule, the alternative is to add flat
`creditLimitAmount` / `creditLimitCurrency` fields alongside the objects and
deprecate one set later. I did not do that by default because shipping both
doubles the surface permanently to save one line of parsing in three places.

### Behavioural changes to know about

- **`sapStatus` is new on both the list row and the detail.** It existed only on the
  create/submit response (`DepotSapStatusDto`), so a rep who had just submitted a
  registration went back to the list, saw `status: "Draft"`, and reasonably concluded
  it had failed. Additive on both shapes - no existing field changed.
- **`status` and `sapStatus` are independent, and both are normal together.**
  `Draft` + `Submitted` means "captured in the field, sent to the ERP, awaiting credit
  approval here". Never derive one from the other.
- **`DELETE` requires `depots.delete`**, which sales representatives do not
  hold. Verified: a rep receives 403. If field staff must delete their own drafts,
  that is a permission grant, not a code change.
- **`(0, 0)` coordinates are rejected.** It is a valid point in the Gulf of Guinea
  and what a device reports when the GPS fix failed. Send them as null.
- **Latitude and longitude must be sent together**; one without the other is a 400.

---

## Recommendations for v2

Roughly in order of value.

1. **Cursor pagination for sync.** `pageNumber`/`pageSize` over a set that is
   being written to can skip or repeat rows between pages. A keyset cursor on
   `(updated_at, id)` is stable under concurrent writes and is the correct shape
   for a full sync of a large territory.

2. **`PATCH` with JSON Merge Patch.** `PUT` requires the client to send the whole
   resource, which means a phone with a stale copy can silently revert a field
   someone else changed. `PATCH` also makes "null means untouched" versus "null
   means clear" explicit rather than conventional — the ambiguity currently
   documented on `contacts`.

3. **ETag and `If-Match`.** The aggregate already carries a concurrency token
   (`xmin`); it is not currently exposed. Surfacing it as an ETag turns lost
   updates from silent into a 412, which matters when two representatives edit the
   same shop offline.

4. **A dedicated `/sync` endpoint.** Overloading the list endpoint works, but a
   purpose-built one could return depots, orders and visits in a single
   round trip with one consistent watermark — currently a client makes three calls
   with three timestamps that can interleave.

5. **Split the metrics into a sub-resource.** `GET /depots/{id}/metrics`, cached
   separately with its own TTL. They change on a different schedule from the
   depot and currently invalidate the whole payload.

6. **Server-driven field selection.** `?fields=id,shopName,phone` for the list.
   The summary DTO is already about a fifth of the full one, but a rep on 2G
   syncing 800 depots still moves real bytes.

7. **Revisit the localisation storage model at a third language.** Columns beat a
   translation table cleanly at two languages. A third means a migration and a
   branch in every projection; that is the point to switch, and not before.

8. **Redis-cache the translated status labels.** Currently an in-memory dictionary
   lookup per row — nil cost today, worth revisiting only if the catalogue grows.
