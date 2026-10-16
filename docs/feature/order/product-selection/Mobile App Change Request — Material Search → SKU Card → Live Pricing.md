# Mobile App Change Request — Material Search → SKU Card → Live Pricing

## Objective

Update the **mobile app only** for the quotation/material-selection workflow.

Do **not** redesign or modify the web application, backend business rules, SAP services, or unrelated modules.

The goal is to change how a sales representative searches for and selects materials/SKUs inside the mobile quotation builder.

### New UX Flow

```text
Quotation Builder
      ↓
Search Material
      ↓
Search results
      ↓
SKU / Material Cards
      ↓
User selects a SKU
      ↓
Selected SKU becomes a Material Card
      ↓
Request depot-specific price from backend
      ↓
Show price on Material Card
      ↓
Connect/subscribe to SignalR pricing
      ↓
Realtime price update
      ↓
Update Material Card automatically
```

---

# 1. Mobile App Only

All implementation must be limited to the Flutter/mobile application.

Do NOT:

- modify web UI
- create web components
- change backend pricing logic
- duplicate SAP pricing logic inside Flutter
- calculate the SAP price locally
- create a second pricing API
- modify unrelated quotation/order flows

Reuse the existing mobile architecture:

- Clean Architecture
- Repository pattern
- Use cases
- Bloc/Cubit
- existing CartCubit
- existing quotation flow
- existing product/material entities where appropriate

Follow the existing `lib/features/order/` structure.

---

# 2. Change Material Search Flow

The current product finder is:

```text
Category
→ SAP-defined filter steps
→ Products
→ Add to cart
```

Change the mobile UX so the representative can directly search for a material/SKU and see matching SKU cards.

The search must support the existing searchable material fields:

- Material code
- SKU
- Product code
- Product name
- Barcode
- Description

Keep the existing query sanitization rules, including support for:

- `-`
- `.`
- `/`
- Khmer Unicode combining marks

Do not break existing Khmer search behavior.

---

# 3. Search Result UI

When the representative searches for a material, display results as **compact SKU Material Cards**.

Do NOT display a large product-detail page for every result.

Each result card should be clean and mobile-friendly.

### SKU Card

Display approximately:

```text
┌────────────────────────────────────┐
│ SKU / Material                     │
│ 1100000000                         │
│                                    │
│ GI Steel Sheet                     │
│ Material description...            │
│                                    │
│ Grade      Gauge       Stock       │
│ S250       0.50 mm     Available   │
│                                    │
│                    [ Select ]      │
└────────────────────────────────────┘
```

Keep the card compact.

The primary purpose of the card is to help the sales representative identify the correct SKU quickly.

Do not show unnecessary information.

---

# 4. SKU Selection

When the user taps/selects a SKU:

```text
Search Results
      ↓
Selected SKU
      ↓
Material Card
```

The selected SKU must move into the quotation's **Material Card / quotation line area**.

Do not require the user to manually re-enter the material code.

The selected material should retain its complete identity:

- material code
- SKU
- product ID if available
- description
- unit
- depot
- quotation context
- selected quantity

Use the existing cart/quotation architecture instead of creating a parallel temporary cart system.

---

# 5. Material Card After Selection

Once selected, render the material as a compact quotation Material Card.

Example:

```text
┌────────────────────────────────────┐
│ GI Steel Sheet                     │
│ SKU: 1100000000                    │
│                                    │
│ Price                              │
│ $1,250.50 / unit                   │
│                                    │
│ Qty        −   1   +               │
│                                    │
│ Total                              │
│ $1,250.50                          │
│                                    │
│ ● Live price                       │
└────────────────────────────────────┘
```

The card must support:

- quantity increase/decrease
- remove material
- price display
- currency display
- loading price state
- unavailable price state
- realtime price update state

Use the existing `CartCubit` and cart line binding wherever possible.

---

# 6. Depot-Specific Pricing

After the user selects a material, request the current price from the backend.

The pricing request must use the selected depot's ID.

Use the existing mobile pricing endpoint:

```text
GET /api/v1/mobile/pricing/depots/{depotId}
```

Pass the selected material using the repeatable `materials` query parameter.

Example concept:

