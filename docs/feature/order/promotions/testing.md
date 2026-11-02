# Promotions & Discounts — Testing

**Status:** Active · **Last updated:** 2026-09-12
**Suite:** `tests/ISI.Application.UnitTests/Features/Promotions/`

---

## What runs

```bash
dotnet test tests/ISI.Application.UnitTests/ISI.Application.UnitTests.csproj \
  --filter "FullyQualifiedName~Promotions"
```

41 tests, all passing. The whole `ISI.Application.UnitTests` suite is 376, all passing
— the promotions work introduced no regression.

| File | Covers |
|---|---|
| `AgreementTierRulesTests` | Ladder validation: contiguity, the zero floor, gaps, overlaps, an open rung before the last, a closed top rung, out-of-range rates, non-sequential orders |
| `AgreementWorkflowTests` | The chain: submit guards, four eyes both ways, per-step allowed outcomes, acting on the wrong step, returns and revisions, restart-at-step-1, withdrawal windows, rejection as terminal |
| `AgreementTermTests` | Approved vs effective, deductibility, ladder snapshotting, supersede date arithmetic, termination, SAP mismatch |

---

## Why these cases

Most of them are **refusals**, because the chain is the feature. If one person can walk
a request from draft to approved, the whole programme is a spreadsheet with a login
page.

The three that matter most:

- **`OnePerson_CannotSignTwoStepsOfOneRevision`.** Somebody may legitimately hold two
  of the four permissions. Without this, a four-step chain quietly becomes a two-person
  one — and nothing in the UI would look wrong.
- **`ResubmittingAfterAReturn_RestartsAtStepOne`.** It also asserts the previous
  revision's four signatures are still on the aggregate. Resuming mid-chain would put
  the Commercial Director's name on a version they never read.
- **`AVolumeRebate_IsNeverDeductible`.** A rebate looks like a discount on a card and
  behaves nothing like one on an invoice. The month's total is unknowable while the
  month is running.

The ladder cases are each something a spreadsheet accepts silently: a gap between
2,000 and 2,500 that nobody prices, an overlap where a depot spending 2,200 earns two
different rates depending on evaluation order.

---

## What is not covered, and why

| Not covered | Reason |
|---|---|
| The handlers end to end | They need `IApplicationDbContext`, `ICurrentUser`, `IPricingAudienceResolver` and `IUserDirectory` together. `MaterialTestContext` is the in-memory pattern to follow when this is done |
| The exclusion constraint | EF Core's in-memory provider cannot enforce one. **This belongs in an integration test against PostgreSQL** and is the most valuable gap on this list |
| The overlap checks against real data | Same — they are database queries |
| `IAgreementLookup` and the quotation pipeline together | Needs a seeded context: depot, material, mapping, effective term, quotation |
| Idempotent creation on `clientRequestId` | The unique index is what enforces it, so it needs a real database |
| The SAP attestation path | No SAP to attest against; the domain transition is covered, the handler is not |

**The exclusion constraint is the one to write next.** It is the backstop for the
feature's central commercial guarantee — one depot, one effective rate per category per
day — and nothing currently proves it fires.

---

## Manual verification done

- **`dotnet build`** across all nine source projects: 0 errors, 0 warnings
  (`TreatWarningsAsErrors` is on).
- **OpenAPI confirmed by running the API** and fetching `/openapi/v1.json`: 21
  promotion operations across 17 paths, tagged into all three sidebar groups
  (`Admin.Promotions`, `Mobile.Promotions`, `HeadSales.Promotions`).
- **The migration was inspected** rather than assumed: nine `CreateTable` operations
  and no drift into unrelated tables.

---

## Pre-existing breakage, not caused here

`tests/ISI.Domain.UnitTests` still does not compile. Its `ProjectReference`s were
restored during the quotations work, taking it from 120 errors to 1; the remaining one
is `Modules/Depots/DepotReferenceTests.cs`, testing a `DepotReference` type
that no longer exists. That belongs to in-flight depot work and was left alone.

**Consequence:** solution-wide `dotnet test` still fails on that one file. The
promotions tests live in `ISI.Application.UnitTests`, which compiles and passes.
