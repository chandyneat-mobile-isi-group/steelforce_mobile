# Pricing

**Purpose:** one depot's SAP selling prices, delivered to the field app and the
admin portal, with a realtime channel that pushes changes as they happen.
**Scope:** the pricing read path, the SignalR hub, and the SAP condition-record
boundary. There is no pricing aggregate and no pricing table.
**Status:** Active · **Last updated:** 2026-09-03

**Implementation:** `src/ISI.Application/Features/Pricing/` ·
`src/ISI.Api/Controllers/Pricing/` · `src/ISI.Api/Realtime/` ·
`src/ISI.Infrastructure/Services/SapPricingService.cs`

---

## Documents

| Document | Contains | State |
|---|---|---|
| [overview.md](overview.md) | What the feature is and the guarantee it keeps | ✅ |
| [architecture.md](architecture.md) | The pieces, the layering, and the realtime seam | ✅ |
| [sap-integration.md](sap-integration.md) | The SAP pricing contract — captured and pinned | ✅ |
| [security.md](security.md) | Permissions, row-level scoping, group isolation | ✅ |
| [testing.md](testing.md) | Coverage, and what could not be tested here | ⚠️ |
| [test-data.md](test-data.md) | Real SAP data, and what to test against | ✅ |
| [mobile-upgrade-workflow.md](mobile-upgrade-workflow.md) | Migrating the Flutter app onto the real SAP integration | ✅ |
| [api/mobile.md](api/mobile.md) | The Flutter pricing surface and the hub | ✅ |
| [api/admin.md](api/admin.md) | Admin portal read and the publish trigger | ✅ |

---

## In one paragraph

A price is the one thing on this platform that must never be served stale, so
pricing is **not** database-first. Every read goes to SAP's
`GET /api/Pricing/GetPriceByPaging` for the depot's sales organisation and price
group, valid today; nothing is cached and there is no pricing sync. REST answers
"what is the price now", and a SignalR hub pushes `PricingUpdated` when something
changes — a client loads state over REST and subscribes for the deltas. Both
surfaces, and the background publish path, go through one `IPricingService`, so a
price shown in the portal, a price shown on a handset, and a price pushed over the
socket are the same number from the same call.

---

## The one thing to know before changing this

**A price is `price` + `currency` + `pricingUnit` + `conditionUnit`, together.** This
catalogue is quoted in eight units — `BAG`, `KG`, `M`, `PAC`, `PC`, `ROL`, `SET`,
`UNI` — so rendering the number alone is not showing a price, it is showing a number
that means eight different things. The realtime payload and the REST payload carry the same four
fields for that reason.

**The reads are paged, and the realtime broadcast is not.** `GET` returns 50 of 3,869
records; `PricingUpdated` still carries every one. See the note in
[test-data.md](test-data.md).

Two more things worth knowing before you change the mapping:

- **The response contract is verified** — captured from `Live110` on 2026-09-10, with
  3,869 rows mapping and 0 unmapped. `SapPriceDto` declares the real names; the alias
  lists remain only as a fallback.
- **There is no mock.** It was deleted with the block it existed for. Nothing in this
  feature can produce a price the ERP did not send.

See [sap-integration.md](sap-integration.md) before touching the mapping.

---

## Related

- [blueprint/sap-api-catalogue.md](../../blueprint/sap-api-catalogue.md) — the endpoint catalogue
- [feature/depot/](../depot/) — the sales area and price group pricing is keyed on
- [feature/material/](../material/) — the catalogue prices are quoted against