```text
GET /api/v1/mobile/pricing/depots/{depotId}?materials=1100000000
```

For multiple selected materials, support the backend's repeatable material parameter rather than creating individual unrelated pricing implementations.

The backend response contains:

```text
material
price
currency
validFrom
validTo
```

Use the returned values directly.

### IMPORTANT

Never calculate or synthesize the SAP/depot price inside Flutter.

Flutter must display the price returned by the backend.

---

# 7. Pricing Loading State

Immediately after selecting a material:

```text
Material Selected
      ↓
Material Card appears
      ↓
Price = Loading...
      ↓
REST pricing request
      ↓
Price returned
      ↓
Render actual price
```

Example:

```text
GI Steel Sheet
SKU: 1100000000

Price
Loading current price...
```

Do not block the entire quotation screen while waiting for pricing.

Only the selected Material Card should show its pricing loading state.

---

# 8. Pricing Error State

If pricing fails, do not remove the selected material.

Keep the Material Card visible.

Display a compact state such as:

```text
Price unavailable
Tap to retry
```

Differentiate between:

- no price
- unauthorized
- depot not found
- depot not priceable
- backend/SAP unavailable
- network unavailable

Do not silently replace a failed live price with a fake/local calculated price.

---

# 9. SignalR Realtime Pricing

Implement realtime pricing updates in the mobile app using the existing pricing hub.

Hub:

```text
wss://<host>/hubs/pricing?access_token=<accessToken>
```

The access token must be supplied through the SignalR/WebSocket connection according to the existing backend contract.

Do not invent another authentication mechanism.

---

# 10. SignalR Depot Subscription

After the initial REST pricing request succeeds, connect to the pricing hub and subscribe to the selected depot.

Use:

```text
SubscribeToPricingAsync(depotId)
```

The client must send the **depot ID**, never a manually constructed group name.

The server determines the depot's pricing group.

When the quotation/depot context changes:

```text
Unsubscribe old depot
        ↓
Subscribe new depot
```

Do not leave stale depot subscriptions active.

---

# 11. PricingUpdated Event

Listen for:

```text
PricingUpdated
```

The event contains:

```text
items:
  material
  price
  currency
  validFrom
  validTo

updatedAt
```

The mobile app should update the corresponding Material Card automatically.

Example:

```text
Old:

GI Steel Sheet
$1,250.50

        ↓ PricingUpdated

New:

GI Steel Sheet
$1,275.00
● Price updated
```

Do not require the representative to refresh the quotation manually.

---

# 12. Prevent Stale Price Updates

Store the latest known pricing timestamp.

For every `PricingUpdated` event:

```text
if updatedAt > lastKnownUpdatedAt:
    update price
else:
    ignore event
```

Never allow an older SignalR event to overwrite a newer price.

Follow the existing mobile pricing contract.

---

# 13. Reconnection Behaviour

SignalR group membership does not survive a disconnected connection.

Therefore:

```text
Connection lost
      ↓
Reconnect
      ↓
GET pricing from REST again
      ↓
SubscribeToPricingAsync(depotId)
      ↓
Resume PricingUpdated listener
```

The REST request after reconnection is mandatory.

Do not depend on SignalR replaying missed events.

---

# 14. Recommended Mobile Architecture

Keep pricing responsibilities separated.

Suggested structure:

```text
lib/features/order/

data/
  models/
    mobile_price_item.dart

  remote/
    pricing_remote_data_source.dart
    pricing_signalr_data_source.dart

  repositories/
    pricing_repository_impl.dart

domain/
  entities/
    mobile_price.dart

  repositories/
    pricing_repository.dart

  usecases/
    get_depot_material_price.dart
    subscribe_to_depot_pricing.dart
    unsubscribe_from_depot_pricing.dart

presentation/
  bloc/
    material_search_bloc.dart
    pricing_cubit.dart
    product_filter_flow_bloc.dart

  widgets/
    material_search/
      material_search_bar.dart
      sku_material_card.dart
      selected_material_card.dart
      material_price_view.dart
      pricing_status_indicator.dart
```

Adapt this structure to the existing project instead of blindly creating duplicate classes.

---

# 15. State Management

