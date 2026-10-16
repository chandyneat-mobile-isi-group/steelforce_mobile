# Depot Mobile Registration — Overview

The Sales Rep "Register New Business Partner" flow: load the SAP dropdowns, open a
prefilled draft, save as they type, submit.

Implemented at `/api/v1/mobile/depots/{references,draft,update,submit}`.

---

## The flow

```mermaid
flowchart TD
    A[Open Create Depot] --> B[GET references<br/>9 catalogues · 4.5 KB · 98 ms]
    B --> C[POST draft<br/>server state, 8 fields prefilled]
    C --> D[Rep types]
    D --> E[POST update<br/>patch, one field at a time]
    E --> D
    D --> F[POST submit]
    F --> G{Complete?}
    G -->|no| H[400 + per-field errors]
    H --> D
    G -->|yes| I[Depot created<br/>sapStatus = Submitted]
    I --> J[Appears in GET /mobile/depots]
    J --> K[push-pending delivers it to SAP later]

    L[Sales employee search<br/>?kinds=SalesEmployee&search=leng] -.-> D

    style C fill:#fff3cd,stroke:#d39e00,stroke-width:2px
    style I fill:#e8f4fd,stroke:#2a7ab0
```

---

## Three decisions worth knowing

### 1. The draft is server-side state, and not a `Depot`

A `Depot` guarantees it has a name, a telephone and an address — that guarantee is
what lets the rest of the platform route, call and visit one. A half-filled form
satisfies none of it, and relaxing the aggregate so an empty shell could exist would
weaken **every** depot in the database to serve one screen.

So `DepotDraft` is its own aggregate: 46 nullable strings shaped exactly like SAP's
`BpCreateRequestDto`. It becomes a real `Depot` on submit, and only then are the
invariants enforced. Because it lives on the server, a handset that dies mid-form
loses nothing.

### 2. The helper catalogues are synced, never called live

Measured against the live middleware, the ten `CustHelper` endpoints range from
**0.2 s to never completing**. A form that fetched them on open would be slow at best
and broken at worst.

They are synced into `depot_references` and served from there — **98 ms, works with
the radio off**. Refreshed daily at 03:00 UTC, as requested.

### 3. Sales employees are a search box, not a dropdown

There are **5,809** of them. Returning them with the other nine made the form-open
response **252 KB** — about ten seconds on a provincial 3G link, for a list nobody
scrolls.

They are excluded from the bulk response (now **4.5 KB**) and fetched with
`?kinds=SalesEmployee&search=leng` (2.3 KB, 48 matches).

---

## What already existed and was reused

This feature is mostly wiring, not new machinery. Already present before this work:

| Existing | Reused for |
|---|---|
| `SapBpWriteRequest` (46 fields) | The draft's field set matches it exactly |
| `CreateBusinessPartnerCommand` | Submit delegates the whole draft→depot mapping to it |
| `SapRegistrationStatus` | `Submitted` is the status the list shows |
| `POST /depots/sap/push-pending` | Delivers submitted depots to SAP |
| `ISapDepotService` | Extended with the helper-catalogue read |
| `DatabaseSeeder`, Hangfire scheduler | One more idempotent step, one more daily job |

**No new SAP write endpoint was built.** Submission still goes through the existing
`CreateCust` push, exactly as you said it should.

---

## Documents

| Document | What it covers |
|---|---|
| [`docs/feature/depot/registration/api.md`](api.md) | The endpoints, with verified request and response shapes |
| [`docs/feature/depot/registration/sap-helpers.md`](sap-helpers.md) | All ten catalogues as the live API actually returns them |
| [`implementation.md`](backend-implementation.md) | Files, database, verification, limitations |
| [`business-partner-changes.md`](business-partner-changes.md) | Mobile hand-off notes for the Business Partner submit path: what changed, and the open product decisions (moved here from `lib/features/depots/`) |
