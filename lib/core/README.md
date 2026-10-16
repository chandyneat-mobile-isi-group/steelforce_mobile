# `lib/core/` — cross-cutting infrastructure

Only code that more than one feature needs, and that is not a feature itself.
Layering and ownership rules: `.claude/rules/architecture.md`. One concern has
one home — do not open a second folder for something listed here.

| Folder | Holds |
|---|---|
| `animations/` | Transitions and interaction motion |
| `auth/` | Route guards and the "sign in to continue" surfaces |
| `bootstrap/` | App start-up and the top-level error boundary |
| `camera/` | Image capture seam; `mock/` is the debug/QA stand-in, never shipped |
| `config/` | Envied config and the mock/live data-source switch |
| `database/drift/` | The encrypted database: `connection/`, `tables/`, `daos/`, `migrations/` (`steps/` by version range, `legacy/` one-time importers) |
| `database/hive/` | Non-sensitive preferences, and their keys (`preference_keys.dart`) |
| `database/secure/` | Key derivation, rotation, and secure-storage keys (`secure_storage_keys.dart`) |
| `database/files/` | Encrypted file store (planned stub) |
| `di/` | Composition root — registers every feature's injection |
| `error/` | `Exception` and `Failure` types |
| `localization/` | EN/KM translation service and localized text |
| `logging/` | `AppLogger`, debug-only tracing |
| `network/` | `app_network.dart` (the one `dio` client) plus `api/` (endpoints, defaults, envelope, errors), `interceptors/` (auth refresh, headers, logging), `connectivity/` (real reachability, ADR-005) |
| `notifications/` | Channels, deep links and time zone; `push/` (FCM) and `local/` (foreground alerts), each with a web no-op |
| `pdf/` | `pdf_service.dart` plus `document/` (building), `storage/` (saving), `sharing/` (opening, sharing) |
| `permissions/` | Location permission service and the permission primer cubit |
| `platform/` | OS capability probes: `device/`, `storage/`, `environment/` |
| `responsive/` | Breakpoints and responsive sizing |
| `session/` | Session state and per-rep data reset on sign-out |
| `sync/` | Planned unified sync engine (ADR-006) — tracked empty stubs |
| `theme/` | Colours, typography, theme extensions |
| `usecase/` | The `UseCase` base class |
| `utils/` | Small, dependency-light helpers only — never widgets |

## Conventions

- **Platform splits** keep the three files together in one folder: `x.dart`
  (the conditional export), `x_native.dart`, `x_web.dart`.
- **Constants live with their concern**, not in a catch-all: API routes in
  `network/api/api_endpoints.dart`, storage keys beside their storage.
- **A file past ~400 lines** is a signal to split by responsibility; use `part`
  files when the pieces share private names (see `database/drift/migrations/`).
