# Depot — Requirements & Backend API Specification

> **Audience:** backend engineers building the Depot APIs, and mobile engineers
> consuming them.
> **Derived from:** `lib/features/depots/` at branch `web`, commit `17f3c9f`
> (2026-09-25). Every endpoint, field and rule below was read out of the mobile
> source — nothing here is invented.
> **Status:** specification. Where the code does not answer a question, the row
> is marked `TODO / Backend Confirmation Required`.

---

## 1. Feature overview

Depots are the shops, wholesalers and distributors a field sales rep sells to.
The feature covers four jobs:

1. **Browse** — a searchable, filterable, paged list of the depots a rep may see.
2. **Inspect** — one depot in full: contacts, SAP block, credit, metrics.
3. **Register** — create a new depot, optionally pushing it to SAP as a
   Business Partner through a resumable server-side draft.
4. **Stay usable offline** — the list is synced into the encrypted local
   database and read from there; the network only refreshes it.

## 2. Business purpose

A rep standing in a shop with no signal must still be able to identify the
depot, see its credit position, and register a new one. The local database is
the source of truth (ADR-002); every API here is a *refresher* of local state,
never a precondition for using the screen.

## 3. User roles

| Role | Capability |
|---|---|
| **Sales Representative** | Browse and inspect depots in their own territory; register new depots; upload documents. Cannot approve. |
| **Sales Supervisor / Manager** | As above, across the territories they own. |
| **HQ / Approver** | Holds `depots.approve`. Activates a `Draft` depot so it can trade. **Not a mobile role** — listed because it gates the depot lifecycle. |

Row-level scoping is enforced **server-side** — see `../api.md` §Row-level
scoping. The app sends no territory filter for "my depots"; it receives only
what the caller may see.

## 4. Naming: the single most important thing on this page

**The routes say `depot`. The payload keys say `customer`.** This is ADR-0007 —
the routes were renamed, the SAP-derived contract was not. Backend must keep
sending the `customer*` keys; mobile already maps them.

| Wire (backend) | Mobile model | Where |
|---|---|---|
| `data.customers[]` | list rows | `GET /mobile/depots` |
| `data.customer` | single depot | `GET /mobile/depots/{id}` |
| `customerCode` | `depotCode` | every depot payload |
| `sapCustomerId` | `sapDepotId` | every depot payload |
| `customerGroup` | `depotGroup` | detail payload |

