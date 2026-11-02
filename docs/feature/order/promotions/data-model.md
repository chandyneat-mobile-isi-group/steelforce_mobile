# Promotions & Discounts — Data Model

**What it is:** the nine tables the feature owns, and why each column is there.
**Status:** Active · **Last updated:** 2026-09-12
**Migration:** `20260912055024_AddPromotionsAndAgreements`

PostgreSQL through EF Core. GUID v7 keys, snake_case columns, `timestamptz`
throughout, `numeric(18,6)` for money, `numeric(9,4)` for percentages, audit columns
stamped by `AuditableEntityInterceptor`.

The plan's ERD covers 22 tables. Nine are built; the rest belong to rebates, campaigns
and free goods, which are blocked — see [README.md](README.md#what-is-not-built).

---

## The shape in one picture

```text
category_mappings ──── joins a material's SAP price group to a category
        │
        │ (by category_code, not a foreign key)
        ▼
agreement_requests ──┬── agreement_request_lines ──── agreement_request_tiers
                     │            │
                     │            │ snapshot on the 4th approval
                     │            ▼
                     │     agreement_terms ──── agreement_term_tiers
                     │            │
                     │            └──── sap_tasks   (condition maintenance queue)
                     │
                     └── agreement_approval_steps   (4 slots per revision)

pickup_rules ──── standing order-term rate, no approval chain
```

---

## `agreement_requests`

What was asked for. Soft-deletable, audited, optimistic concurrency via `version`.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | `AgreementRequestId` |
| `request_number` | varchar(32) | `AGR-2026-000045`. **Unique** |
| `scope_type` | int | `Depot` = 0. `Segment` = 1 is declared and refused |
| `depot_id` | uuid | The depot |
| `requested_by` | uuid | The representative. The row-level scoping key |
| `client_request_id` | varchar(64) | **Unique.** The device's own key, so an offline draft syncing twice creates one request |
| `source_channel` | varchar(16) | `Mobile`, `Portal` or `Import` |
| `remarks` | varchar(2048) | The commercial reasoning every approver reads |
| `status` | int | Nine values, from `Draft` to `Withdrawn` |
| `revision` | int | Incremented on every return |
| `current_step` | int, null | 1–4, or null when off the chain |
| `submitted_at` · `completed_at` | timestamptz, null | |

**Indexes** — `number` (unique), `client_request_id` (unique), `(status, current_step)`
for the approval inbox, `(depot_id, status)`, `requested_by`.

**Why `client_request_id` is a unique index and not a handler check.** The handler does
look for an existing request first, but two syncs racing would both find nothing. The
database is what actually makes the sync idempotent.

---

## `agreement_request_lines` and `agreement_request_tiers`

Part of the request aggregate; cascade-deleted with it, and **hard**-deleted, because a
line the representative removed from a draft is not a record of anything.

| `agreement_request_lines` | Type | Notes |
|---|---|---|
| `request_id` | uuid | |
| `category_code` | varchar(32) | |
| `entry_mode` | int | `FLAT_PERCENT` / `TIERED` / `NO_TARGET` — **the BRD's words** |
| `nature` | int | `OnInvoice` / `VolumeRebate` / `ImmediatePayment` — **what the domain reasons about** |
| `percent` | numeric(9,4), null | Null on a tiered line |
| `currency` | varchar(4) | `US3` by default |
| `valid_from` · `valid_to` | date | `valid_to` null means open-ended |

**Two vocabularies, deliberately.** `entry_mode` is what the form says because that is
how the business talks; `nature` is *when the discount is earned*, which is the only
thing the calculator cares about. A "flat percent with a monthly target" is a rebate
however the form describes it, and conflating the two is what made the BRD ambiguous.

| `agreement_request_tiers` | Type | Notes |
|---|---|---|
| `line_id` | uuid | |
| `tier_order` | int | 1-based. **Unique** with `line_id` |
| `min_amount` | numeric(18,6) | Inclusive floor |
| `max_amount` | numeric(18,6), null | Exclusive ceiling; null only on the top rung |
| `percent` | numeric(9,4) | |

**Index:** `(request_id, category_code)` unique — one rate per category, so the
database says what the aggregate says.

---

## `agreement_approval_steps`

One row per signature slot per revision. All four are written when the request is
submitted, not one at a time.

| Column | Type | Notes |
|---|---|---|
| `request_id` | uuid | |
| `revision` | int | Which version of the document this signature was given to |
| `step_order` | int | 1–4 |
| `label` · `permission` | varchar | Copied from the template, so a timeline stays readable after the chain is reconfigured |
| `status` | int | `Waiting` · `Pending` · `Completed` · `Returned` · `Rejected` |
| `outcome` | int, null | What the approver chose |
| `acted_by_user_id` · `acted_at` | | |
| `comment` | varchar(2048) | Mandatory on return and reject |
| `due_at` | timestamptz, null | Advisory. Nothing escalates on it yet |

**Index:** `(request_id, revision, step_order)` unique — a second row for one step
would mean two people signed one signature line.

**Why all four rows up front.** The mobile timeline shows the whole chain from the
moment a request is submitted, so a representative can see how many signatures are
still to come rather than having them revealed one at a time.

**Why `revision` is on the row.** A return restarts the chain. Without it, a timeline
would show four signatures given to three different versions of the document.

---

## `agreement_terms`

What four people approved. **Immutable** except `state` and `valid_to`.

| Column | Type | Notes |
|---|---|---|
| `term_number` | varchar(32) | `AG-2026-0045`. **Unique.** What a quotation line points at, and what the SD team quotes |
| `depot_id` · `category_code` · `nature` | | The scope |
| `percent` | numeric(9,4), null | Null on a tiered term |
| `currency` | varchar(4) | |
| `valid_from` · `valid_to` | date | `valid_to` moves on supersede and terminate, and only then |
| `state` | int | `Approved` · `Effective` · `SapMismatch` · `Superseded` · `Expired` · `Terminated` |
| `source_request_id` · `source_revision` | | Traceability back to exactly which version was signed |
| `sap_condition_record` | varchar(32), null | SAP's `KNUMH`, once confirmed |
| `verified_at` | timestamptz, null | |
| `terminated_by` · `termination_reason` | | |

**Indexes** — `term_number` (unique), `(depot_id, category_code, state)` for the
lookup a quotation runs on every depot it prices, `(state, valid_from)` for "what is
approved but not yet effective", `source_request_id`.

### The exclusion constraint

```sql
ALTER TABLE agreement_terms
ADD CONSTRAINT exclude_overlapping_effective_terms
EXCLUDE USING gist (
    depot_id WITH =,
    category_code WITH =,
    nature WITH =,
    daterange(valid_from, COALESCE(valid_to, 'infinity'::date), '[]') WITH &&
) WHERE (state = 1 AND scope_type = 0);
```

Added by hand in the migration because EF Core cannot express one, and needs
`btree_gist`. `state = 1` is `Effective`; `scope_type = 0` is `Depot`.

**Why the database and not just the domain.** The domain checks overlap at submit and
again at final approval, and neither can cover a bulk import, a hand-run data fix, or
two approvals committing in the same instant. One depot holding two effective rates for
one category is a commercial guarantee, so it belongs where nothing can route around it.

`agreement_term_tiers` mirrors the request tiers, with `ON DELETE RESTRICT` — a tier
the approvers signed is part of what was approved, and a term is never deleted anyway.

---

## `sap_tasks`

The SD team's condition-maintenance queue. Exists because the middleware cannot write
condition records.

| Column | Type | Notes |
|---|---|---|
| `term_id` | uuid | |
| `task_type` | int | `CreateCondition` on approval, `EndDateCondition` on supersede or terminate |
| `status` | int | `Pending` · `InProgress` · `Completed` · `Failed` |
| `assigned_to` | uuid, null | |
| `due_at` · `completed_at` | timestamptz | 24-hour SLA from approval |
| `resolution_notes` | varchar(1024) | Carries the `KNUMH` that was created |

**Index:** `(status, due_at)` — the queue, oldest deadline first, which is how the SD
team works it.

**Closing a `CreateCondition` task is what makes a term `Effective`.** That is the
whole mechanism, and it is the honest answer to *"why is this depot not getting its
discount?"* — the task is either still pending, or it was closed and the term is live.

---

## `category_mappings`

| Column | Type | Notes |
|---|---|---|
| `category_code` | varchar(32) | **Unique.** `REBAR`, `ROOFING_PROFILE` |
| `sap_material_price_group` | varchar(8) | **Unique.** SAP's `KONDM` |
| `description` | varchar(128) | |
| `is_active` | boolean | Retired rather than deleted — terms reference the code |

**Both columns are unique.** One price group mapping to two categories would make a
material's category ambiguous, and a quotation would silently pick whichever came back
first.

**Ships empty** — this is D14, and only the business can answer it.

---

## `pickup_rules`

| Column | Type | Notes |
|---|---|---|
| `name` | varchar(64) | |
| `region_code` · `category_code` | varchar(32), null | Null means "everywhere" / "everything" |
| `percent` | numeric(9,4) | |
| `valid_from` · `valid_to` | date | |
| `is_active` | boolean | |
| `sap_condition_type` | varchar(8) | `ZPKP` placeholder until SD confirms |

**Index:** `(is_active, valid_from)`.

**Ships with none configured** — this is D13. Until Commercial sets one, no pickup
discount is applied anywhere.

---

## What it borrows

| Table | Used for |
|---|---|
| `depots` | The depot's trading name, and the ownership rule that scopes every read |
| `materials` | The price group that resolves a quotation line's category |
| `quotation_lines` · `quotation_line_discounts` | Where an agreement rate lands as a deduction, with `source_reference` carrying the term number |

No rebate, campaign, free-goods, billing-snapshot or generic approval-template table
exists. The approval chain is a reviewable catalogue in code
(`AgreementApprovalTemplate`), following the `PermissionCatalog` convention; the plan's
`approval_template_steps` table is its destination once a second subject type needs a
different chain.

---

## Known compromise: document numbers

`AgreementNumberFactory` derives both sequences by counting rows for the year and
stepping past anything taken — the same approach, and the same compromise, as
`QuotationNumberFactory`. Two requests created in the same instant can compute the same
candidate, and the unique index is what stops both being stored. A PostgreSQL sequence
is the proper fix and needs a migration that creates one.
