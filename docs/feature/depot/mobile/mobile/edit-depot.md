# Edit Depot — Mobile

**Purpose:** updating an existing depot, including the contact set.
**Scope:** `PUT /api/v1/mobile/depots/{depotId}`.
**Status:** Active · **Last updated:** 2026-08-28

A whole-resource replace, not a patch. Everything you omit that the server treats as
replaceable is overwritten — with one deliberate exception, `contacts`.

---

## Contents

1. [The request](#the-request)
2. [PUT replaces — read this first](#put-replaces--read-this-first)
3. [What you cannot change](#what-you-cannot-change)
4. [Contacts: null and empty differ](#contacts-null-and-empty-differ)
5. [Closed depots reject edits](#closed-depots-reject-edits)
6. [Flow: SAP → backend → mobile](#flow-sap--backend--mobile)
7. [Validation](#validation)
8. [Client implementation](#client-implementation)
9. [Concurrency](#concurrency)
10. [Checklist](#checklist)

---

## The request

```
PUT /api/v1/mobile/depots/01a03189-9670-7599-98ac-45ebaf277899
Authorization: Bearer <access_token>
Accept-Language: km-KH
Content-Type: application/json
```

```json
{
  "shopName": "Sok Heng Hardware",
  "type": "Retailer",
  "phone": "012 345 678",
  "addressLine1": "Street 271",
  "city": "Phnom Penh",
  "district": "Chamkarmon",
  "province": "Phnom Penh",
  "ownerName": "Sok Heng",
  "email": null,
  "whatsapp": "+85512345678",
  "territory": "PP-CENTRAL",
  "latitude": 11.5449,
  "longitude": 104.9160,
  "creditLimit": 5000,
  "creditTermDays": 30,
  "currency": "USD",
  "enName": "Sok Heng Hardware",
  "khName": "ហាង សុខ ហេង",
  "descriptionEn": null,
  "descriptionKm": null,
  "contacts": null
}
```

Requires `depots.update`. Returns the updated depot in the mobile envelope —
the same shape `POST /mobile/depots` returns, not the `data.depot` nesting of
the detail endpoint.

Row-level scoping applies: editing a depot outside your scope returns **404**, not
403, exactly as reading one does.

---

## PUT replaces — read this first

This is the mistake that costs data. `PUT` is a replace, so a field you omit is set to
null rather than left alone:

```jsonc
// Depot currently has whatsapp, territory and a Khmer name.
// This request clears all three.
{ "shopName": "Sok Heng Hardware", "type": "Retailer", "phone": "012345678",
  "addressLine1": "Street 271", "city": "Phnom Penh" }
```

**Always build the body from the full current record**, not from the form fields the
user touched:

```dart
// Correct — start from what the server has, apply the edit, send it all back
final current = await getDepot(id);           // GET first
final body = current.toUpdateRequest()..['phone'] = newPhone;
await api.put('/mobile/depots/$id', data: body);
```

Fetch immediately before the edit, not from a cached summary — the summary has 23 of
the 52 fields, so building a body from it silently nulls the other 29.

> `PATCH` with JSON Merge Patch is the right shape for this and is on the roadmap.
> Until it lands, read-modify-write is the only safe pattern.

---

## What you cannot change

| Field | Why |
|---|---|
| `depotCode` | Immutable. Renaming it would orphan every SAP document, order and statement that references it. |
| `sapDepotId`, `salesOrg`, `division`, `distributionChannel`, `depotGroup`, `priceGroup`, `paymentTerms`, `taxNumber` | SAP owns them. Returned, never accepted. |
| `status` | Moves only through the lifecycle endpoints (`/submit`, `/approve`, `/suspend`, `/reinstate`) — and approval needs `depots.approve`. |
| `sapStatus`, `sapDepotNumber`, `lastError` | Set by the SAP push, which needs `depots.sync`. |
| Metrics (`lifetimeValue`, `totalOrders`, …) | Written by a projection job. |
| `assignedRepId` | Reassignment is a supervisor action through the portal. |

Sending any of them is not an error — they are ignored. Do not build a UI that
appears to edit them.

`creditLimit` and `creditTermDays` **are** editable here, because a depot's terms
genuinely change. Whether this user should be changing them is a permission question,
not a domain one — gate the field on the role if your business wants that.

---

## Contacts: null and empty differ

The one field where omission is meaningful:

| `contacts` | Effect |
|---|---|
| omitted or `null` | Contacts left completely untouched |
| `[ … ]` | **Replaces the whole set** |
| `[]` | **Removes every contact** |

Within a supplied array:

- an entry **with** an `id` updates that contact
- an entry **without** an `id` adds a new one
- a contact previously present and now absent is **removed**

```json
"contacts": [
  { "id": "019ff532-…", "name": "Heng Vuthy", "phone": "012345605", "position": "Owner" },
  { "name": "Sok Dara", "phone": "098765432", "position": "Purchaser", "isPrimary": true }
]
```

That request keeps Heng Vuthy, adds Sok Dara as primary, and deletes every other
contact.

**Do not let an empty list mean "unchanged".** Many Dart models serialise
`List<Contact> contacts = []` by default, which wipes the depot's contacts on
every save. Omit the key explicitly:

```dart
Map<String, dynamic> toUpdateRequest({bool contactsEdited = false}) => {
      'shopName': shopName,
      // …
      // Only send contacts when the user actually opened that section.
      if (contactsEdited) 'contacts': contacts.map((c) => c.toJson()).toList(),
    };
```

At most one contact is primary, guaranteed by the server: marking a second promotes it
and demotes the previous one rather than failing. No two-call swap needed, and there is
never a window with no primary. Maximum 25 contacts.

Contacts come back primary-first then alphabetical — a stable order, so a local diff
does not show phantom changes on every sync.

---

## Closed depots reject edits

A depot in `Closed` cannot be edited at all:

```json
{ "status": 422, "errorCode": "Depot.Closed",
  "detail": "This depot is closed and can no longer be modified." }
```

`Closed` is terminal — no transition leads out of it. History stays queryable, but
nothing can be changed. Disable the edit action when `status == 'Closed'` rather than
letting the user fill a form and lose it to a 422.

Every other status is editable, including `Suspended` — a suspended depot's details
still need correcting while the debt is chased.

---

## Flow: SAP → backend → mobile

An edit is local to the platform. **It does not propagate to SAP**, and it can be
overwritten by the next sync.

```mermaid
sequenceDiagram
    autonumber
    participant App as Flutter app
    participant API as ISI API
    participant DB as PostgreSQL
    participant Job as sap-depot-sync
    participant SAP as SAP ERP

    App->>API: GET /mobile/depots/{id}
    API-->>App: full record (52 fields)
    App->>API: PUT /mobile/depots/{id} (full body)
    API->>DB: update platform-owned fields; updated_at stamped
    API-->>App: updated depot

    Note over Job,DB: later — the nightly reconciliation
    Job->>SAP: GET /api/Depot/GetCustByPaging/{conId}
    SAP-->>Job: master data
    Job->>DB: overwrite SAP-owned fields<br/>platform-only fields untouched
```

Two consequences that matter for the UI:

- **A field SAP owns will revert.** The sync replaces the SAP block wholesale. That is
  why those fields are not accepted here — the edit would appear to work and silently
  disappear overnight.
- **An edit to a SAP-sourced name is fragile.** `enName` and `khName` on a depot
  that came from SAP are refreshed from the feed. If the ERP's name is wrong, it must
  be fixed in SAP; editing it here is temporary.

To push a change **to** SAP, an operator uses `PUT /depots/sap/{depotId}`, which
requires `depots.sync`. That is not available to the field app.

---

## Validation

Identical to create, minus the code:

| Rule | Failure |
|---|---|
| `shopName` required | `400 Depot.NameRequired` |
| Known `type` | `400 General.Validation` |
| Valid phone | `400 Depot.PhoneMalformed` |
| `addressLine1` and `city` required | `400 Depot.AddressLineRequired` / `…CityRequired` |
| Latitude and longitude together | `400 General.Validation` |
| `(0,0)` rejected | `400 Depot.CoordinatesMissing` |
| `creditTermDays` 0–180 | `400 Depot.CreditTermInvalid` |
| `creditLimit` ≥ 0 | `400 Depot.CreditLimitNegative` |
| Contact needs a name | `400 Depot.ContactNameRequired` |
| Contact `id` must exist on this depot | `404 Depot.ContactNotFound` |
| At most 25 contacts | `400 Depot.TooManyContacts` |
| Depot not closed | `422 Depot.Closed` |

Contact removals are applied **before** additions, so replacing a full 25-contact set
does not transiently exceed the limit and fail a request that is actually valid.

---

## Client implementation

```dart
Future<Depot> updateDepot({
  required String id,
  required DepotEditForm form,
  required bool contactsEdited,
}) async {
  // 1. Read the current full record. Not the cached summary — it has 23 of 52 fields.
  final current = await getDepot(id);

  if (current.depot.status == 'Closed') {
    throw const DepotClosedException();      // fail before the user types
  }

  // 2. Merge the edit onto the full record.
  final body = <String, dynamic>{
    'shopName':      form.shopName      ?? current.depot.shopName,
    'type':          form.type          ?? current.depot.type,
    'phone':         form.phone         ?? current.depot.phone,
    'addressLine1':  form.addressLine1  ?? current.depot.addressLine1,
    'addressLine2':  form.addressLine2  ?? current.depot.addressLine2,
    'city':          form.city          ?? current.depot.city,
    'district':      form.district      ?? current.depot.district,
    'province':      form.province      ?? current.depot.province,
    'postalCode':    form.postalCode    ?? current.depot.postalCode,
    'ownerName':     form.ownerName     ?? current.depot.ownerName,
    'email':         form.email         ?? current.depot.email,
    'whatsapp':      form.whatsapp      ?? current.depot.whatsapp,
    'territory':     form.territory     ?? current.depot.territory,
    'latitude':      form.latitude      ?? current.depot.latitude,
    'longitude':     form.longitude     ?? current.depot.longitude,
    'creditLimit':   form.creditLimit   ?? current.depot.creditLimit.amount,
    'creditTermDays':form.creditTermDays?? current.depot.creditTermDays,
    'currency':      current.depot.currency,
    'enName':        form.enName        ?? current.depot.enName,
    'khName':        form.khName        ?? current.depot.khName,
    'descriptionEn': form.descriptionEn ?? current.depot.descriptionEn,
    'descriptionKm': form.descriptionKm ?? current.depot.descriptionKm,
    // 3. Contacts ONLY when that section was opened.
    if (contactsEdited) 'contacts': form.contacts.map((c) => c.toJson()).toList(),
  };

  final res = await api.put('/mobile/depots/$id', data: body);
  final updated = Depot.fromJson(res.data['data']);
  await db.upsertDetail(updated);              // keep the local copy consistent
  return updated;
}
```

Note the coordinate handling: `form.latitude ?? current.latitude` preserves an
existing fix when the user did not recapture one. To **clear** a location you must
send explicit nulls for both, which needs a sentinel in your form model rather than
plain `null` — otherwise "not edited" and "cleared" are indistinguishable.

---

## Concurrency

There is no optimistic-concurrency check on this endpoint today. The aggregate carries
a concurrency token (`xmin`) but it is not exposed, so **last write wins**.

Two representatives editing the same shop offline will silently overwrite each other.
Until ETag / `If-Match` support lands:

- Keep the read-modify-write window short — fetch, edit, submit; do not hold a form
  open for an hour.
- After a successful `PUT`, trust the response over your local copy and upsert it.
- If your workflow genuinely has two people editing one shop, detect it by comparing
  `updatedAt` before and after and warn the user.

---

## Checklist

- [ ] Full current record fetched immediately before the edit
- [ ] Body built from the full record, never from the cached summary
- [ ] `contacts` omitted unless that section was edited — `[]` wipes them
- [ ] Edit action disabled when `status == 'Closed'`
- [ ] SAP-owned fields not presented as editable
- [ ] `status` not sent — use the lifecycle endpoints
- [ ] Coordinates preserved when not recaptured; explicit nulls to clear
- [ ] 404 handled as "not available", not "no permission"
- [ ] Response upserted into the local copy
- [ ] Read-modify-write window kept short (last write wins)

---

## See also

- [get-depot-by-id.md](get-depot-by-id.md) — the record you must read first
- [create-depot.md](create-depot.md) — the three creation paths
- [mobile.md](mobile.md) — the whole mobile depot surface