Full mapping: [usecases/browse-depots.md](usecases/browse-depots.md#response-field-mapping).

## 5. User stories

| # | Story | Doc |
|---|---|---|
| US-01 | View my depots | [view-my-depots.md](user-stories/view-my-depots.md) |
| US-02 | Search and filter depots | [search-and-filter-depots.md](user-stories/search-and-filter-depots.md) |
| US-03 | View depot detail | [view-depot-detail.md](user-stories/view-depot-detail.md) |
| US-04 | Register a new depot | [register-new-depot.md](user-stories/register-new-depot.md) |
| US-05 | Resume an interrupted registration | [resume-registration-draft.md](user-stories/resume-registration-draft.md) |
| US-06 | Check a depot code before registering | [check-depot-code.md](user-stories/check-depot-code.md) |
| US-07 | Upload depot documents | [upload-depot-documents.md](user-stories/upload-depot-documents.md) |
| US-08 | Work offline | [work-offline.md](user-stories/work-offline.md) |

## 6. Use cases

| # | Use case | Doc |
|---|---|---|
| UC-01 | Browse depots | [browse-depots.md](usecases/browse-depots.md) |
| UC-02 | Get depot detail | [get-depot-detail.md](usecases/get-depot-detail.md) |
| UC-03 | Create depot | [create-depot.md](usecases/create-depot.md) |
| UC-04 | Look up depot by code | [lookup-depot-by-code.md](usecases/lookup-depot-by-code.md) |
| UC-05 | Initial sync | [initial-sync.md](usecases/initial-sync.md) |
| UC-06 | Delta sync | [delta-sync.md](usecases/delta-sync.md) |
| UC-07 | Registration draft lifecycle | [registration-draft-lifecycle.md](usecases/registration-draft-lifecycle.md) |
| UC-08 | Fetch SAP reference catalogues | [fetch-references.md](usecases/fetch-references.md) |
| UC-09 | Create SAP business partner | [create-business-partner.md](usecases/create-business-partner.md) |
| UC-10 | Manage depot documents | [manage-depot-documents.md](usecases/manage-depot-documents.md) |

## 7. Required APIs

Base prefix `/api/v1` (`AppConstants.apiPrefix`).
Depot root `/api/v1/mobile/depots` (`AppConstants.depotsEndpoint`).

| # | Method | Endpoint | Use case |
|---|---|---|---|
| A-01 | `GET` | `/mobile/depots` | UC-01, UC-05, UC-06 |
| A-02 | `GET` | `/mobile/depots/{id}` | UC-02 |
| A-03 | `POST` | `/mobile/depots` | UC-03 |
| A-04 | `PUT` | `/mobile/depots/{id}` | UC-03 (edit) — ⚠ see §13 |
| A-05 | `GET` | `/depots/by-code/{code}` | UC-04 — **portal surface, different envelope** |
| A-06 | `GET` | `/mobile/depots/references` | UC-08 |
| A-07 | `POST` | `/mobile/depots/draft` | UC-07 |
| A-08 | `GET` | `/mobile/depots/draft/active` | UC-07 |
| A-09 | `GET` | `/mobile/depots/draft/{draftId}` | UC-07 |
| A-10 | `GET` | `/mobile/depots/drafts` | UC-07 |
| A-11 | `POST` | `/mobile/depots/update` | UC-07 |
| A-12 | `POST` | `/mobile/depots/submit` | UC-07 |
| A-13 | `DELETE` | `/mobile/depots/draft/{draftId}` | UC-07 |
| A-14 | `POST` | `/mobile/depots/business-partner` | UC-09 |
| A-15 | `POST` | `/depots/bp/{localId}/attachments` | UC-09 — ⚠ inconsistent, see §13 |
| A-16 | `POST` | `/mobile/depots/{depotId}/documents` | UC-10 |
| A-17 | `GET` | `/mobile/depots/{depotId}/documents` | UC-10 |
| A-18 | `DELETE` | `/mobile/depots/{depotId}/documents/{documentId}` | UC-10 |

## 8. API flow

```
App start ─────────────► A-01 (initial sync, paged, sort=updatedAt)
                              │ store rows + metadata.syncTimestamp
                              ▼
Later / on refresh ─────► A-01 (modifiedSince=<last syncTimestamp>,
                              │  includeDeleted=true)
                              │ upsert non-deleted, delete tombstones
                              ▼
Browse screen ─────────► reads LOCAL database (never blocks on network)
Open a depot ──────────► A-02 (refresh) + local fallback

Register a depot:
  A-06 references ──► A-07 create draft ──► A-11 update (per step)
                            ▲                     │
                            └── A-08 resume ──────┘
                                                  ▼
                                             A-12 submit ──► SAP
                                                  │
                                    A-15 attachments (if any)
```

## 9. Entity relationships

```
Depot (1) ──< DepotContact (0..n)      contacts[] on the detail payload
Depot (1) ──< DepotDocument (0..n)     A-16 / A-17
Depot (1) ──< DepotNote (0..n)         local only — see §13
Depot (1) ──< DepotActivity (0..n)     local only — see §13
Depot (0..1) ── SAP Business Partner   via sapCustomerId
DepotRegistrationDraft (1) ──> Depot   via submittedDepotId after A-12
```

## 10. Business rules

| # | Rule | Evidence |
|---|---|---|
| BR-01 | `depotCode` is immutable once created; duplicates rejected `409 Depot.DuplicateCode`. | `depot_draft.dart` |
| BR-02 | A created depot starts `Draft` and **cannot trade** until someone with `depots.approve` activates it. | `depot_draft.dart`, `depot_status.dart` |
| BR-03 | A `Closed` depot cannot be edited at all — `422 Depot.Closed`. | `depot_status.dart` |
| BR-04 | Coordinates are sent **both or neither**. `(0,0)` is rejected `Depot.CoordinatesMissing` — it is a real point in the Gulf of Guinea and exactly what a failed GPS fix looks like. | `depot_draft.dart`, `depot_api_mapper.dart` |
| BR-05 | The SAP block (`salesOrg`, `division`, `distributionChannel`, `customerGroup`, `priceGroup`, `paymentTerms`) is **returned but never writable** from mobile. | `depot_draft.dart` |
| BR-06 | Phone accepts human formatting; server strips spaces, dashes, brackets. Never reject a rep for a space. | `depot_draft.dart` |
| BR-07 | Branch on `status`; **render `statusDisplay`**, which is localised and changes with `Accept-Language`. | `depot_status.dart` |
| BR-08 | An unknown `status` degrades to `Draft` (cannot trade), never throws. Erring toward "cannot trade" is recoverable. | `depot_status.dart` |
| BR-09 | `modifiedSince` must be the **server's own previous `syncTimestamp`**, never a device clock. More than 5 minutes ahead of server time is rejected. | `api_depot_remote_data_source.dart` |
| BR-10 | Delta sync **must** return tombstones (`deleted: true`), or deleted depots live on the handset forever. | `api_depot_remote_data_source.dart` |
| BR-11 | `pageSize` is **clamped** to 200, not rejected — mobile reads `metadata.pageSize` back rather than trusting what it sent. | `api_depot_remote_data_source.dart`, `AppConstants.maxPageSize` |
| BR-12 | A stable `sort=updatedAt` is mandatory on paged reads; without it a paged run both misses and duplicates rows. | `api_depot_remote_data_source.dart` |
| BR-13 | `references` must default to **active codes only**. A retired code renders identically in a dropdown and gets the registration rejected at SAP push with no visible reason. | `depot_datasources.dart` |
| BR-14 | `GET /draft/active` returning **404 means "no open form"**, not an error — it is also what a server without the endpoint answers. | `depot_datasources.dart` |
| BR-15 | A draft is resumable only when `isEditable == true` **and** `status == "Draft"`. If they disagree, the restrictive reading wins. | `depot_datasources.dart` |
| BR-16 | SAP BP creation is **synchronous and slow** — mobile allows 60s. A timeout that SAP later completes produces a duplicate on retry. | `business_partner_remote_data_source.dart` |
| BR-17 | `by-code` `502` means the ERP was unreachable — it must **never** be shown as "not found", or the rep registers a duplicate BP. | `api_depot_remote_data_source.dart` |
| BR-18 | Depot document upload max **10 MB**, one file per slot, no batch endpoint. | `depot_document_remote_data_source.dart` |

## 11. Validation rules

Consolidated in each use case. Summary of what the client already enforces or
relies on:

| Field | Rule |
|---|---|
| `depotCode` | required, unique, immutable |
| `shopName` | required, non-empty |
| `type` | required; `Retailer` \| `Wholesaler` \| `Distributor` \| `KeyAccount`. Invalid → `General.Validation`, **not** `Depot.TypeInvalid` |
| `phone` | required; formatting-tolerant |
| `addressLine1`, `city` | required |
| `latitude`/`longitude` | both or neither; not `(0,0)`; \|lat\|≤90, \|lng\|≤180 |
| `creditLimit` | ≥ 0 |
| `creditTermDays` | 0–180 |

## 12. Error handling

Success envelope (every endpoint except A-05 and the OAuth routes):

```json
{ "success": true, "message": "…", "data": { }, "metadata": { }, "traceId": "…", "timestamp": "…" }
```

**Failure is detected by HTTP status, not by `success`** — an error response is
a problem document with no `success` field at all.

| Status | Mobile behaviour |
|---|---|
| `2xx` | Parse `data`. |
| `4xx` | `ValidationFailure` — **not retried**. The rep must change a field. |
| `5xx` / transport | Retryable; stays queued. |
| `404` on `/draft/active` | "no draft" — a normal answer. |
| `404` on `by-code` | `DepotCodeAbsent` — safe to offer registration. |
| `502` on `by-code` | `DepotCodeUnavailable` — must not offer registration. |

Error codes referenced by the client: `Depot.DuplicateCode` (409),
`Depot.Closed` (422), `Depot.CoordinatesMissing`, `Depot.NotFoundByCode` (404),
`General.Validation`.

## 13. Open questions / TODO — Backend Confirmation Required

| # | Issue | Why it matters |
|---|---|---|
| Q-01 | **A-15 attachment route is inconsistent.** It is `/api/v1/depots/bp/{localId}/attachments` — missing the `mobile/` segment every other depot route has. | Likely a typo that will 404 in production. Confirm the correct path. |
| Q-02 | **A-15 bypasses the response envelope.** It reads `res.data['url']` directly, not `data.url`. | Either the endpoint genuinely returns a bare object, or this is a latent bug. Confirm the shape. |
| Q-03 | **`CreateBpResponse` accepts both camelCase and snake_case** (`customerCode`\|`customer_code`, `sapStatus`\|`status`, `customerId`\|`local_id`). | Two naming conventions on one payload. Which is authoritative? |
| Q-04 | **A-05 uses a different envelope** (`{data, meta}`) from every other endpoint (`{success, data, metadata}`). | Confirm this is deliberate (portal vs mobile surface) and will not be unified. |
| Q-05 | **A-04 (`PUT /mobile/depots/{id}`) is specified in `../api.md` but has no mobile client.** | Is edit-depot in scope? If yes, mobile work is required. |
| Q-06 | Depot **notes** and **activities** have use cases, entities and local storage but **no remote datasource**. | Are these local-only by design, or are APIs pending? |
| Q-07 | `metadata.syncTimestamp` format and timezone. | Mobile sends it back verbatim on `modifiedSince`; must round-trip exactly. |
| Q-08 | `references` catalogue names are read dynamically. Is the set stable (`SalesOrg`, `DistributionChannel`, `Division`, `DepotGroup`, `PriceGroup`, `PaymentTerm`, `ShippingCondition`, `SalesOffice`, `SalesGroup`)? | Mobile renders whatever arrives, but the form expects these. |
| Q-09 | BP payload is **47 fields**; mobile warns when the count drifts. Server **silently drops unknown keys**. | A bad merge reaches SAP incomplete with no error. Should the server reject unknown/missing keys instead? |
| Q-10 | `productCategory` filter exists in `DepotFilter` but is **never sent** to any endpoint. | Is it a planned server filter, or dead client state? |
| Q-11 | **Contacts are asymmetric.** Create sends `{name, phone, position?, isPrimary}`; detail returns `{id, name, position, phone, email}`. `isPrimary` is sent but never read; `email` is read but never sent. | A contact's email cannot be set at registration. Is `isPrimary` honoured, or is primacy purely the server's ordering? |

## 14. Backend implementation checklist

- [ ] A-01 list: `pageNumber`, `pageSize` (clamp 200), `sort`, `modifiedSince`, `includeDeleted`, `search`, `status`, `territory`
- [ ] A-01 returns `data.customers[]` + full `metadata` incl. `syncTimestamp`, `hasNextPage`, `pageSize`
- [ ] A-01 delta returns tombstones with `deleted: true` (BR-10)
- [ ] A-01 rejects `modifiedSince` > 5 min ahead of server time (BR-09)
- [ ] A-02 returns `data.customer` with contacts, SAP block, metrics, `metricsCalculatedAt`
- [ ] A-03 create: validate per §11, return 201 + `Location` + `data.customer`
- [ ] A-03 rejects `(0,0)` and half-coordinates (BR-04)
- [ ] A-03 rejects duplicate `depotCode` with 409 `Depot.DuplicateCode`
- [ ] Reject all writes to the SAP block (BR-05)
- [ ] `status` + `statusDisplay` on every depot payload; `statusDisplay` honours `Accept-Language` (BR-07)
- [ ] A-05 by-code returns 200 / 404 / 502 distinctly (BR-17)
- [ ] A-06 references default to active only; `kinds`, `search`, `includeInactive` (BR-13)
- [ ] A-07…A-13 draft lifecycle incl. 404-as-absence on `/draft/active` (BR-14)
- [ ] A-11 patch semantics: distinguish omitted from explicitly-empty (BR-15)
- [ ] A-14 BP accepts 47 fields, tolerates ≥60s, returns SAP return table on 400 too (BR-16)
- [ ] A-16…A-18 documents: 10 MB cap, per-slot upload (BR-18)
- [ ] Row-level scoping enforced server-side on every read
- [ ] Resolve every item in §13

## 15. Traceability

```
User Story (user-stories/) → Use Case (usecases/) → API (§7)
   → Request → Response → Mobile Model → Mobile UI
```

Each user story names its use case; each use case names its API, its mobile
model and the screen that renders it.

## 16. Related

- [`../api.md`](../api.md) — the existing Mobile Integration Guide (975 lines)
- [`../registration/`](../registration/) — SAP BP registration deep-dive
- [`../mobile/`](../mobile/) — per-endpoint contract notes
- [`../ui-ux.md`](../ui-ux.md) — step design for the registration form
- ADR-0007 (routes vs payload naming), ADR-002 (offline-first), ADR-011 (no local FKs)
