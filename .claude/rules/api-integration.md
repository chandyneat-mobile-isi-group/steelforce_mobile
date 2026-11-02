# API integration

Implementation notes and verified-against-live findings:
`docs/skills/api-integration.md`. Per-feature contracts live with the feature:
`docs/feature/<feature>/api.md` (and `api/mobile.md` where admin and mobile
contracts differ). **There is no separate `docs/api/` directory — do not create
one**; a contract has exactly one home, next to its feature.

---

## 1. Before writing any API code

1. Find the existing client: `lib/core/network/` —
   `app_network.dart`, `api_envelope.dart`, `api_error.dart`,
   `api_log_interceptor.dart`, `network_info.dart`,
   `connectivity_service.dart`, `sap_client.dart`.
2. Find the existing endpoint pattern and request/response models in the
   feature's `data/` layer.
3. Read the feature's contract doc in `docs/feature/<feature>/`.
4. Confirm auth handling and error mapping — do not re-implement either.

**Do not invent endpoints. Do not assume request or response field names.** If
the contract is unclear, say so explicitly and name what you need confirmed
rather than guessing a field.

---

## 2. Rules

- API logic never lives in a widget. Remote datasource → repository impl →
  usecase → BLoC → widget.
- Responses are parsed into typed models; the repository maps them to **domain
  entities**. No `Map<String, dynamic>` reaching presentation.
- Errors map to the existing types in `lib/core/error/` (`exceptions.dart`,
  `failures.dart`). Do not throw raw strings or let a `DioException` escape the
  data layer.
- One client, one envelope, one error mapper. Do not add a second `dio`
  instance or a parallel `http` path for a new feature.
- Base URLs and keys come from Envied config (`lib/core/config/`) — never
  hardcoded, never committed.

---

## 3. Offline is the normal case

A network call is an optimisation, not a precondition. Read from the local
database first; a failed request degrades to cached data with an honest
indicator, it does not blank the screen. Writes go to the local database and the
sync queue **in the same transaction** (ADR-006) — never "call the API, then
save on success".

Check real reachability via `connectivity_service.dart` (ADR-005), not a raw
`connectivity_plus` interface state.

---

## 4. Authentication

Use the existing auth architecture in `lib/features/authentication/` and
`lib/core/session/`. Handle login, logout, token expiry, refresh, 401, and
session expiry through it — do not add a bespoke token path. Never log a token,
credential, or refresh token. See `security.md`.
