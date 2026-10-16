# Pricing — Architecture

## The chain

```text
Flutter app / Admin portal
        │
        ├── GET  /api/v1/mobile/pricing/depots/{id}   MobilePricingController
        ├── GET  /api/v1/pricing/depots/{id}          PricingController
        ├── POST /api/v1/pricing/depots/{id}/publish  PricingController
        └── WS   /hubs/pricing                           PricingHub
                    │
                    ▼
        IPricingAudienceResolver ── row-level scoping, one rule for all four
                    │
                    ▼
        IPricingService  →  SapBackedPricingService
                    │            │
                    │            ├── IApplicationDbContext  (sales org + price group)
                    │            └── ISapPricingService → SapPricingService
                    │                                          │
                    ▼                                          ▼
        IPricingRealtimePublisher              GET /api/Pricing/GetPriceByPaging
                    │
                    ▼
        PricingRealtimePublisher → IHubContext<PricingHub>
```

## Where each piece lives, and why

| Piece | Project | Why there |
|---|---|---|
| `MobilePriceItem`, `MobilePricingResponse`, `MobilePricingUpdatedEvent` | `ISI.Contracts` | Shared by REST and the hub, so both transports carry one shape |
| `IPricingService`, `SapBackedPricingService` | `ISI.Application` | The business logic: which sales area, which filters, what maps |
| `IPricingRealtimePublisher`, `PricingAudience` | `ISI.Application` | The seam. The application decides *what* and *for whom* |
| `PricingHub`, `PricingRealtimePublisher` | `ISI.Api` | The only project that may know `IHubContext` |
| `ISapPricingService`, `SapPriceDto` | `ISI.Application/Abstractions/Infrastructure` | The SAP contract, declared where the application can see it |
| `SapPricingService` | `ISI.Infrastructure` | The HTTP client, failover, token handling |

## The three decisions worth knowing

### One service, three callers

`SapBackedPricingService` is called by the mobile controller, the admin controller and
`PublishPricingUpdateCommandHandler`. An event assembled independently of the REST
response would eventually disagree with it, and that disagreement surfaces as a price
that changes when the user pulls to refresh — the most alarming bug a pricing screen
can have.

### The publisher is in `ISI.Api`, not `ISI.Infrastructure`

`IHubContext` is an ASP.NET Core type. Keeping it behind `IPricingRealtimePublisher`
is what stops pricing tests from being SignalR tests, and what makes a Redis backplane
a second implementation rather than an edit to a handler if the API is ever scaled past
one instance.

`PublishPricingUpdatedAsync` takes `MobilePricingUpdatedEvent` — not `object` — so a
caller holding a SAP DTO has nothing to pass. Leaking an ERP shape over the socket is a
compile error, not a code-review catch.

### The service does not authorize

Scoping happens where a caller exists: `PricingHub` resolves on subscribe, and both
controllers resolve on request. `SapBackedPricingService` is also called by the publish
command, which runs on a background thread with no user — putting the check inside the
service would make every published update fail as unauthenticated.

## Startup wiring

```csharp
builder.Services.AddPlatformRealtime();   // SignalR + resolver + publisher

app.UseMiddleware<HubAccessTokenMiddleware>();  // before UseAuthentication
app.UseAuthentication();
app.UseAuthorization();
app.MapPlatformRealtime();                // after both, or [Authorize] has no identity
```

`HubAccessTokenMiddleware` exists because a WebSocket handshake cannot carry an
`Authorization` header — see [api/mobile.md](api/mobile.md).
