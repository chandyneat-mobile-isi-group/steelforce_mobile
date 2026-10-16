# Pricing — Security

## Permissions

| Surface | Permission | Why this one |
|---|---|---|
| `GET /api/v1/mobile/pricing/depots/{id}` | `depots.read` | Pricing *is* a depot read |
| `GET /api/v1/pricing/depots/{id}` | `depots.read` | Same rule, admin envelope |
| `POST /api/v1/pricing/depots/{id}/publish` | `depots.read` + ownership | A refresh of prices the caller may already read |
| `WS /hubs/pricing` | `[Authorize]` + row-level scoping | See below |

**Publish is not gated by `depots.sync`.** It was, and that made it unusable from a
handset. Raising the field app to `depots.sync` would have been the larger mistake:
that permission also carries `POST /depots/sync-sap` and `POST /materials/sync` —
full ERP master walks — so every representative would have been able to trigger them.
Guarding publish with `depots.read` plus the ownership check gives a representative
exactly what they already have on the read path, and nothing more.

> The ownership check is load-bearing here, not decorative. Publishing reads a
> depot's commercial terms and pushes them to that depot's group, so lowering the
> permission without it would have let any holder of `depots.read` trigger a read of
> a shop that is not theirs.

**No new permission was added.** A `pricing.read` would be a row nobody holds until
somebody remembers to grant it — a 403 for every representative on the day it deploys.
Pricing genuinely is a depot read: one depot's commercial terms, scoped by the
same ownership rule. Split it later if finance ever needs pricing without depots.

## Row-level scoping

A permission answers *"may this caller read depots at all"*. It does not answer
*"may they read **this** depot"*. `IPricingAudienceResolver` asks the second
question, and **all four surfaces go through it**:

- a representative holding `depots.read` sees the depots assigned to them;
- a supervisor additionally holding `depots.readall` sees everyone's.

The rule is the platform's existing one, reused rather than reinvented, so a permission
change takes effect on the pricing surface with nothing to remember.

> Without this check a representative holding `depots.read` could read any shop's
> pricing by guessing an id. The permission attribute alone does not stop that.

The portal is not exempt on the assumption that portal users hold `depots.readall`.
Which roles hold which permission is a database row, and a surface that authorizes
differently depending on who is expected to call it is a surface that will eventually
be wrong.

## Not found vs forbidden

A caller who is not entitled receives `Pricing.DepotNotFound` — **the same answer as
a depot that does not exist**, and a 404 rather than a 403. Distinguishing them
confirms the record exists. This follows the `Depot.DraftNotFound` precedent.

`Pricing.DepotNotPriceable` (422) is deliberately *not* masked: by the time it is
returned the caller has already been shown that depot, so naming the reason confirms
nothing they did not know.

## Group isolation

Groups are named `pricing:depot:{depotId}` — the depot is the finest correct
scope, because SAP prices a material *for a depot*. A broader group would deliver a
representative price changes for shops they do not call on, and every one of those
messages is a row of another depot's commercial terms.

**The client sends a depot id, never a group name.** `PricingAudience` has no public
constructor taking a string; the only way to obtain one is through the resolver.

> A hub method taking a group name would let any authenticated handset type
> `pricing:depot:{someone else}` and receive another shop's terms. SignalR would not
> object — **joining a group is not an authorization event.**

`PricingRealtimePublisher` sends to `Clients.Group(...)`, never `Clients.All`.
Broadcasting pricing to every connected handset would send each representative the
commercial terms of every depot in the country, and it is one word's difference from
correct code.

## The query-string token

A WebSocket handshake cannot carry an `Authorization` header, so the SignalR clients
pass the token as `?access_token=`. `HubAccessTokenMiddleware` moves it into the header
**for the hub path only**.

> Accepting a query-string token across the whole API would put access tokens into
> every request log, every proxy log and every browser history.

The middleware rewrites a header; it makes no token decision. OpenIddict still
validates the token, still consults the token store, and still rejects a revoked
session. A request that already carries an `Authorization` header is left untouched.

## What never leaves the server

- **SAP's own error text, endpoint and connection id.** A SAP failure becomes a 502
  carrying a stable code and a localised message.
- **Prices, in logs.** The publisher logs the group and the item count; the mapper logs
  unresolved *field names*, never values.
- **SignalR detailed errors**, in every environment. `EnableDetailedErrors` is off — a
  detailed error is the exception's `ToString()`, which for a SAP failure names the
  middleware host. The hub throws `HubException` with a stable code instead.
