# Order — Workflow & Structure

Sales-catalog / quotation / sales-order feature for field reps. Offline-first: the product catalog is synced into a local DB and browsed offline; cart, quotation, and sales-order data are purely local (SAP is mocked at the point of "conversion", not synced in the background).

## 1. Folder structure (clean architecture)

```
order/
├── data/
│   ├── local/         # sqlite catalog DB, cart/product/quotation/sales-order local sources
│   ├── mock/           # mock product generator (dev backend)
│   ├── models/         # ProductModel, CategoryModel (DTOs)
│   ├── remote/         # ProductRemoteDataSource + RemoteSyncPage / RemoteDeltaPage
│   ├── repositories/    # repository implementations
│   └── services/        # MockCreditService, MockMtoPricingService
├── domain/
│   ├── entities/        # Product, CartItem, Quotation, SalesOrder, OffVisitReason, MtoQuote, CreditSummary, ...
│   ├── repositories/     # abstract repository contracts
│   ├── services/         # BarcodeScannerService, VoiceSearchService, ImageSearchService, CreditService, MtoPricingService, OrderLocationService
│   └── usecases/          # one class per action (BrowseProducts, SaveQuotation, CreateSalesOrder, ...)
├── presentation/
│   ├── bloc/               # CartCubit, CatalogBloc, ProductDetailCubit, SyncCubit
│   ├── screens/            # see workflow below
│   ├── widgets/            # product cards, cart tiles, discount section, credit card, etc.
│   └── services/           # real implementations (mobile_scanner, speech_to_text, image_picker, geolocator)
└── order_injection.dart      # DI wiring
```

## 2. Three entry points

### A. Direct / tab entry (full path, off-visit gate always applies)
`OrderScreen` (bottom-nav tab) → `TerritoryScreen` → `ShopListScreen` → `ShopOrderEntryScreen` → `QuotationBuilderScreen`

### B. Hand-off from `my_visits` (Route Stock Count)
`RouteStockCountScreen` ("Build Quotation") pushes straight into `ShopListScreen(territory:, skipOffVisitCheck: true, seedSearchTerm: <out-of-stock item>)` — skips territory-picking's need and the off-visit gate, since the rep is provably already on a checked-in visit, and pre-seeds the catalog search.

### C. Hand-off from Lead
`LeadDetailScreen` opens `QuotationBuilderScreen(leadId:, leadDisplayName:)` directly — no territory/shop/off-visit steps, because a lead has no SAP `Depot` record yet. Lead-scoped quotations **cannot** be converted to a sales order later.

## 3. Step-by-step: full order path

| Step | Screen | What happens | Next |
|---|---|---|---|
| 0 | `OrderScreen` | Tab root. Shows "New Order" button + merged recent list of quotations/sales orders (`WatchQuotations`/`WatchSalesOrders`) | "New Order" → Step 1 |
| 1 | `TerritoryScreen` | Lists territories grouped from `BrowseDepots`, with shop counts | Tap territory → Step 2 |
| 2 | `ShopListScreen` | Lists shops in the territory, each with a lazily-loaded credit badge | Tap shop → Step 3 |
| 3 | `ShopOrderEntryScreen` | Shows shop info, credit summary, captures GPS once. If not skipped, blocks progress until an `OffVisitReason` is picked via a bottom sheet | "Start Quotation" → Step 4 |
| 4 | `QuotationBuilderScreen` | **Guided product configurator** (see §11) — category → SAP-defined filter hierarchy → products → add-to-cart. Then discounts, cart preview. Sync runs on init | "Save" → Step 5 |
| 5 | `QuotationDetailScreen` | Read-only summary of the saved quotation (lines, totals, status). "Convert to Sales Order" is disabled for lead-scoped quotations | "Convert" → Step 6, or "Edit Quotation" → back to Step 4 (edit mode) |
| 6 | `SalesOrderScreen` | Editable line list seeded from the quotation (qty change/remove), "Create Sales Order in SAP" (mocked — freezes totals, no repricing) | Success → Step 7 |
| 7 | `OrderSuccessScreen` | Terminal screen — shows the confirmed sales order. "Done" pops to app root | — |

