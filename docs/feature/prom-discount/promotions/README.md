# Promotions & Discounts Architecture

> **Feature:** Promotions & Commercial Discounts  
> **Location:** `docs/feature/promotions/`  
> **Code:** `lib/features/order/domain/entities/promotion/`, `lib/features/order/presentation/widgets/quotation/`, `lib/features/order/presentation/screens/quotation/`, `lib/shared/widgets/promotions/`  
> **Verified Against:** branch `web` (2026-09-11)


> [!WARNING]
> **This documents the Flutter mobile application, not the backend**, and was copied
> into the backend repository from the mobile one (`lib/…`, branch `web`). Its file
> paths do not resolve here.
>
> **Parts of it are superseded.** The backend now owns the arithmetic it describes:
>
> | This document says | What the server does now |
> |---|---|
> | Rep line discount `0% – 10%` | The limit is served by `GET /api/v1/mobile/me/discount-authority` (3% by default) and enforced server-side. Exceeding it is *accepted* and escalates |
> | Manual USD price override when unpriced | Refused. The quotation API prices every line from SAP; a SAP outage answers `502`, never an input box |
> | Free-goods ladder evaluated on the phone | Not built anywhere. `POST /promotions/evaluate` does not exist |
> | On-invoice depot discount as a client-side scheme | Applied by the server from an **effective** agreement term, and never from an approved-but-unconfirmed one |
> | COD / Pickup as one discount | Two different things. Pickup is who moves the goods; COD is how the depot pays. Only pickup earns the rate |
>
> For the endpoints and their actual behaviour see [../api/mobile.md](../api/mobile.md);
> for what is built see [../README.md](../README.md).

---

## 1. Overview & Business Purpose

In ISI Steel sales operations, **promotions** and **discounts** represent distinct commercial incentives governed by separate business rules, approval processes, and accounting impacts.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      PROMOTIONS & DISCOUNTS ECOSYSTEM                       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         ▼                             ▼                             ▼
┌──────────────────┐          ┌──────────────────┐          ┌──────────────────┐
│  LINE DISCOUNTS  │          │ INVOICE SCHEMES  │          │   FREE GOODS     │
│ (SKU / Product)  │          │  (Order-Level)   │          │ (Quantity Tier)  │
├──────────────────┤          ├──────────────────┤          ├──────────────────┤
│ • Rep % discount │          │ • On-Invoice %   │          │ • Buy X Get Y    │
│ • Manual USD fix │          │ • COD / Pickup   │          │ • Non-monetary   │
│ • Per-line total │          │ • Volume rebate  │          │ • Separate units │
└──────────────────┘          └──────────────────┘          └──────────────────┘
```

The system enforces three fundamental rules across the mobile application:

1. **Free goods are never converted into cash discounts:**  
   Free units (e.g., *Buy 40 sheets, get 1 free*) are tracked as physical items and physical deliverables. They are never deducted from unit prices or subtotal calculations.
2. **Discounts reduce taxable subtotal before tax calculation:**  
   Both line-level SKU discounts and invoice-level term discounts reduce the gross subtotal to produce the net taxable base.
3. **Strict separation of discount origins:**  
   Sales reps, depots, and accounting can clearly inspect whether a price reduction originated from a line-item rep discretion, a depot campaign, an order fulfillment term (pickup vs. delivery), or an approved price request.

---

## 2. Core Concepts & Taxonomy

| Term / Mechanism | Domain / Scope | Value Type | Impact on Invoice / Quotation |
|---|---|---|---|
| **Rep Line Discount** | SKU / Line Item | Percentage (`0% – 10%`) | Reduces SKU line total: `lineTotal = (qty * unitPrice) * (1 - rate)` |
| **Manual Price Override** | SKU / Line Item | USD Unit Price | Replaces catalog/backend price when unpriced by HQ (`isManualPrice: true`) |
| **Free Goods Ladder** | SKU / Category | Integer Units (`buyXGetY`) | Awards free quantity; adds bonus note; zero impact on line price |
| **On-Invoice Depot Discount** | Category / Depot | Percentage / Fixed USD | Aggregated under Invoice Discounts in summary breakdown |
| **COD / Pickup Discount** | Order / Shipment | Percentage (e.g., `1%`) | Dynamic; earned **only** when `ShipmentMethod == pickup` |
| **Depot Request** | Outlet / Approval | Percentage (e.g., `1.5%`) | Pre-approval state (`pending`, `approved`); non-quotable until approved |

---

## 3. Directory & File Structure

```
lib/
├── features/
│   ├── order/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── cart_item.dart                   # Holds discountPercent, lineDiscount, unitPriceOverride
│   │   │   │   └── promotion/
│   │   │   │       ├── promotion.dart               # Free-goods ladder definition & depot eligibility
│   │   │   │       ├── promotion_tier.dart          # Tier rungs: minQuantity -> freeQuantity
│   │   │   │       └── promotion_evaluation.dart    # Evaluation verdict (earnedTier, nextTier, gap)
│   │   │   ├── repositories/
│   │   │   │   └── promotion_repository.dart        # Contract for promotion queries & evaluations
│   │   │   └── usecases/
│   │   │       ├── evaluate_promotion.dart          # Quantity-based line evaluation
│   │   │       └── get_promotions.dart              # Depot-scoped promotion list
│   │   ├── presentation/
│   │   │   ├── bloc/
│   │   │   │   └── promotion/
│   │   │   │       └── promotion_cubit.dart         # Debounced (220ms) material promotion cache
│   │   │   ├── screens/
│   │   │   │   └── quotation/
│   │   │   │       ├── quotation_builder_screen.dart # Host screen coordinating shipment, promos & cart
│   │   │   │       ├── promotion_section.dart        # Collapsible promo group block in builder
│   │   │   │       ├── promotion_detail_screen.dart  # Group expansion view
│   │   │   │       └── promotions_mock_data.dart     # Depot & term promotion catalog
│   │   │   └── widgets/
│   │   │       ├── promotion/
│   │   │       │   ├── cart_promotion_badge.dart     # Badge indicating earned or upcoming rungs
│   │   │       │   └── demo_cart_promotions.dart     # Free goods ladder evaluator for demo
│   │   │       └── quotation/
│   │   │           ├── discount_summary_section.dart # Structured summary breakdown (Invoice + SKU + Free)
│   │   │           ├── line_discount_chips.dart      # Inline chips for rep discount % & free goods
│   │   │           ├── manual_price_input_sheet.dart # Modal bottom sheet for manual price capture
│   │   │           ├── quotation_items_table.dart    # Enterprise quotation table with discount metrics
│   │   │           ├── quotation_preview_section.dart# Review card before final confirmation
│   │   │           └── shipment_widget_section.dart  # Pickup/COD terms and Type of Invoice selection
│   │   └── pdf/
│   │       ├── quotation_pdf_data.dart               # Flat DTO mapping SKU & invoice discounts
│   │       └── quotation_pdf_generator.dart          # PDF renderer with dedicated Discount column
│   └── my_visits/
│       └── presentation/screens/stop_information/
│           └── promotions_screen.dart                # Outlet visit promotion browser
└── shared/
    └── widgets/promotions/
        ├── promo_card.dart                           # Unified promotion card with countdown & urgency
        ├── promo_filter_bar.dart                     # Filter by PromoKind
        └── promo_view.dart                           # Shared UI model (PromoKind, OrderTerms, PromoValue)
