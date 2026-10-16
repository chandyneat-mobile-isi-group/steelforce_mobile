# Quotations — Data Model

**What it is:** the three tables the feature owns, and why each column is there.
**Status:** Active · **Last updated:** 2026-09-11
**Migrations:** `20260911082009_AddQuotations`, `20260914065631_AddSapSubmissions`

PostgreSQL through EF Core. GUID v7 keys, snake_case columns, `timestamptz`
throughout, audit columns stamped by `AuditableEntityInterceptor`.

---

## `quotations`

The aggregate root. Soft-deletable, with `xmin`-style optimistic concurrency through
the platform's `version` column.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | `QuotationId`, time-ordered |
| `number` | varchar(32) | `QT-2026-000001`. **Unique.** Also the SAP depot reference, and therefore the reconciliation key |
| `depot_id` | uuid | The depot quoted |
| `owner_user_id` | uuid | The representative. The row-level scoping key |
| `sales_organization` · `distribution_channel` · `division` | varchar(8) | Copied from the depot's primary sales area at creation, not resolved later — a depot can move, and the document belongs to the area it was raised in |
| `status` | int | **Derived.** Written only by `RecomputeStatus()` |
| `approval_status` · `sap_quotation_status` · `sap_order_status` · `depot_decision` | int | The four dimensions `status` is derived from |
| `closure` | int, null | `Cancelled` or `Expired` — the two closings no dimension expresses |
| `shipment_type` | int | Pickup or Delivery |
| `ship_to` | varchar(512) | Required for Delivery |
| `payment_term` · `depot_reference` | varchar | Header fields the representative fills in |
| `remarks` | varchar(2048) | For the depot-facing document |
| `currency` | varchar(8) | **Nullable, and eight characters.** Null on an empty draft — the platform does not know what SAP prices this depot in until it asks. Eight rather than three because `US3` is a SAP currency key, not an ISO code |
| `valid_from` · `valid_to` | date | The platform's validity. SAP's dates will take over once SAP holds the document |
| `revision` | int | Incremented on every return |
| `required_approval_level` | int | Computed at submit from the largest manual discount, and stored so the queue can filter and the audit can say *why* |
| `submitted_at` · `decided_by` · `decided_at` · `decision_reason` | — | The approval trail's summary; the full trail is in `approval_records` |
| `sap_quotation_number` | varchar(32) | SAP's document number, set when a submission succeeds |
| `sap_order_number` | varchar(32) | Always null — sales orders are not built |
| `sap_submitted_at` · `sap_confirmed_at` | timestamptz, null | When the last attempt began, and when its answer was recorded |
| `estimate_net` | numeric(18,6) | The calculator's document total |
| `sap_net` | numeric(18,6), null | SAP's. **Still null** — nothing reads the priced document back yet, so totals stay estimates even after SAP holds the quotation |

**Why `numeric(18,6)` and not the platform's default `(18,4)`?** A `US3` unit price of
0.475 multiplied over a tonnage carries more significant digits than an invoice total
does. Storing at four would make the document disagree with the calculator that
produced it.

**Indexes**

| Index | Answers |
|---|---|
| `ix_quotations_number` (unique) | "Does this document number already exist?" — and stops two documents sharing a SAP reconciliation key |
| `ix_quotations_owner_status` | "What is on my list" — the representative's five tabs |
| `ix_quotations_status_level` | "What is waiting for me to approve" — the portal queue |
| `ix_quotations_depot` | "Everything quoted to this shop" |

---

## `quotation_lines`

