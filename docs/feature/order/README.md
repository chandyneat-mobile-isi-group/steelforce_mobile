# Order & Quotation

> **Purpose:** everything between "the rep knows what the depot wants" and "a
> sales order exists" — catalog browsing, guided material selection, cart,
> quotations, PDF output, and sales orders that eventually reach SAP.
> **Code:** `lib/features/order/`
> **Verified:** 2026-08-27, branch `web` @ `142de9b`.

The largest feature in the app: 14 screens, 48 widgets, 10 blocs, 43 use cases,
32 entities, 9 domain repositories.

---

## Documents

| Document | What it covers |
|---|---|
| [workflow.md](workflow.md) | Folder structure and the catalog → cart → quotation → sales-order workflow. |
| [product-selection/README.md](product-selection/README.md) | The guided material configurator — category → attribute steps → stock location → SKU → quotation line. Written for the SAP/middleware team. |
| [product-selection/api.md](product-selection/api.md) | Materials, stock, and price integration contract. Responses were executed against a live server and live SAP `Live110`. |
| [product-selection/availability.md](product-selection/availability.md) | How the client implements the sellability check — when the call is made, what is rendered, and which compromises were deliberate. |

---

## Screens

| Group | Screens |
|---|---|
| Catalog & finder | `order_screen.dart`, `product_filter_screen.dart`, `voice_search_screen.dart` |
| Customisation | `customized_product_form_screen.dart` |
| Quotation | `quotation_builder_screen.dart`, `quotation_detail_screen.dart`, `quotation_preview_screen.dart` |
| Sales order | `sales_order_screen.dart`, `sales_order_list_screen.dart`, `sales_order_detail_screen.dart`, `shop_list_screen.dart`, `shop_order_entry_screen.dart`, `order_success_screen.dart` |
| Territory | `territory_screen.dart` |

Reached via `MainShell` tab 3, or directly at `/order`.
`QuotationBuilderScreen` and `ShopListScreen` are resume targets for an
interrupted visit workflow.

---

## State

| Bloc / Cubit | Responsibility |
|---|---|
| `CatalogBloc` | Catalog browsing and search |
| `ProductFilterFlowBloc` | The guided multi-step material finder |
| `ProductDetailCubit` | One material, including live availability |
| `CustomizationCubit` | Made-to-order attribute capture and drawing upload |
| `CartCubit` | Cart lines |
| `PdfGenerationCubit` | Quotation / order PDF rendering |
| `SalesOrderListCubit` | Sales order list |
| `SyncCubit` / `PendingSyncCubit` | Outbound sync state and the pending-sync sheet |
| `ContinueWorkCubit` | Resume an in-progress quotation |

---

## API surface

Endpoint constants live in `lib/core/network/api/api_endpoints.dart` (`ApiEndpoints`).

| Endpoint | Purpose |
|---|---|
| `GET /api/v1/mobile/materials/selection/categories` | Stage zero — the categories that open the finder |
| `POST …/selection/schema` | The wizard's shape for a category. **Configuration, not data** — fetch once per session and cache. |
| `POST …/selection/facets` | Options for exactly one step (`{attribute, selection}`) |
| `POST …/selection/materials` | The terminal read. **Different body shape** — selection fields nested, not top-level, or it silently reads as an empty selection. |
| `GET /api/v1/materials/{material}/availability` | SAP's live sellability verdict. **Note the path** — not under `/mobile/`. |

All but the last read the platform's own synced copy of the material master,
which is why the finder keeps working when the ERP does not. Availability is a
**live SAP round trip**: slow, fails when the middleware is down, and must be
called only when a rep commits to a material — never while browsing.

---

## Data

| Domain repository | Purpose |
|---|---|
| `ProductRepository`, `CategoryRepository` | Catalog master data |
| `ProductFilterRepository` | Finder schema, facets, results |
| `MaterialAvailabilityRepository` | Live SAP sellability |
| `CartRepository` | Cart lines |
| `QuotationRepository`, `SalesOrderRepository` | Quotation and order documents |
| `SyncQueueRepository`, `SyncRepository` | The order → SAP queue |

Tables: `catalog_tables.dart`, `cart_items_table.dart`, `order_tables.dart`,
`syncable_table.dart`. DAOs: `catalog_dao.dart`, `cart_dao.dart`,
`order_dao.dart`.

The order → SAP `sync_queue` (with `attempt_count` / `next_retry_at` /
`last_error` and a FIFO backoff query) is **the only real sync queue in the
app** — the seed the unified engine of
[../../adr/ADR-0006-sync-engine.md](../../adr/ADR-0006-sync-engine.md) is meant
to generalise.

Master data is stored bilingually; `product_delta_preserves_khmer_test.dart`
guards that a delta sync cannot wipe Khmer content.

---

## Offline behaviour

| Action | Offline |
|---|---|
| Browse the synced catalog | ✅ Fully |
| Run the guided finder | ✅ If the schema and facets were cached this session |
| Build a cart, quotation, or sales order | ✅ Fully local |
| Generate and share a PDF | ✅ Fully local |
| Live SAP availability check | ❌ Requires connectivity; the UI must not block on it |
| Catalog delta sync | ❌ Queued; drains on reconnect |
| Order → SAP conversion | ❌ Enqueued in the same transaction as the write ([../../adr/ADR-0006-sync-engine.md](../../adr/ADR-0006-sync-engine.md)) |

---

## Tests

`test/features/order/` — 15 files: cart and product Drift data sources, catalog
localization and sync-to-finder, filter selection and facets, filter repository
and flow bloc, material availability, product result card stock status, SKU
identity, sales order list and detail screens, Khmer delta preservation.

---

## Known gaps

- **The SKU step is specified but not built** on either side — see
  [product-selection/README.md](product-selection/README.md) §6, marked **NEW**.
- **No feature-level architecture document.** [workflow.md](workflow.md) covers
  folder structure and flow, but with 43 use cases and 9 repositories this is
  the feature most in need of an `architecture.md`.
- **SAP conversion is mocked** at the point of conversion; orders are not
  background-synced.
- **No requirement documents** — pricing, discount, and approval rules are
  enforced in code without testable acceptance criteria.
- `fl_chart` is a declared dependency that nothing in this feature (or any
  other) uses.

---

## Related

- [../my-visits/README.md](../my-visits/README.md) — a stop pivots into a quotation here
- [../../blueprint/sync-architecture.md](../../blueprint/sync-architecture.md) — the queue this feature seeded
- [../../blueprint/diagrams/quotation-offline-sync-lifecycle.svg](../../blueprint/diagrams/quotation-offline-sync-lifecycle.svg)
- [../../skills/api-integration.md](../../skills/api-integration.md)