Create a dedicated pricing state or extend the existing pricing implementation.

Pricing state should be able to represent:

```text
initial
loading
loaded
updated
unavailable
error
reconnecting
```

Each material should be independently trackable.

For example:

```text
Material A → $100 → live
Material B → $250 → live
Material C → loading
Material D → unavailable
```

One failed material price must not break the pricing state of the other materials.

---

# 16. Multiple Materials

The quotation can contain multiple selected SKUs.

Example:

```text
Depot: ABC Construction

Material Card
SKU A
$100

Material Card
SKU B
$250

Material Card
SKU C
$75
```

Pricing must be mapped by material code.

When a `PricingUpdated` event contains:

```text
material: SKU B
```

only SKU B's Material Card should update.

Do not rebuild or overwrite unrelated material prices.

---

# 17. Cart / Quotation Integration

The selected SKU must integrate with the existing cart flow.

Follow the current architecture where quantity changes are the actual cart commit.

The new selection flow must not create a second cart implementation.

Maintain compatibility with:

- `CartCubit`
- `CartLineBinding`
- quotation saving
- quotation editing
- sales-order creation
- existing quantity behaviour
- existing line discounts
- existing totals

The current documentation specifies that `CartCubit.addProduct` merges lines according to the existing product/depot/lead rules. Preserve that behavior.

---

# 18. Offline Behaviour

The application is offline-first, but pricing is live backend/SAP data.

Therefore:

### Offline

```text
Search cached material
        ↓
Select SKU
        ↓
Material Card appears
        ↓
Live price unavailable
```

Do not invent a live SAP price while offline.

If an existing cached price is intentionally available in the current architecture, clearly label it as cached/stale rather than presenting it as a live price.

### Online

```text
Select SKU
→ REST pricing
→ show current price
→ SignalR subscription
→ realtime updates
```

The existing architecture already treats live SAP availability as connectivity-dependent and non-blocking.

---

# 19. Search UX

Keep the search interface fast.

Requirements:

- debounce search
- avoid duplicate requests
- cancel obsolete searches
- show loading state
- show empty state
- show clear-search action
- support Khmer
- support material codes containing `-`, `.`, `/`
- preserve existing barcode/voice/image search behavior where already implemented

Do not remove existing search modalities unless required for the new SKU flow.

---

# 20. Important Existing Gap

The documentation currently says:

> The SKU step is specified but not built.

Treat this implementation as the mobile-side completion of the SKU selection experience.

Do not invent a new SAP filter hierarchy.

The backend remains the authority for material/pricing data.

---

# 21. UI Design Requirements

The UI must be optimized for a sales representative using a phone in the field.

Design principles:

- compact
- fast
- clean
- easy to scan
- minimal taps
- large enough touch targets
- clear SKU/material identity
- price visually prominent
- quantity controls simple
- no unnecessary screens
- no desktop/tablet-oriented layout

Preferred structure:

```text
┌──────────────────────────────┐
│ ← Quotation                  │
│                              │
│ Search material...       🔍   │
│                              │
│ ┌──────────────────────────┐ │
│ │ SKU: 1100000000           │ │
│ │ GI Steel Sheet            │ │
│ │ S250 · 0.50mm             │ │
│ │ Stock: Available          │ │
│ │                 [Select]  │ │
│ └──────────────────────────┘ │
│                              │
│ Selected Materials           │
│                              │
│ ┌──────────────────────────┐ │
│ │ GI Steel Sheet            │ │
│ │ SKU: 1100000000           │ │
│ │                            │ │
│ │ $1,250.50 / unit          │ │
│ │ ● Live price              │ │
│ │                            │ │
│ │ Qty   −   1   +           │ │
│ └──────────────────────────┘ │
│                              │
│ ──────────────────────────── │
│ Total: $1,250.50             │
│                              │
│ [ Continue / Save Quote ]    │
└──────────────────────────────┘
```

Keep the result card and selected Material Card visually distinct.

---

# 22. Do Not Break Existing Workflow

Existing flow outside material search must continue working:

```text
Territory
→ Shop
→ Shop Order Entry
→ Quotation Builder
→ Material Selection
→ Cart
→ Save Quotation
→ Quotation Detail
→ Sales Order
```

