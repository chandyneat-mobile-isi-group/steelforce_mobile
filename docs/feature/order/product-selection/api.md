# Materials, Stock and Price — Mobile Integration Guide

For the Flutter field sales app. Base URL `https://<host>/api/v1`.
Every response below was executed against a live server and a live SAP `Live110`.

---

## 0. What exists, and what does not

You asked for three features. **One is built, one is partial, one does not exist yet.**
Read this table before planning any screen.

| Feature | State | What you get today |
|---|---|---|
| **Material** — the product catalogue | **Built** | 12 mobile endpoints. 13,499 materials synced from SAP, with a server-driven guided selection wizard |
| **Stock** | **Partial** | A live SAP *sellability* check — yes/no with reasons. **No on-hand quantity anywhere.** Plus the rep's own eyeball estimate, pushed with a visit |
| **Price** | **Not built** | Nothing. `priceGroup` is a classification code, not a price. See [§6](#6-price-does-not-exist-yet) |

> **`priceGroup` is not a price.** A material carries `priceGroup: "A7"` and
> `priceGroupName: "TRIM_PALM100PP"`. That is SAP's *pricing classification* — the bucket
> a material sits in for condition lookup. It carries no amount, no currency, and no
> depot. Do not display it as a price, and do not attempt to derive one from it.

---

## 1. Permissions

Everything here needs **`materials.read`**.

Sales representatives hold it. If you get a `403` with no `errorCode` on a materials
endpoint, the role is missing the permission in the database — see
[§7](#7-if-you-get-403-on-everything).

All materials endpoints return **envelope C** — `{success, message, data, metadata,
traceId, timestamp}`. See the `mobile-integration-guide.md` §3 "Three response shapes" (⧉ backend repo)
for why that matters.

---

## 2. The catalogue

### List — `GET /mobile/materials`

Filters: `material`, `materialName`, `materialKhName`, `materialType`, `materialGroup`,
`brand`, `excludeBlocked`, plus `pageNumber` / `pageSize` / `sort` / `search`.

```json
{
  "success": true,
  "data": {
    "materials": [{
      "id": "01a0372a-6141-7a1c-b5fe-6c8c58d7c43f",
      "material": "1100000000",
      "name": "CRC 625x0.679 (SPCC-1B)",
      "materialName": "CRC 625x0.679 (SPCC-1B)",
      "materialKhName": "ដុំរ៉ូឡូដែក-ខ្មៅ 625x0.589mm - SPCC-1B",
      "materialType": "ROH",
      "materialTypeName": "Raw Materials",
      "materialGroup": "150000",
      "materialGroupName": "CRC (Cold Roll Coil)",
      "baseUnit": "KG",
      "brand": "NA",
      "isBlocked": false
    }]
  },
  "metadata": {
    "page": 1, "pageSize": 2, "totalRecords": 13499, "totalPages": 6750,
    "hasNextPage": true, "hasPreviousPage": false,
    "syncTimestamp": "2026-08-25T06:43:12.4530913+00:00", "isDeltaSync": false
  }
}
```

**13,499 materials.** Do not build a screen that scrolls this list. Reps do not find a
roofing sheet by paging 6,750 pages — they answer four questions. That is what the
guided selection in [§3](#3-guided-selection--the-primary-way-in) is for. Keep the flat
list for search-by-code and for a "recently used" shelf.

`isBlocked: true` means SAP has blocked the material. Pass `excludeBlocked=true` and
never offer a blocked material for order capture.

### Detail — `GET /mobile/materials/{materialId}` · `GET /mobile/materials/by-number/{materialNumber}`

`by-number` reads the local database and **falls back to SAP** when the number is
unknown locally, so a material created in SAP minutes ago is still findable.

```json
{
  "material": "2400001439",
  "name": "CAP 980 SB 0.40mm-PALM 100PPGL",
  "materialKhName": "ស័ង្កសី ផាម ភ្លីមួក 980 ផ្ទៃមេឃ 0.40mm-PALM AM100PPGL",
  "materialType": "KMAT",         "materialTypeName": "Configurable Materials",
  "materialGroup": "311000",      "materialGroupName": "Palm Profile",
  "materialGroupCategory": "FG-RF",
  "priceGroup": "A7",             "priceGroupName": "TRIM_PALM100PP",
  "division": "10",               "divisionName": "ISI Steel",
  "itemCategoryGroup": "0002",
  "transportGroup": "T001",       "transportGroupName": "ISI Group",
  "productGroup": "PALM PROFILE",
  "brand": "PALM 100PPGL",
  "profile": "CAP 980",
  "grade": "G300AZ100",
  "topColor": "Sky Blue-ផ្ទៃមេឃ",
  "saleThicknessMm": 0.4,
  "rawThicknessMm": 0.4,
  "widthMm": 1200.0,
  "density": 0.0072,
  "baseUnit": "M",   "weightUnit": "KG",
  "grossWeight": 3.46, "netWeight": 3.46,
  "isBlocked": false, "blockedCode": null, "deletionFlag": null,
  "changedOnInSap": "2024-11-27",
  "synchronisedAt": "2026-08-25T04:59:38.28659+00:00"
}
```

Two distinct thicknesses, and they are not interchangeable: **`saleThicknessMm` is what
you quote to a depot**, `rawThicknessMm` is the coil it was rolled from. Show the
sale thickness.

`baseUnit` varies by material — `KG` for coil, `M` for profile. Never hard-code a unit;
read it and render it. `synchronisedAt` tells you how stale the local copy is.

### Reference data, for filter chips

| Endpoint | Rows (live) | Notes |
|---|---|---|
| `GET /mobile/materials/types` | 16 | `{code, name}` — e.g. `ROH` "Raw Materials" |
| `GET /mobile/materials/groups` | 239 | `{code, name, category}` — category ties a group to a selection category |
| `GET /mobile/materials/plants` | 23 | `{code, name}` — e.g. `1001` "ISI Tower (ISIT)" |
| `GET /mobile/materials/storage-locations?plant=1001` | 3 | `{code, name, plant}` — requires `plant` |

These change rarely. Cache them on first launch and refresh daily, not per screen.

---

## 3. Guided selection — the primary way in

**The most important thing in this document.** The server ships the *shape of the
wizard*, not just its data, so the app renders a UI it was never coded against.

```
GET  selection/categories   →  48 categories, with material counts
GET  selection/schema       →  the steps for one category: label, widget, unit, order
POST selection/facets       →  the options for one step, given what is chosen so far
POST selection/materials    →  the materials matching a completed selection
```

### Step 1 — `GET /mobile/materials/selection/categories`

```json
[{ "code": "FG-RF", "name": "Profile Roofing", "materialCount": 1549, "hasPublishedSchema": true }]
```

**Only offer categories with `hasPublishedSchema: true`.** The rest have no wizard
defined and will dead-end. `materialCount` is worth showing — it tells the rep how big
a haystack they are entering.

### Step 2 — `GET /mobile/materials/selection/schema?categoryCode=FG-RF`

```json
[{
  "categoryCode": "FG-RF",
  "categoryName": "Profile Roofing",
  "isDerived": false,
  "steps": [
    { "key": "profile", "label": "Profile",      "attribute": "Profile",   "sortOrder": 1,  "style": "List",  "role": "Family",        "required": true,  "unitSuffix": null, "decimals": null },
    { "key": "coating", "label": "Coating Line", "attribute": "Brand",     "sortOrder": 2,  "style": "Chips", "role": "Specification", "required": true,  "unitSuffix": null, "decimals": null },
    { "key": "gauge",   "label": "Gauge",        "attribute": "Thickness", "sortOrder": 3,  "style": "Grid",  "role": "Dimension",     "required": true,  "unitSuffix": "mm", "decimals": 2 },
    { "key": "colour",  "label": "Colour",       "attribute": "Colour",    "sortOrder": 4,  "style": "Chips", "role": "Specification", "required": true,  "unitSuffix": null, "decimals": null },
    { "key": "sku",     "label": "Material",     "attribute": "Sku",       "sortOrder": 99, "style": "List",  "role": "Sku",           "required": true,  "unitSuffix": null, "decimals": null }
  ]
}]
```

Render each step from its own fields:

| Field | Use it for |
|---|---|
| `label` | The heading the rep reads. **Already localised** — never hard-code "Gauge" |
| `style` | The widget: `List`, `Chips`, `Grid` |
| `attribute` | What you send to `selection/facets` as `attribute` |
| `sortOrder` | Step order. `99` conventionally marks the final SKU pick |
| `unitSuffix` / `decimals` | Number formatting — `0.40 mm`, not `0.4` |
| `required` | Whether the rep may skip it |
| `role` | Semantic hint: `Family` · `Specification` · `Dimension` · `Sku` |

**Build one wizard screen driven by this array.** Adding a step, renaming a label or
changing a widget is then a server-side change with no app release. Hard-code the four
steps and you have signed up to ship a build every time the product team reorganises a
category.

### Step 3 — `POST /mobile/materials/selection/facets`

One call per step. Send the attribute you want options for, plus everything chosen so far.

```json
{
  "attribute": "Profile",
  "selection": { "categoryCode": "FG-RF", "excludeBlocked": true }
}
```

```json
[
  { "value": "CAP 980",          "label": "CAP 980",          "matchCount": 37  },
  { "value": "CAP 980PU",        "label": "CAP 980PU",        "matchCount": 114 },
  { "value": "CAP 980 BULLNOSE", "label": "CAP 980 BULLNOSE", "matchCount": 36  },
  { "value": "COOL TILE",        "label": "COOL TILE",        "matchCount": 40  }
]
```

Narrowing works by adding to `selection`:

```json
{ "attribute": "Brand", "selection": { "categoryCode": "FG-RF", "profile": "CAP 980", "excludeBlocked": true } }
```

```json
[
  { "value": "PALM 100GL",   "label": "PALM 100GL",   "matchCount": 3  },
  { "value": "PALM 100PPGL", "label": "PALM 100PPGL", "matchCount": 27 },
  { "value": "PALM 50PPGL",  "label": "PALM 50PPGL",  "matchCount": 7  }
]
```

**Show `matchCount` on every option.** It is computed from the same filter the final
query uses, so it never promises twelve and delivers nine. A rep can see that one branch
has 114 materials and another has 3 before spending a tap.

An option list of length 1 can be auto-selected; an empty list means the combination
does not exist and the rep should back up a step.

### Step 4 — `POST /mobile/materials/selection/materials`

```json
{
  "selection": { "categoryCode": "FG-RF", "profile": "CAP 980", "brand": "PALM 100PPGL", "excludeBlocked": true },
  "page": 1,
  "pageSize": 20
}
```

Returns the same `MaterialListItem` rows and `metadata` as the flat list — 27 records for
the selection above.

> **Note the two different body shapes.** `selection/facets` takes
> `{attribute, selection}`; `selection/materials` takes `{selection, page, pageSize,
> search}`. Putting the selection fields at the top level of the second one is silently
> read as an empty selection — the mistake produces the error below.

### The `selection` object

| Field | |
|---|---|
| `categoryCode` | The category. **Does not count as narrowing** — see below |
| `family`, `brand`, `colour`, `profile`, `grade` | Text attributes |
| `materialType`, `division`, `priceGroup` | SAP classifications |
| `thickness`, `rawThickness`, `width` | Numeric |
| `materialNumber` | Exact SAP number |
| `excludeBlocked` | Send `true` for order capture |

### The bounded-selection rule

```json
{
  "errorCode": "Material.SelectionNotBounded",
  "status": 400,
  "detail": "Answer at least one selection step, or search for two characters or more, before requesting materials."
}
```

`selection/materials` refuses a request that narrows nothing. **A `categoryCode` alone
does not count** — "Profile Roofing" is 1,549 materials, which is not a result set a rep
can use on a phone.

So the wizard must either carry one real answer, or a `search` of two characters or more.
Handle this as a UI state, not an error dialog: keep the "Show materials" button disabled
until one step is answered.

---

## 4. Stock — what there actually is

**There is no on-hand quantity endpoint.** No `stockLevel` in units, no warehouse
balance, no ATP quantity. If you have a screen designed around "how many tonnes are in
the depot", it cannot be built against this API today.

What exists is two much narrower things.

### 4a. Sellability — `GET /mobile/materials/{material}/availability`

A **live call to SAP** asking whether a material may be sold into a sales area. Not a
quantity — a verdict with its reasoning.

```
GET /mobile/materials/2400001439/availability?salesOrg=1000&disChannel=10&division=10&plant=1001
```

```json
{
  "material": "2400001439",
  "isSellable": false,
  "summary": "Material is not available for sale in 1000/10. 1 blocking issue(s) found.",
  "checks": [
    { "sequence": "001", "checkId": "MATERIAL",    "status": "S", "message": "Material 2400001439 exists.",                    "isVerdict": false },
    { "sequence": "002", "checkId": "SALES_VIEW",  "status": "E", "message": "Material is not extended to sales area 1000/10.", "isVerdict": false },
    { "sequence": "003", "checkId": "RESULT",      "status": "E", "message": "Material is not available for sale in 1000/10. 1 blocking issue(s) found.", "isVerdict": true }
  ]
}
```

| Parameter | Required by SAP |
|---|---|
| `salesOrg` | Yes |
| `disChannel` | Yes |
| `division` | Yes |
| `plant` | Optional |

**Read `isSellable` for the decision and `checks` for the explanation.** The check with
`isVerdict: true` is the conclusion; the others are the working. `status` is SAP's:
`S` success, `E` error. Showing the failing check's `message` is the difference between
"cannot sell this" and "not extended to sales area 1000/10", and only the second lets a
rep phone the right person.

Omit the sales-area parameters and SAP answers `isSellable: false` with
`"Validation not performed. Mandatory input parameters are missing."` — **a 200, not an
error.** Do not read that as "out of stock". Check for the `INPUT_*` check ids and treat
them as a client bug.

This is a live SAP round trip, so it is slow and it fails when the middleware is down.
Call it when the rep commits to a material, not while they browse.

### 4b. Stock level as the rep sees it — the visit push

The rep's own observation, sent with a visit, in
`POST /mobile/visits/push` (`mobile-integration-guide.md` §7, ⧉ backend repo; the mobile-side contract is [my-visits/api.md](../../my-visits/api.md)):

```json
"stockUpdates": [{
  "id": "…", "stopId": "…", "depotId": "…",
  "productId": "…", "productName": "…",
  "stockLevel": "low",
  "notes": null
}]
```

Three coarse bands, judged by eye on a shop floor, not a counted figure — a rep walking a
yard estimates, and asking for a number would produce a precise-looking one that is
wrong. This flows **from** the app; it is not a stock feed you can read back.

---

## 5. Order capture

There is no order endpoint on the mobile surface yet. The rep's order lines are captured
as part of a visit — `orderLines` in the visit push, carrying `productId`, `quantity`,
`unit` and `unitPrice`.

**`unitPrice` is a number your app must supply,** because nothing serves it. See below.

---

## 6. Price does not exist yet

Nothing in this API returns a price. To be specific about what is missing:

- No price list, price condition, or scale endpoint
- No depot-specific or contract pricing
- No currency on any material response
- `priceGroup` / `priceGroupName` are classification codes, not amounts

Yet the visit push accepts `unitPrice` on every order line. **That number has to come
from somewhere, and today the only place is the app or the rep.** Which means order
values captured in the field are only as trustworthy as whatever the handset was told.

That is a gap to close on the backend, not to work around on the handset. Until it is
closed, be explicit in the UI about where a price came from, and do not present a
rep-entered figure as a quotation.

---

## 7. If you get 403 on everything

A `403` with no `errorCode` body on every materials endpoint means the caller's role does
not hold `materials.read` in the database — not that the app is doing anything wrong.

This happened for real: the Materials module added `materials.read` to the permission
catalogue two weeks after the Sales Representative role was created, so no existing role
ever received it, and every rep got 403 on every catalogue screen while the endpoints
themselves worked perfectly.

The seeder now grants catalogue permissions introduced after a role was created, so this
self-corrects on the next deployment. If you still see it, the fix is on the roles screen,
not in the app.

---

## 8. Checklist

- [ ] Guided selection is the primary path; the flat 13,499-row list is for search only
- [ ] The wizard is **rendered from `selection/schema`** — steps, labels, widgets and
      units are not hard-coded
- [ ] `label` used as-is; it is already localised
- [ ] `unitSuffix` and `decimals` applied to numeric steps
- [ ] Only categories with `hasPublishedSchema: true` are offered
- [ ] `matchCount` shown on every facet option
- [ ] "Show materials" disabled until one step is answered — `Material.SelectionNotBounded`
      is prevented, not caught
- [ ] `{attribute, selection}` vs `{selection, page, pageSize}` bodies not mixed up
- [ ] `excludeBlocked: true` on any path leading to order capture
- [ ] `baseUnit` read per material, never assumed
- [ ] `saleThicknessMm` displayed, not `rawThicknessMm`
- [ ] `priceGroup` never shown as a price
- [ ] Availability called on commit, not on browse; `isSellable` for the verdict and the
      failing `checks[].message` for the reason
- [ ] `INPUT_*` check ids treated as a client bug, not as "out of stock"
- [ ] No screen promises on-hand quantity — it does not exist

---

## See also

- `mobile-integration-guide.md` (⧉ backend repo) — envelopes, auth, errors, the endpoint map
- `Material SAP API Integration – Backend .NET README.md` (⧉ backend repo) — the SAP side
- `https://<host>/docs` — interactive reference, mobile audience