Search modalities (barcode, voice, image) all resolve to a text query and feed the same `CatalogBloc` pipeline (barcode is the exception — it resolves directly to a single product via `GetProductByBarcode`, though it isn't currently wired to a button in the search bar).

## 4. State machines

**`QuotationStatus`**: `draft` (transient, UI-only, never persisted) → `saved` (persisted/editable) → `converted` (intended once a sales order is created — note: `SalesOrderRepositoryImpl.createFromQuotation` does not appear to call `markConverted`, worth verifying whether this transition actually fires).

**`SalesOrderStatus`**: two-value enum `{pending, confirmed}` — `pending` is never assigned in practice; every created sales order jumps straight to `confirmed` (mocked SAP confirmation, no repricing).

**`ProductStatus`**: `active / inactive / discontinued`. `Product.isAvailable` requires `availableQuantity > 0 && status == active`.

## 5. State management (bloc/cubit)

- **`CartCubit`** — in-memory + locally-persisted cart. `addProduct` merges into an existing line by product+lead+depot; `loadFromQuotation` seeds the cart from a saved quotation (edit / convert-to-sales-order flows); `saveQuotation` creates or updates a `Quotation` and clears the cart on success.
- **`CatalogBloc`** — paginated (30/page) product grid. `CatalogIdle` landing state means no fetch until the first query/filter. Uses `droppable()` for load/refresh/loadMore and `restartable()` for search/filter/voice/image so fast typing never races. All four query types funnel through one shared `_runQuery()`; search is debounced 300ms.
- **`ProductDetailCubit`** — powers the inline expanded product detail (variants, per-warehouse stock, favorite, records as "recently viewed").
- **`SyncCubit`** — `syncIfNeeded()` runs full initial sync if never synced; `refresh()` always runs delta sync. Drives the sync status banner.

## 6. Domain usecases (grouped)

- **Catalog browsing/search**: `BrowseProducts`, `FetchBrands`, `FetchCategories`, `FetchFavorites`, `FetchRecentProducts`, `GetProductByBarcode`, `GetProductById`, `GetProductVariants`, `GetProductsByCategory`, `GetWarehouseStock`, `RecordViewed`, `ToggleFavorite`, `GetPricing`
- **Cart**: `AddToCart`, `UpdateCartItem`, `RemoveFromCart`, `ClearCart`, `FetchCart`, `ReplaceCart`
- **Quotation**: `SaveQuotation`, `UpdateQuotation`, `GetQuotationById`, `WatchQuotations`
- **Sales order**: `CreateSalesOrder`, `GetSalesOrderById`, `WatchSalesOrders`
- **Sync**: `RunInitialSync`, `RunDeltaSync`, `GetLastSyncedAt`
- **MTO pricing**: `RequestMtoQuote`
- **Credit**: `GetCreditSummary`
- **Location**: `CaptureLocationOnce` (one-shot GPS snapshot, distinct from `my_visits`' continuous route tracking)

## 7. Off-visit handling

- **`OffVisitReason`**: `phoneOrder | urgentRestock | passingBy` — why a rep is ordering without being on a scheduled/checked-in visit.
- **`skipOffVisitCheck`**: threaded `ShopListScreen → ShopOrderEntryScreen`, default `false` (gate on for the direct/tab path). Only the `my_visits` Route Stock Count hand-off sets it `true`.
- **Gate behavior**: not a hard block — the rep simply cannot proceed to the builder without picking a reason from the bottom sheet; dismissing the sheet just leaves them on the entry screen. Once picked, the reason is stored on the quotation/sales order and shown later on `OrderSuccessScreen`/`QuotationDetailScreen`.

## 8. MTO pricing & credit check (both advisory, non-blocking)

- **MTO pricing** (`MtoPricingService`/`RequestMtoQuote`) — for `Product.isMto` SKUs, pricing is never resolved from the local table; always a fresh "SAP" quote request. Mock: offline → unavailable message; online → `standardPrice * 1.15` with a "confirm with SAP" disclaimer.
- **Credit check** (`CreditService`/`GetCreditSummary`) — outstanding balance + credit/debit notes, deterministically mocked per depot. Purely informational — nothing blocks quotation/order creation on a bad credit position; the UI just displays the badge (and hides itself if the lookup is unavailable).

## 9. Sync

Same idle/in-progress/succeeded/failed cubit shape as `my_visits`' route sync, but catalog-scoped only (products + categories), keyed by `SyncScope.forCurrentUser`. `SyncRepositoryImpl` is the only repository allowed to touch `ProductRemoteDataSource`. Initial sync pages through the backend (500/page), upserting products after each page and syncing all categories up front. Delta sync fetches everything changed since the last sync (falls back to a full initial sync if never synced) and applies upserts + deletes. Cart/quotation/sales-order data is never synced remotely — it's purely local, "SAP" is only mocked at the point of conversion.

## 11. Product finder (quotation product selection)

Entering a quotation no longer loads a product list. Screen order is fixed:

```
Search + Filter  (always visible, every stage)
Active filter chips
Category → [SAP-defined steps, one at a time] → Products
Cart summary + Find New Product
```

**Two ways in, both bounded.** A new rep walks the hierarchy; an experienced rep types a material code from the category screen and gets products immediately. `ProductFilterFlowBloc` has one call site for `BrowseProducts`, gated on `hasSearch || isFilterComplete` — browsing must finish the hierarchy, searching must clear `minQueryLength` (2). Nothing else can reach the catalog, so an idle screen still can't pull the whole product list.

Search covers code, name, SKU, barcode, **material code** and description. Query sanitisation keeps `-`, `.` and `/` — stripping them made every hyphenated material-code search unmatchable.

**Quantity is the commit.** There is no Add button. `CartQuantityStepper` on each card writes straight through `CartLineBinding` to `CartCubit`: zero removes the line, above zero creates or updates it. `CartLineBinding` mirrors `CartCubit.addProduct`'s own merge rule (product + unit + lead + depot, customized lines excluded) so the two can't disagree about what "the same line" is.

**Find New Product** clears category, steps, search and results, keeps the cart, and returns to category selection — the "next line item" action.

**Filter button** (always visible) opens `FilterOptionsSheet`: sort, in-stock-only, per-chip clearing and clear-all. Those are preferences *over* the result set, so they re-run the query but never invalidate an answered step.

**Removed from the builder**: the unit picker, the standalone quantity stepper, and the header discount-percentage chips. The header discount was preview-only — it was never persisted (`SaveQuotation` takes no discount argument), so removing it changes no stored quotation. Per-line discounts (`CartItem.discountPercent`, `CartCubit.updateDiscount`) are untouched and still reach the totals through the cart subtotal.

**Where the hierarchy comes from.** The steps a category exposes — which ones, in what order, under what business label, rendered as chips or a grid — are published by SAP (`ProductFilterRemoteDataSource`, mocked by `isi_filter_schema_data.dart`). Nothing in `presentation/` or `domain/` knows that Palm walks Profile → Family → Thickness → Colour → Length while DeBar walks Diameter → Grade → Length. Adding a level is a backend change.

**Where the values come from.** Option values are `SELECT DISTINCT … GROUP BY` aggregates over the locally synced catalog (`CatalogDao.distinctFacetValues`), narrowed by every answer above. Consequences:

- Each level costs one query returning a few dozen short strings, regardless of catalog size — a 100k-SKU catalog is walkable offline.
- An option that matches nothing is never offered, so the flow is dead-end free.
- A step with no options for the current path is **skipped**, not shown empty — which is what lets one generic fallback schema serve categories of very different attribute coverage.

**Layers**

| Layer | Type |
|---|---|
| Entities | `filter/{filter_step, filter_option, filter_selection, category_filter_schema, product_attribute}.dart` |
| Repository | `ProductFilterRepository` → `ProductFilterRepositoryImpl` (remote schema + local facet values) |
| Usecases | `FetchFilterCategories`, `GetCategoryFilterSchema`, `GetFilterStepOptions` (+ existing `BrowseProducts` for the final page) |
| Bloc | `ProductFilterFlowBloc` — owns the entire flow; the only call site for `BrowseProducts`, reachable only once every required step is answered |
| Widgets | `widgets/filter_flow/` — `product_search_bar`, `category_selector`, `product_family_selector`, `dynamic_filter_section`, `filter_chip_bar`, `filter_options_sheet`, `product_result_grid`, `product_result_card`, `cart_quantity_stepper`, `cart_summary_bar`, `find_new_product_button`, `empty_products`, `loading_products`, `filter_flow_transition`, `guided_product_filter_view` |
| Cart plumbing | `cart_line_binding.dart` — the one translation from "stepper reads N" to a `CartCubit` add/update/remove |

**Invalidation rule** (in `FilterSelection`, not the bloc): answering or clearing a step drops every answer below it, plus the product list. Removing the Thickness chip clears Length and the results but keeps Category + Family.

**Search** appears only once products are resolved, and narrows within them (name / code / material code / description via the existing `BrowseProducts` LIKE query). Voice and photo lookup feed the same query.

**Demo data.** `isi_demo_catalog.dart` — 10 categories transcribed from the real SAP material master (`SAP_BP_Data.pbix`): Palm Profile Roofing, PU Insulated Panels, Roofing Accessories, Cold Formed Sections, Galvanized Pipes, K-Pipe, GI Steel Sheet, GI Steel Bending, Reinforcement (traded), Beams (traded) — x **exactly 6 SKUs each**, so every branch of every schema is walkable end to end. Material numbers, descriptions (English + Khmer), grades, gauges and net weights are verbatim SAP values; only price is synthesized. `mock_product_data.dart` generates the traded/MRO bulk catalog on top, which still exercises paging. Category ids across the two never collide — a generated row landing in an ISI category would inject invented gauges into the guided flow.

**Sync triggering.** `SyncCubit.syncIfNeeded()` pulls when the device has never synced **or** when it holds a sync timestamp with an empty catalog. The timestamp alone is not evidence: a device that synced under a previous taxonomy carries a valid date over zero products, and keying off the date read that as "nothing to do" — the empty category picker with no way to recover. When the timestamp and the catalog disagree, the catalog wins. Both finder hosts provide `SyncCubit` themselves and reload the flow on `SyncSucceeded`, so neither depends on whichever screen the rep arrived from having synced.

**Category sync.** Categories are reference data with no tombstone, so `SyncRepositoryImpl._syncCategories()` fetches the full list and calls `pruneCategoriesNotIn` on **both** the initial and delta paths. Delta matters most: a device that had already synced would otherwise pull changed products forever and never learn the taxonomy moved, showing an empty category picker over a full catalog. Schema v14 clears catalog tables + `catalog_sync_meta` so existing installs re-pull rather than delta against ids that no longer exist.

**Khmer search.** The query sanitizer keeps `\p{L}\p{N}\p{M}` — the `\p{M}` is load-bearing. Khmer builds a syllable from a base consonant plus combining marks, all category M; dropping them shatters one word into space-separated consonants that LIKE can never match. Covered by a test that pulls a real Khmer word out of the catalog rather than hardcoding one.

## 10. Known gaps / things to verify or flag

- Barcode scanning (`BarcodeScannerService`/`GetProductByBarcode`) exists end-to-end but isn't currently wired to a button in `CatalogSearchBar` — dead entry point until hooked up.
- `QuotationStatus.converted` may never actually get set — `SalesOrderRepositoryImpl.createFromQuotation` doesn't appear to call `markConverted()` on the source quotation. Worth confirming before relying on that status in reporting/UI.
- `OrderSuccessScreen`'s `onNewOrder` callback is scaffolded (doc comment says it's meant to be hidden for Lead/Route-Stock-Count entry points) but is never actually passed from `SalesOrderScreen` today — the "New Order" action is unreachable.
- Tapping a confirmed sales-order row on `OrderScreen`'s recent list does nothing (`onTap: null`) — only quotations are tappable there.
- `ShopListScreen.seedSearchTerm` (the out-of-stock item handed over from Route Stock Count) no longer pre-seeds a catalog search — the guided configurator has no catalog-wide search to seed. Tagged `TODO(order)` in `shop_order_entry_screen.dart`; wants a SAP product → category resolve endpoint so the hand-off can pre-select a category instead.
- `CatalogBloc` and `widgets/catalog/product_lists_section.dart` are no longer used by the quotation builder or the filter screen. Left in place rather than deleted in the same change — removing them is a separate refactor.
