# Feature Architecture — the module map

> **Purpose:** one page that says what modules exist, how big each layer is, and
> what each one owns. Read this before opening any feature you have not worked
> in — it tells you whether the thing you need already exists somewhere else.
> **Source:** `lib/` on 2026-08-27, branch `web` @ `142de9b`. Counts are file
> counts, not lines.

---

## Census

Every feature under `lib/features/` follows `presentation → domain → data`
unless the "Layers" column says otherwise.

| Feature | Screens | Widgets | BLoC/Cubit | Use cases | Entities | Domain repos | Remote DS | Local DS | Layers |
|---|--:|--:|--:|--:|--:|--:|--:|--:|---|
| `order` | 14 | 48 | 10 | 43 | 32 | 9 | 7 | 11 | full |
| `my_visits` | 7 | 25 | 10 | 30 | 24 | 6 | 7 | 11 | full |
| `depots` | 3 | 11 | 5 | 17 | 12 | 4 | 6 | 4 | full |
| `notification` | 0 | 5 | 4 | 3 | 11 | 3 | 3 | 0 | full (DAO-backed) |
| `authentication` | 6 | 6 | 1 | 3 | 7 | 1 | 1 | 1 | full |
| `geo_location` | 0 | 4 | 1 | 4 | 2 | 1 | 0 | 1 | full (local-only) |
| `app_coach` | 0 | 6 | 1 | 4 | 4 | 1 | 0 | 1 | full (local-only) |
| `localization` | 0 | 3 | 1 | 4 | 1 | 1 | 0 | 14 | full (asset-backed) |
| `profile` | 1 | 3 | 1 | 4 | 1 | 1 | 1 | 0 | full |
| `shell` | 1 | 17 | 0 | 0 | 0 | 0 | 0 | 0 | presentation only |
| `home` | 1 | 7 | 2 | 0 | 0 | 0 | 0 | 0 | presentation + data |
| `about` | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | presentation + domain |
| `settings` | 0 | 3 | 1 | 0 | 1 | 1 | 0 | 0 | theme only |
| `splash` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | presentation only |
| `onboarding` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | presentation only |

`order` and `my_visits` hold roughly half the application between them. Any
change to shared `core/` infrastructure should be blast-radius-checked against
those two first — see [../skills/graphify.md](../skills/graphify.md).

`shell`, `splash`, and `onboarding` are presentation-only by design: they
compose other features rather than owning data.

---

## What each feature owns

| Feature | Owns | Docs |
|---|---|---|
| `authentication` | Login, OTP, forgot/reset password, session restore, guest state | [../feature/authentication/](../feature/authentication/) |
| `depots` | Depot list, detail, filtering, SAP Business Partner creation, master-data lookups | [../feature/depot/](../feature/depot/) |
| `my_visits` | Daily routes, stops, geofenced check-in/out, stop dashboard, inventory visibility, telemetry | [../feature/my-visits/](../feature/my-visits/) |
| `order` | Catalog and guided material selection, cart, quotations, sales orders, PDF generation, voice search | [../feature/order/](../feature/order/) |
| `notification` | Inbox, badge counts, per-category preferences, push device registry, deep links | [../feature/notification/](../feature/notification/) |
| `geo_location` | Cambodian administrative gazetteer, address pickers, reverse geocoding | **undocumented** |
| `app_coach` | Interactive first-run coaching that teaches by having the user act | [../feature/app-coach/](../feature/app-coach/) |
| `localization` | Runtime `en`/`km` switching, `.tr` lookup, app-restart-on-change | [../skills/localization.md](../skills/localization.md) |
| `profile` | Rep profile, sign-out | **undocumented** |
| `shell` | `MainShell` bottom-nav container, app bar, KPI screen, guest surfaces, sync widgets | [../feature/shell/](../feature/shell/) |
| `home` | Landing dashboard tiles | **undocumented** |
| `about` | About hub, informational detail pages | **undocumented** |
| `settings` | Theme mode | **undocumented** |
| `splash` | Cold-boot splash, language selection (first run) | in [authentication-architecture.md](authentication-architecture.md#boot--navigation-flow) |
| `onboarding` | First-run onboarding, gated by `isOnboardingComplete` | in [authentication-architecture.md](authentication-architecture.md#boot--navigation-flow) |

---

## Shared `core/` infrastructure

A feature must reuse these rather than reimplement them.

| Directory | Provides |
|---|---|
| `core/database/drift/` | `AppDatabase`, 12 table files, 11 DAOs, migrations v1→v20+, rekey executor |
| `core/database/secure/` | Composite key derivation, `dynamic_key_store`, key rotation |
| `core/database/hive/` | Non-sensitive preferences, local cache |
| `core/network/` | `dio` construction (authed + bare clients), envelope, error mapping, redacted logging, connectivity/reachability, `sap_client` |
| `core/middleware/` | `AuthInterceptor` (single-flight refresh), `ApiHeadersInterceptor` |
| `core/session/` | `SessionManager` — the one synchronous source of auth truth; `SessionResetService` |
| `core/auth/` | `AuthGuard`, `LoginRequiredDialog`, `ProtectedFeature` mixin |
| `core/notifications/` | Push registration, channels, local presenter, deep links — all web-no-op'd |
| `core/localization/` | Locale resolution, `.tr` extension, localized-text codec |
| `core/di/` | `injection_container.dart` composition root |
| `core/theme/` | Colour schemes, typography, the two font families |
| `core/responsive/` | Breakpoints, `context.responsive(...)` |
| `core/animations/` | Shared transitions, shimmer, staggered lists, press-scale |
| `core/bootstrap/` | `AppBootstrapService` (no network I/O), `ErrorBoundary` |
| `core/sync/` | **1-byte stubs.** The unified engine of [../adr/ADR-0006-sync-engine.md](../adr/ADR-0006-sync-engine.md) is not built; sync is per-feature today. |

---

## Test coverage by area

107 test files. Densest where the risk is:

| Area | Files |
|---|--:|
| `core/database/` (schema, DAOs, migrations, key derivation) | 20 |
| `features/my_visits/` | 19 |
| `features/order/` | 15 |
| `features/authentication/` | 9 |
| `features/depots/` | 7 |
| `core/localization/`, `core/logging/`, `core/network/` | 12 |
| `features/geo_location/` | 5 |
| everything else | 20 |

No integration test directory (`integration_test/`) exists, though
[../skills/engineering-standard.md](../skills/engineering-standard.md) §10 requires
one for cross-layer flows.

---

## Related

- [system-architecture.md](system-architecture.md) — the layer rules these modules obey
- [navigation-architecture.md](navigation-architecture.md) — how the user moves between them
- [../feature/README.md](../feature/README.md) — the per-feature documentation index
