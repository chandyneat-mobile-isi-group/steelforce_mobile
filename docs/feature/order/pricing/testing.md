# Pricing — Testing

## What is covered

`tests/ISI.Application.UnitTests/Features/Pricing/PricingContractTests.cs` — 13 tests,
all passing.

| Area | Pins |
|---|---|
| SAP row contract | Declared names resolve; aliases resolve; SAP technical names (`MATNR`, `KBETR`, `KONWA`, `DATBI`) resolve |
| Lenient types | A numeric amount sent where a string was declared, on both the declared and the extension-data path |
| Absent vs zero | A blank amount resolves to null, never `0` |
| Open-ended validity | Blank dates resolve to null; `99991231` survives as a date |
| Diagnostics | `DescribeShape()` reports field **names** and never values |
| Unknown fields | Extra SAP fields do not lose the row |
| Paging envelope | Standard envelope reads; a missing `Rows` is an empty page, not null |
| Group isolation | Two depots never share a group; one depot's group is stable |
| Event name | `PricingUpdated` — a contract with a released Flutter build |

The two chosen deliberately: **the SAP contract**, because it is unverified, and
**group isolation**, because a wrong group name does not throw — it delivers one shop's
commercial terms to another shop's handset.

## How they were run

> [!IMPORTANT]
> **`dotnet test` cannot currently run in this repository, for reasons unrelated to
> pricing.**

`tests/ISI.Application.UnitTests` and `tests/ISI.Domain.UnitTests` have had their
`ProjectReference` entries removed in an uncommitted change, and restoring them
surfaces pre-existing compile errors from the in-flight depot BP-schema work:

- `MaterialTestContext` does not implement ~22 `IApplicationDbContext` members added by
  that work;
- `DepotReference` no longer exists in the domain, but tests still reference it.

Neither is caused by, or fixable within, the pricing change. The pricing tests were
therefore executed by compiling that one test file against the real
`ISI.Application` assembly in an isolated harness:

```text
Passed!  -  Failed: 0, Passed: 13, Skipped: 0, Total: 13
```

**They will run under `dotnet test` unchanged** once the test project's references are
restored and the pre-existing errors above are fixed by the owner of that work.

## What is not covered, and why

| Not tested | Why |
|---|---|
| A real SAP response | The middleware is on a VPN address unreachable from here. **This is the important gap** — see [sap-integration.md](sap-integration.md) |
| Hub subscribe/unsubscribe | Needs a SignalR test host; the decision it delegates to (`IPricingAudienceResolver`) is application code and testable without one |
| `PricingRealtimePublisher` | Mocking `IClientProxy.SendCoreAsync` pins NSubstitute mechanics rather than behaviour |
| End-to-end REST | `ISI.Api.IntegrationTests` compiles cleanly with its references restored, but the app cannot start against the current database — a pre-existing EF `PendingModelChangesWarning` from the depot schema work |

## The first thing to do when SAP is reachable

Call the endpoint, capture the JSON, and check the log. If any field could not be
resolved, `SapBackedPricingService` will have logged the names SAP actually sent — pin
them into `SapPriceDto`, delete the aliases, and add a test built from the captured
response.
