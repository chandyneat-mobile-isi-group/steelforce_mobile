# Authentication — Overview

> Plain-language explanation for PMs, BAs, QA, the SAP team, and new engineers. Generated 2026-07-23 from the actual implementation.

---

## What is this feature?

The identity layer of the ISI Steel Sales app. It answers "who is using the app right now" in one of two ways:

- **Guest** — anyone can open the app and browse everything (catalog, demo data) without an account. This is the normal, default state, not an error.
- **Authenticated** — a user who signed in with an identifier (email or phone) and password. Their session is cached securely on the device so they stay signed in — even fully offline — until they log out.

It also ships a complete (currently mocked) password-recovery UI: request reset → enter a 6-digit code → set a new password → success confirmation.

## Why does it exist?

Field sales reps work for hours with no signal. A login wall at startup would brick the app in exactly the conditions it was built for. So the design inverts the usual model: **the app always opens**, and login is requested only at the moment a protected action needs it (creating an order, viewing profile, notifications…). A previously signed-in rep boots straight into their account from an encrypted on-device cache with zero network calls.

## Who uses it?

Every user, implicitly: guests (evaluation/browsing), sales reps, managers and admins (roles exist in the model — `admin`, `manager`, `salesRep`, `guest` — though per-role screen behavior is not yet implemented).

## When is it used?

- **Every app start** — a background session check decides Authenticated vs. Guest.
- **When a guest taps a protected feature** — the "Login Required" prompt appears (Login Now / Later).
- **On every API call** — the network layer silently attaches the access token and, if it has expired, refreshes it once and retries.
- **On logout** — from the Profile screen; the user returns to guest browsing, app still open.
- **When a password is forgotten** — the 3-step recovery flow (UI complete; backend calls are placeholders today).

## Business benefits

- No adoption friction: prospects and new reps explore instantly.
- No field downtime: connectivity never blocks access to the rep's own data.
- Conversion by intent: the login prompt appears exactly when the user wants something that needs an account.
- One consistent, branded, bilingual (English/Khmer), light-and-dark auth experience.

## Technical benefits

- **One source of truth** — `SessionManager` is readable synchronously by any guard, screen, or (future) sync scope.
- **One gate** — `AuthGuard` / `context.requireAuth`: protecting a new feature is one line, and gating can never drift between screens.
- **One token store** — the same object serves the repository and the HTTP interceptor, so tokens can't diverge.
- **Safe under concurrency** — double-taps are dropped; parallel 401s trigger exactly one refresh.
- Reference implementation: `docs/blueprint/offline-architecture.md` §2 tells every other feature to copy this shape.

## Offline behavior

| Action | Offline result |
|---|---|
| Open app (previously signed in) | Boots Authenticated from cache, instantly |
| Open app (never signed in) | Boots as Guest |
| Sign in | Fails fast with a clear "network" error — by design, credentials must be verified online |
| Log out | Works; server notification is skipped, local session cleared |
| Browse as guest or user | Unaffected — data reads are local |

## SAP interaction

**None directly.** Authentication talks to the app's own gateway (`/v1/auth/*`), not SAP. Its future SAP relevance: the signed-in user's identity and roles will scope which depots/routes/orders sync from SAP (see `docs/blueprint/sync-architecture.md`), and the bearer token authenticates the gateway that fronts SAP. The SAP client itself (`core/network/sap_client.dart`) is a tracked, still-empty stub.

## Security considerations

- Tokens and the cached user profile live **only** in `flutter_secure_storage` (iOS Keychain / Android Keystore) — never in Hive, SharedPreferences, or a plain database.
- Passwords are never stored, cached, or logged anywhere on the device.
- Errors shown to users are typed, localized messages — never raw exceptions.
- **Known issue to fix before release**: a hardcoded test credential (`tester@gmail.com`) and a mock OTP (`111111`) exist for demo purposes and are not yet tagged with the mandatory `// TODO(release-gate):` marker. Details and remediation in [Security.md](security.md) and Blueprint gaps G-1/G-2.
