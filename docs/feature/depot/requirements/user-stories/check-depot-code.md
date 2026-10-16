# US-06 — Check a Depot Code Before Registering

**Role:** Sales Representative
**Use case:** [UC-04 Look Up Depot By Code](../usecases/lookup-depot-by-code.md)
**API:** `GET /api/v1/depots/by-code/{code}`
**Screen:** Registration identity step · `DepotCodeLookupCubit`

---

## Story

> As a **Sales Representative**,
> I want to **check whether a depot code already exists before I register it**,
> so that **I do not create a duplicate business partner in SAP**.

---

## Why this story matters more than it looks

A duplicate business partner in SAP is expensive to unwind — it splits a
customer's order history, credit and statements across two records. This check
is the only thing standing between a rep and that outcome.

## Acceptance criteria

- [ ] Entering a depot code triggers a lookup (debounced).
- [ ] **Found** → the existing depot is shown and registration is blocked.
- [ ] **Not found** → the rep may continue registering.
- [ ] **ERP unavailable** → registration is **blocked**, with a message saying the check could not be completed.
- [ ] The three outcomes are visually and semantically distinct. "Unavailable" must never look like "not found".
- [ ] The rep can retry the check.
- [ ] The lookup does not block typing.

## Main scenario

1. Rep types `KH-PP-00412`.
2. `GET /api/v1/depots/by-code/KH-PP-00412`.
3. `404` → `DepotCodeAbsent` → "Available — continue".

## Alternative scenarios

| Response | Mobile state | What the rep sees |
|---|---|---|
| `200` with a depot | `DepotCodeFound` | The existing depot; registration blocked |
| `200` with an empty payload | `DepotCodeAbsent` | Available |
| `404` | `DepotCodeAbsent` | Available |
| **`502`** | **`DepotCodeUnavailable`** | **"Could not verify — try again." Registration blocked** |

## Validation / error scenarios

| Condition | Expected |
|---|---|
| Empty code | No request sent |
| Transport failure | `ApiException` → retryable error, registration blocked |
| **`502` presented as "not found"** | **Defect.** Creates duplicate SAP business partners (BR-17) |
| Response parsed with `ApiEnvelope` | **Defect.** This endpoint uses the portal `{data, meta}` envelope and would be rejected — see [UC-04](../usecases/lookup-depot-by-code.md#-this-is-the-portal-surface-not-the-mobile-one) |
