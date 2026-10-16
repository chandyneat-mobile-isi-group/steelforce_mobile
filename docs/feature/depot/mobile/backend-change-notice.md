# Backend change notice — bind to the real keys

**To:** Mobile (Flutter) team
**Date:** 2026-09-16
**Action required:** yes — one endpoint constant, and stop hardcoding eight values

---

## What changed on the backend

Three things, in the order they affect you:

1. **The routes moved.** `/mobile/customers` → `/mobile/depots`. The old path still
   works — see [Deprecation](#deprecation).
2. **A new endpoint exists** that returns real outlet data the app was previously
   inventing: `GET /mobile/depots/{id}/stop-information`.
3. **Eight values the stop screen hardcoded are now real.** Five still are not, and are
   marked as such.

Everything below is taken from the C# contracts, not from prose. If a key here disagrees
with what the server sends, the server is right and this document is a bug.

---

## 1 · The endpoint constant

```dart
// lib/core/network/api/api_endpoints.dart
static const String customersEndpoint = '$apiPrefix/mobile/depots';
```

Already applied. It is also the **entire revert** — no other client code refers to the
path.

---

## 2 · The endpoint, and its exact keys

```
GET /api/v1/mobile/depots/{depotId}/stop-information
```

- **Permission:** `customers.read`
- **200** on success · **404** when the outlet does not exist **or you are not entitled
  to see it** — the two are deliberately indistinguishable, so do not treat 404 as
  "deleted"
- `{depotId}` is a GUID — the same `customerId` the route sync already gives you on each
  stop

### The response, key for key

```jsonc
{
  "success": true,
  "message": "…",
  "data": {
    "customer": {                        // ← still "customer", by design
      "id":         "01a03189-…",
      "code":       "6100000123",
      "name":       "Sok Heng Hardware",
      "nameKh":     "ហាង សុខ ហេង",        // null when none — not ""
      "contact":    "Sok Heng",           // null when nobody recorded
      "phone":      "012345678",
      "address":    "Street 271, Chamkarmon, Phnom Penh",
      "telegram":   "phnom_penh_steel_outlet",   // NO leading @ — see below
      "outletType": "Wholesaler"
    },
    "financial": {
      "creditLimit":      { "amount": 50000.00, "currency": "USD" },
      "creditLimitDate":  "2026-08-10T00:00:00+00:00",
      "creditBalance":    { "amount": 12500.00, "currency": "USD" },
      "availableCredit":  { "amount": 37500.00, "currency": "USD" },
      "currency":         "USD",
      "paymentTermCode":  "T030",
      "paymentTermLabel": "30 days due net",
      "paymentTermDays":  30
    }
  },
  "metadata": null,
  "traceId": "0HNO1GJO3S25K:00000001"
}
```

**`data.customer`, not `data.depot`.** The route says depot because that is the business
word; the payload keeps SAP's word because renaming response fields is a wire break this
change deliberately did not take. See
[depot-terminology-migration.md](depot-terminology-migration.md).

### Key-by-key binding rules

| Key | Type | Bind it like this |
|---|---|---|
| `customer.code` | string | The SAP outlet number. A locally registered outlet carries a `BP-…` placeholder until SAP names it |
| `customer.nameKh` | string **or null** | **Null**, not `""`. The route sync's `nameKh` uses `""` — a different contract. Do not share a parser |
| `customer.contact` | string or null | Null means nobody was recorded. Show "Not recorded" — never a placeholder name |
| `customer.telegram` | string or null | **Stored without `@`.** Add it for display: `'@${telegram}'`. Send it either way |
| `customer.outletType` | string | `Retailer` · `Wholesaler` · `Distributor` · `KeyAccount` |
| `financial.creditLimit` | `{amount, currency}` | **Zero is a real answer** — cash-only trade. Not "unknown", do not re-default it |
| `financial.creditLimitDate` | ISO-8601 or null | When **SAP** last set the limit. Read it as the age of the figure |
| `financial.availableCredit` | `{amount, currency}` | Limit − balance, computed server-side. **Do not recompute** — a client that does can disagree with the server about an outlet's headroom |
| `financial.paymentTermLabel` | string **or null** | Null means the catalogue has no entry for the code. **Fall back to `paymentTermCode`.** The server will not echo the code back as a label, so null genuinely means unresolved |
| `financial.paymentTermDays` | int or null | SAP's net days. Distinct from the platform's own `creditTermDays` |

> **Money is always `{amount, currency}`**, never a bare number. A client rendering
> `1500.00` without knowing whether it is dollars or riel is one careless screen away
> from a 4000× error in front of an outlet owner.

---

## 3 · Stop hardcoding these eight

The stop screen was showing constants. These are now real — bind them:

| Was hardcoded | Bind to |
|---|---|
| `'026 407 480'` | `customer.phone` |
| `'BP-884920'` | `customer.code` |
| `'Yim Vithou'` | `customer.contact` |
| `'St. 218, Mean Chey'` | `customer.address` |
| `'WHS / Retail'` | `customer.outletType` |
| `'@phnom_penh_steel_outlet'` | `customer.telegram` |
| `'$50,000'` | `financial.creditLimit` |
| `'30 Days Net'` | `financial.paymentTermLabel` ?? `paymentTermCode` |

**Do not bind outlet type to `territoryType`** from the route sync. It derives from the
same source but collapses `Distributor` and `Wholesaler` both onto `"industrial"`, so the
original value cannot be recovered from it.

---

## 4 · Five values are still not real — mark them

These have no source in any system yet, each blocked on a business rule nobody has
decided:

| Field | Blocked on | Why |
|---|---|---|
| Outlet Tier | OBD-1 | No tiers, thresholds or owner defined anywhere |
| Outlet Action | OBD-2 | No assignment process for Attack / Defend / Maintain |
| Payment Status | OBD-3 | **No invoice, due date or receivable exists** — "Overdue" is uncomputable. "Blocked" is |
| Avg Rev per Order | OBD-6 | Undecided which quotation statuses count as a won order |
| Latest Order Date | OBD-6 | Same |

**Show them as plainly marked examples, not as data.** The screen now renders these
italic and muted with an "Example" chip — a rep can then tell at a glance which figures
are real.

This matters more than it sounds: a rep quoting "$50,000 credit limit" to an outlet owner
from a hardcoded constant is worse than showing nothing. The chip is what prevents that.

Register: [open-business-decisions.md](../../../../requirement/open-business-decisions.md).

---

## Deprecation

`/mobile/customers` is still served, from the same controller, and behaves identically.
It is **deprecated, not removed** — every handset in the field is compiled against it.

Verified 2026-09-16 against a running API:

```text
401  /api/v1/mobile/depots
401  /api/v1/mobile/customers
401  /api/v1/mobile/depots/{id}/stop-information
401  /api/v1/mobile/customers/{id}/stop-information
```

401 rather than 404 — all four routes exist and authentication engaged.

There is **no removal date**: the telemetry needed to prove nothing calls the old path
does not exist yet. Do not plan against one, and do not build anything new against
`/mobile/customers`.

---

## Checklist

- [x] `AppConstants.customersEndpoint` → `/mobile/depots`
- [x] Fetch `stop-information` when a stop is opened, not with the route sync
- [x] Bind the eight real values
- [x] Mark the five unresolved ones as examples
- [ ] UI labels "Customer" → "Depot" — 163 entries × 2 languages, **not a
      find-and-replace**; see
      [depot-terminology-migration.md](depot-terminology-migration.md) for which ones
      must be left alone
- [ ] Nothing new built against `/mobile/customers`

---

## Related

- [depot-terminology-migration.md](depot-terminology-migration.md) — why routes say depot
  and payloads say customer, and the label rules
- [stop-information.md](stop-information.md) — the endpoint in full
- [ADR-0007](../../../../adr/ADR-0007-depot-terminology-at-the-api-boundary.md) — the
  decision and its accepted costs