```

---

## 4. State Management & Data Flow

### 4.1 PromotionCubit (`lib/features/order/presentation/bloc/promotion/promotion_cubit.dart`)

- **State:** `Map<String, PromotionEvaluation>` keyed by `materialCode`.
- **Debounced Resolution:** Uses a `220ms` debounce timer matching quantity steppers to avoid flooding backend pricing/promotion services while the user adjusts quantities.
- **Depot Scoping:** `setDepot(String? depotId)` resets all cached verdicts immediately to prevent negotiated terms from leaking between depots.

### 4.2 CartCubit (`lib/features/order/presentation/bloc/cart/cart_cubit.dart`)

- Tracks individual `CartItem` state.
- Stores `discountPercent` (rep discount).
- Stores `unitPriceOverride` and `isManualPrice` for lines requiring field-level pricing.
- Emits aggregated calculations:
  - `subtotal`: `sum(item.quantity * item.unitPrice)`
  - `discount`: `sum(item.lineDiscount)`

---

## 5. Summary of Key Workflows

Detailed step-by-step logic, state diagrams, and calculations are documented in [workflow.md](workflow.md):

1. **[Rep Line Discount & Manual Pricing](workflow.md#1-line-level-rep-discount--manual-pricing-flow)**
2. **[Free-Goods Quantity Ladders](workflow.md#2-free-goods-incentive-flow-buy-x-get-y)**
3. **[Order Terms & Pickup Discounts](workflow.md#3-order-terms--depot-pickup-discount-flow)**
4. **[Structured Breakdown & Invoicing Aggregation](workflow.md#4-structured-discount-breakdown--summary-aggregation)**
5. **[Type of Invoice & Tax Calculations](workflow.md#5-type-of-invoice--tax-interaction-flow)**
6. **[PDF Generation & Document Output](workflow.md#6-pdf-generation--commercial-document-flow)**