Part of the aggregate: loaded through the backing field, cascade-deleted with the
document, and **hard**-deleted (a removed draft line is not a record of anything;
revision snapshots are the plan's answer to history).

| Column | Type | Notes |
|---|---|---|
| `id` · `quotation_id` | uuid | |
| `line_number` | int | One-based, renumbered when a line is removed |
| `material_number` | varchar(40) | SAP MATNR |
| `material_description` | varchar(512) | Captured when the line was added, not joined at read time — a material can be renamed in SAP, and the document should say what was offered |
| `quantity` | numeric(18,6) | In `unit` |
| `unit` | varchar(8) | Always equal to `price_condition_unit` in this release |
| `price_amount` · `price_currency` · `price_pricing_unit` · `price_condition_unit` | — | **The four fields of a price**, flattened from the `QuotationLinePrice` owned type so they cannot drift apart |
| `price_condition_record` | varchar(32) | Which of SAP's records was used. Null until the middleware returns one |
| `price_valid_from` · `price_valid_to` · `priced_at` | — | The offer's evidence. `priced_at` is the server's clock |
| `category` | varchar(64) | The product category an agreement rate is keyed on. Always null until the category mapping exists — carried now because backfilling it onto priced lines later is worse |
| `estimate_gross` · `estimate_discount_total` · `estimate_net` | numeric(18,6) | The calculator's output, written back on every mutation |
| `sap_item_number` · `sap_net` | — | Always null in this release |

**Index:** `ix_quotation_lines_quotation_material` (unique) — the aggregate refuses a
duplicate material and this is the database saying the same thing, so a concurrent add
cannot slip one past it.

---

## `quotation_line_discounts`

One row per deduction, **not** one column per kind.

| Column | Type | Notes |
|---|---|---|
| `id` · `line_id` | uuid | |
| `kind` | int | `Manual` · `Agreement` · `Pickup` · `Campaign`. Only `Manual` is written today |
| `percent` | numeric(9,4) | The rate. The client sends this; it never sends money |
| `source_reference` | varchar(128) | What authorised it — a user id today, an agreement term number later. Free text rather than a foreign key, because the four things it can point at live in four tables, two of which are not built |
| `sap_condition_type` | varchar(16) | What it will be sent to SAP as. Null until the SD session names the types |
| `estimate_amount` | numeric(18,6) | The calculator's figure |
| `sap_amount` | numeric(18,6), null | What SAP deducted. The gap between the two is how the platform learns it models a rule differently from SAP's pricing procedure |

**Why rows rather than columns?** There are eight incentives in the catalogue and a
line can carry several at once. Columns would mean a migration every time the business
invents a ninth, and no way to record the one thing that matters most — which rule or
approval produced *this* reduction.

---

## `sap_submissions`

The outbox. One row per attempt to put a document into SAP.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `quotation_id` | uuid | **No foreign key**, deliberately — an attempt record must outlive whatever happens to the quotation |
| `kind` | int | `Quotation` = 0, `SalesOrder` = 1 (declared, never written) |
| `attempt` | int | 1-based, per quotation |
| `idempotency_ref` | varchar(64) | The platform quotation number, sent as `PurchaseOrderNo`. **The key lookup-before-create searches on** |
| `state` | int | `Pending` · `Sent` · `Unknown` · `Succeeded` · `Failed` |
| `request_json` | jsonb | The payload, verbatim. A refusal is almost always explained by exactly what was sent |
| `response_status` | int, null | The HTTP status SAP answered with |
| `sap_document_number` | varchar(32), null | What SAP created |
| `sap_error_code` | varchar(64), null | Stable code, safe to return to a client |
| `sap_error_text` | varchar(4000), null | **SAP's own words. Server-side only** — names hosts, connection ids and ABAP objects |
| `correlation_id` | varchar(128), null | Joins a row to a log line |
| `started_at` · `completed_at` | timestamptz | |

**Indexes** — `(quotation_id, attempt)` for the attempt log, `state` for finding
unresolved attempts, `idempotency_ref` for reconciliation.

**Rows are appended and settled, never rewritten.** The history is the point: it is what
a support desk reads when a depot asks why their quotation is not in SAP, and what
stops a document SAP already holds being sent twice.

**`Unknown` is the state this table exists for.** A request that timed out after the
payload left the wire has not failed — SAP may hold the document — and retrying such an
attempt is how duplicates are made.

---

## What it borrows

| Table | Used for |
|---|---|
| `approval_records` | The append-only decision trail. `ApprovalSubject.Quotation` and `ApprovalAction.Returned` were added to the existing enums |
| `depots` | The trading name on a document header, projected to one column |
| `depot_sales_areas` | The SAP sales area copied onto the header at creation |
| `materials` | The description captured onto a line |

No pricing table is read or written. Prices come from SAP through `IPricingService` on
the request path — the platform holds no price list.

---

## Known compromise: the document number

`QuotationNumberFactory` derives the sequence by **counting** rows for the year and
stepping past any candidate already taken. Two quotations created in the same instant
can compute the same candidate; the unique index is what stops both being stored.

The proper fix is a PostgreSQL sequence, which needs a migration that creates one.
Worth doing before this carries real volume — recorded here rather than left to be
discovered.
