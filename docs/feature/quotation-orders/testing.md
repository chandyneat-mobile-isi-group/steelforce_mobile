# Quotations — Testing

**Status:** Active · **Last updated:** 2026-09-11
**Suite:** `tests/ISI.Application.UnitTests/Features/Quotations/`

---

## What runs

```bash
dotnet test tests/ISI.Application.UnitTests/ISI.Application.UnitTests.csproj \
  --filter "FullyQualifiedName~Quotations"
```

41 tests, all passing. The whole `ISI.Application.UnitTests` suite is 390, all passing
— no regression.

| File | Covers |
|---|---|
| `QuotationCalculatorTests` | The arithmetic: the plan's worked example, `pricingUnit ≠ 1`, `US3` versus `USD` rounding, additive stacking, the per-line cap, a deduction larger than the line, mixed currency, unit mismatch, approval-level routing, the ageing-price warning |
| `QuotationStateMachineTests` | Every transition the diagram draws and the ones it does not: submit guards, four eyes, approve twice, return as a new revision, reject as terminal, cancel before and after a decision, duplicate lines, the document currency released with the last line |
| `QuotationSapSubmissionTests` | The duplicate guards: submission refused unless approved, refused once SAP holds it, refused while an attempt is in flight or unresolved; retry allowed only from `SapFailed`; a 2xx with no document number treated as a failure; an `Unknown` attempt resolved by adopting SAP's document; the outbox recording what was sent and what came back |

---

## Why these cases

They are what live SAP data produced, not invented ones. Each is a *plausible wrong
number* rather than a visible failure, which is the failure mode worth paying for:

- **`pricingUnit = 100`** — "0.475 US3 per 100 KG" is a hundredth of "per KG". A
  calculator that assumed 1 is wrong by a factor of a hundred and looks entirely
  reasonable doing it.
- **`US3` versus `USD`** — 3,867 of 3,869 live condition records are `US3`, which
  rounds to three decimals rather than two.
- **Additive versus compounded stacking** — 5% and 1% on 1,000 is 60, not 59.5. This
  test pins the *current proposal*; if the SD session finds SAP's pricing procedure
  compounds, the calculator changes and so does this test.
- **The worked example** — 10,000 KG of `1500000017` at the price captured from
  `Live110` on 2026-09-10, less 1.5%: gross 4,750.000, discount 71.250, net 4,678.750.

---

## Verified by hand for the SAP flow

| Check | Result |
|---|---|
| Mobile cannot reach SAP | The generated OpenAPI document has **no `/mobile/` path containing `sap`** |
| The submission endpoints are admin-only | Tagged `Admin.Quotations` / `HeadSales.Quotations`, never `Mobile.Quotations` |
| No mobile role holds `quotations.sap` | Granted to Sales Manager, Head of Sales and Finance only |
| `statusDisplay` reaches the clients | Present on `QuotationDetailDto` and `QuotationSummaryDto` in the schema |
| The migration is contained | Two columns on `quotations` plus `sap_submissions`; no drift |

---

## What is not covered, and why

| Not covered | Reason |
|---|---|
| The handlers end to end | They need `IApplicationDbContext`, `ICurrentUser`, `IPricingService` and the audience resolver together. The material feature's in-memory `MaterialTestContext` is the pattern to follow when this is done |
| `IQuotationLinePricer` against real SAP responses | Needs captured `GetPriceByPaging` fixtures for the multi-price and unmapped-row cases |
| The unique index on `number`, and the concurrent-create race | EF Core's in-memory provider cannot enforce a unique index. This belongs in an integration test against PostgreSQL |
| Optimistic concurrency between two editors | Same: needs a real database |
| `SapQuotationService` against a real middleware | No captured `CreateQuot` or `GetQuotByPaging` **response** — the OpenAPI document declares both as a bare `200 OK`. The document-number reader tries several plausible names and logs what SAP actually sent |
| The submission handler end to end | Needs the fake context plus a stubbed `ISapQuotationService`. The domain guards are covered; the orchestration is not |
| Network-kill during `CreateQuot` producing exactly one document | Needs a fake client that commits then drops the connection. **The highest-value gap on this list** |

---

## Pre-existing breakage, not caused here

`tests/ISI.Domain.UnitTests` did not compile: the project had **no `ProjectReference`
to `ISI.Domain` or `ISI.SharedKernel`**, so every `using ISI.Domain.Modules.*`
resolved to nothing and the build reported 120 errors against the test files rather
than one against the missing reference.

The references have been restored, which takes it from **120 errors to 1**. The
remaining error is genuine and belongs to in-flight depot work:
`Modules/Depots/DepotReferenceTests.cs` tests a `DepotReference` type that no
longer exists — the catalogue was split into eighteen concrete types. Rewriting that
file is the depot feature's to do; it was left alone rather than guessed at.

**Consequence:** `dotnet test` across the solution still fails, on that one file. The
quotation tests live in `ISI.Application.UnitTests`, which compiles and passes.

This is the plan's Phase 0 exit criterion — *"restore the test project references and
fix the pre-existing compile errors"* — half done.

---

## When the SAP path is built

The plan's testing strategy applies unchanged, and two cases decide whether it is
safe to deploy:

- **Network kill during `CreateQuot` produces exactly one SAP quotation.** A fake SAP
  client that commits and then drops the connection, followed by the reconciliation
  job finding the document by its platform number.
- **DTOs pinned from captured responses, never from guesses.** Pricing found four
  silent contract defects that way; a feature that creates sales documents cannot
  afford them.