Only replace/improve the **material search and SKU selection portion**.

Do not remove:

- territory selection
- shop selection
- off-visit handling
- quotation saving
- quotation editing
- sales order creation
- cart persistence
- existing synchronization
- existing depot context

---

# 23. Implementation Tasks

Before coding:

1. Inspect the existing Flutter order feature.
2. Find the current material/product search implementation.
3. Find `ProductFilterFlowBloc`.
4. Find `CatalogBloc`.
5. Find `CartCubit`.
6. Find `CartLineBinding`.
7. Find existing `GetPricing` use case.
8. Find existing pricing repository/data source.
9. Find existing authentication/token provider.
10. Check whether SignalR is already available in the project.
11. Reuse existing infrastructure whenever possible.
12. Only create new classes where the current architecture does not already provide the required capability.

Then implement:

### Phase 1 — Search

- Update material search UX.
- Render SKU/material result cards.
- Support direct material/SKU search.
- Preserve existing search behavior.

### Phase 2 — Selection

- Select SKU.
- Convert selected result into Material Card.
- Integrate with CartCubit.
- Preserve quantity behavior.

### Phase 3 — REST Pricing

- Request depot-specific price after selection.
- Render loading state.
- Render returned price/currency.
- Handle errors without removing the material.

### Phase 4 — SignalR

- Connect to `/hubs/pricing`.
- Authenticate with access token.
- Subscribe to depot.
- Listen for `PricingUpdated`.
- Map updates by material code.
- Ignore stale `updatedAt`.
- Re-fetch REST pricing after reconnect.
- Re-subscribe after reconnect.

### Phase 5 — Testing

Add/update tests for:

- material search
- SKU result rendering
- SKU selection
- Material Card creation
- depot-specific pricing
- pricing loading
- pricing error
- multiple material prices
- SignalR price update
- stale event rejection
- reconnect
- unsubscribe/subscribe when depot changes
- offline pricing state
- cart integration
- quotation save/edit compatibility

---

# 24. Acceptance Criteria

The implementation is complete only when all of these work:

### Search

- [ ] User can search material/SKU directly.
- [ ] Results display as compact SKU Material Cards.
- [ ] Material code search works.
- [ ] SKU search works.
- [ ] Khmer search remains functional.
- [ ] Hyphen/dot/slash material codes remain searchable.

### Selection

- [ ] User can select a SKU.
- [ ] Selected SKU becomes a Material Card.
- [ ] No manual material-code entry is required.
- [ ] Quantity is connected to the existing cart system.

### Pricing

- [ ] Depot ID is used for pricing.
- [ ] Material code is sent to the pricing endpoint.
- [ ] Price comes from backend.
- [ ] Currency comes from backend.
- [ ] No local SAP price calculation exists.
- [ ] Loading/error states are handled per material.

### Realtime

- [ ] Mobile connects to `/hubs/pricing`.
- [ ] Access token is used for the connection.
- [ ] Depot subscription uses `SubscribeToPricingAsync(depotId)`.
- [ ] `PricingUpdated` updates the correct Material Card.
- [ ] Older events cannot overwrite newer pricing.
- [ ] Reconnection performs REST re-fetch.
- [ ] Reconnection performs depot re-subscription.
- [ ] Depot changes correctly unsubscribe the previous depot.

### Mobile UX

- [ ] No web implementation.
- [ ] UI is optimized for mobile.
- [ ] Material search is fast.
- [ ] Pricing does not block the whole quotation screen.
- [ ] Multiple selected materials work independently.
- [ ] Existing quotation/cart flow remains functional.

---

## Final Instruction

Do not implement this as a visual-only UI change.

Trace the complete flow through:

```text
Search
→ SKU result
→ Selection
→ Material Card
→ Cart
→ Depot context
→ REST pricing
→ SignalR connection
→ Depot subscription
→ PricingUpdated
→ Material Card update
→ Quotation totals
```

Use the existing project architecture and existing API contracts wherever possible.

Before changing code, identify which existing classes can be reused and which genuinely need modification.

Keep the implementation **mobile-only, production-ready, offline-aware, depot-specific, and realtime-price capable**.