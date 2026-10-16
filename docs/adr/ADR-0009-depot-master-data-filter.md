# ADR-009 — Depot filtering uses flat, locally-applicable criteria; SAP master data is a cached lookup, not a cascade

- Status: Accepted
- Date: 2026-07-20
- Supersedes: none
- Related: ADR-002 (offline-first), ADR-003 (repository pattern), `docs/blueprint/offline-architecture.md` §4

---

## Context

A redesign of the depot filter was requested, specifying a ten-level cascading
hierarchy mirroring SAP master-data dependencies:

```
Sales Organization → Distribution Channel → Division → Sales Office → Sales Group
→ Depot Group → Sales Employee → Payment Term → Shipping Condition → Price Group
```

with each selection reloading and resetting the levels beneath it.

`SapAPI_Technical_Document_v1_BP.docx` (v2.0, §4 "Depot Helper API") was read in
full before designing. It does not support that shape. Four findings, each verified
against the document:

1. **No parent scoping exists.** All Helper endpoints share one signature:
   `GET /api/CustHelper/{Action}/{conId}?<ownIdFilter>`. The optional query
   parameter is the entity's *own* identifier — `GetSalesOrg?organId=`,
   `GetDisChannel?channelId=`, `GetSalesGroup?groupId=`. No endpoint accepts a
   parent key, so "distribution channels for sales org 1000" is not expressible.

2. **Responses carry no foreign keys.** Rows are bare code/name pairs
   (`{salesOrg, salesOrgName}`, `{disChannel, disChannelName}`). The parent
   relationship is therefore not reconstructable client-side either — there is no
   data to cascade on, only an absent parameter.

3. **`GetDivision` does not exist.** The document defines nine Helper endpoints;
   Division is not among them. Division appears only as a *query filter* on
   `Depot/GetDetail` and `Depot/GetPaging`, never as a dropdown source.

4. **Only four criteria filter the depot list.** `Depot/GetPaging` accepts
   `depot`, `salesOrg`, `division`, and `enName`. Sales Office, Sales Group,
   Depot Group, Sales Employee, Payment Term, Shipping and Price Group have
   Helper endpoints that can *populate* a dropdown but no way to *apply* that
   selection to a depot query. Seven of the ten requested levels would be
   decorative.

Two further constraints from the current codebase:

5. **`core/network/sap_client.dart` is a 0-byte stub.** No SAP gateway, JWT
   handling, or `conId` configuration exists. `docs/skills/engineering-standard.md` §2
   forbids building a feature on absent infrastructure, and `docs/blueprint/system-architecture.md` §6
   tracks this gateway as a known gap.

6. **The local `Depot` entity has no sales-area columns.** It models
   `territory` / `province` / `district`, not `salesOrg` / `distributionChannel` /
   `division`. Filtering local data by SAP hierarchy would require a Drift schema
   migration — a `docs/skills/ai-engineering-playbook.md` §3 high-bar change.

## Decision

**1. The depot filter applies flat, locally-satisfiable criteria only.**
It filters on fields the local encrypted Drift database actually holds —
`status`, `territory`, `productCategory`, plus sort order. No filter control is
rendered for a criterion that cannot change the result set.

**2. SAP master data is modelled as a cached lookup list, not a dependency graph.**
A `MasterDataRepository` exposes each Helper list as an independent
`List<MasterDataItem>` (code + name). It deliberately has no `parent` parameter,
because the API has no parent concept. Adding one later is an additive change to
the interface, not a redesign.

**3. Master data is cached in Hive, not Drift.** Per `docs/blueprint/system-architecture.md` §3, Layer 2
is for "cached lookups the user can regenerate" — exactly this data. Reusing
`core/database/hive/local_cache.dart` (TTL + lazy eviction) avoids a schema
migration entirely, and correctly keeps non-business reference data out of the
encrypted relational store.

**4. The remote side stays behind an interface with a mock implementation** until
`sap_client.dart` exists. `MasterDataRemoteDataSource` is the seam; swapping
`MockMasterDataRemoteDataSource` for a real SAP-backed one is a one-line DI change
and touches nothing above the datasource boundary.

## Consequences

Positive:

- No fake cascade ships. A control that reloads nothing and filters nothing is
  never rendered, so the UI does not lie about its own capability.
- No Drift migration, so this change carries no data-loss risk.
- The offline posture is correct by construction: dropdowns read from cache and
  work with zero connectivity.
- The repository seam means the SAP integration, when it lands, is a datasource
  swap rather than a UI rewrite.

Negative / accepted:

- The delivered filter is narrower than the original ten-level request. This is a
  deliberate consequence of finding 4, not a scope reduction for convenience.
- Master-data lists are fetched from a mock until the SAP gateway exists; the
  cache, TTL, offline badge and error mapping are real and exercised, but the
  values are not yet SAP's.

## Open questions to resolve with the SAP / backend team

- Can the Helper BAPIs accept a sales-area filter that API v2.0 does not expose?
  If yes, a genuine cascade becomes possible and this ADR should be superseded.
- Is there a source for the Division list, given no `GetDivision` endpoint?
- Will `Depot/GetPaging` gain filters for sales office / group / depot group?
- The document notes `[Authorize(Roles = "Admin,Operator")]` is commented out on
  the Depot controller, and its examples use self-signed HTTPS on raw IPs with
  `curl -k`. Both conflict with `docs/skills/security.md` and must be resolved before any
  real integration — certificate validation is not to be disabled in the client.
