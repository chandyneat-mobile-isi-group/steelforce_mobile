# Pricing — Overview

## What it is

The prices a given depot pays for given materials, read live from SAP and
delivered to two clients: the Flutter field app and the admin portal.

## The guarantee

> A price this platform shows is a price SAP holds right now, for that depot's
> sales area, valid today.

Everything below follows from that sentence.

## Why there is no pricing table

Every other SAP-backed read on this platform is database-first: depots and
materials are synced and served locally, and the ERP is called only to fill a gap.
Pricing deliberately is not.

A stale catalogue entry is a cosmetic problem — a description reads oddly until the
next sync. A stale price is a commitment the business did not make, discovered at a
counter with a depot waiting. The cost of the live read is a slower screen; the
cost of a cached one is a number the business has to honour or retract.

So: no pricing table, no pricing sync, no cache. The mitigations are that the filters
are pushed into SAP rather than applied here, and that the page ceiling on a read is
low.

## REST and realtime, and why both

| Surface | Answers | Used when |
|---|---|---|
| `GET .../pricing/depots/{id}` | What are the prices **now**? | App open, pull-to-refresh, after any reconnection |
| `PricingUpdated` over SignalR | What just **changed**? | While the screen is open |

They are not alternatives. A client that only polled would show prices that are
minutes old; a client that only subscribed would show nothing until something
happened to change. The hub holds no replay buffer, so a client that was disconnected
must re-read over REST — any event that fired while it was away is gone.

The event carries `UpdatedAt` and the REST response does not. That single difference
is what stops a client that reconnects, re-reads, and then receives an event queued
before the disconnection from overwriting fresh prices with stale ones.

## What is not here

- **No pricing aggregate, no migration, no seed data.** Pricing owns no state.
- **No quotation logic.** SAP's `Quotation` endpoints remain unused.
- **No scheduled publish.** The publish path exists and is triggered by an operator
  through the admin endpoint; nothing polls SAP for price changes yet. Wiring a
  recurring job is one `AddOrUpdateRecurring` in `ISI.BackgroundJobs` when the
  business decides how often that should happen.
