# Real-Time Mobile Pricing — delivery note (superseded)

> [!NOTE]
> **This file is the original hand-off note and is kept for history.**
> The feature is now implemented and documented properly — start at
> [README.md](README.md). Everything this note listed as "you have to do" is done.

## What the note asked for, and where it stands

| Original item | Status |
|---|---|
| `ISI.Api.csproj` — SignalR reference | Not needed. The project is `Microsoft.NET.Sdk.Web` |
| `Program.cs` — `AddPlatformRealtime()` / `MapPlatformRealtime()` | Done |
| Token from the query string | Done, **not** as written — see below |
| `LocalizationService` — `Pricing.Retrieved` | Done, English and Khmer |
| `ISapPricingClient` and the SAP→mobile mapper | **Built.** See [sap-integration.md](sap-integration.md) |
| A trigger for the publish path | Built as an operator endpoint. No scheduled job yet |

## Two places the note was wrong about this codebase

**The token snippet does not apply.** The note proposed `JwtBearerEvents.OnMessageReceived`.
This platform does not use `AddJwtBearer` — it uses OpenIddict validation
(`ISI.Identity/DependencyInjection.cs`). The same outcome is achieved by
`HubAccessTokenMiddleware`, which moves `?access_token=` into the `Authorization`
header for the hub path only, before `UseAuthentication`.

**`ApiModules.PriceLists` already existed**, so the controllers use it rather than
falling back to `ApiModules.Depots`.

## The one judgement in the note that was right, and was kept

The note declined to write the SAP mapper because the pricing response shape could not
be verified, citing the `GetPaymentTerm` / `PayTerm` precedent. That reasoning holds:
the middleware still could not be reached, and
[sap-openapi.json](../../blueprint/sap-openapi.json) still declares every response as a
bare `200 OK`.

The mapper was built anyway, because the request contract *is* fully specified and a
feature nobody can call is not a deliverable — but it was built so that a wrong guess
**fails loudly instead of silently**: documented aliases, extension-data capture, and a
log naming the fields SAP actually sent. See
[sap-integration.md](sap-integration.md#the-response--not-verified), which also says
exactly how to pin the contract once a real response is captured.

## A security gap the note's code had

The controller in the original drop checked `depots.read` but never checked that the
depot belonged to the caller — a representative could read any shop's pricing by
guessing an id. All four surfaces now resolve through `IPricingAudienceResolver`. See
[security.md](security.md).
