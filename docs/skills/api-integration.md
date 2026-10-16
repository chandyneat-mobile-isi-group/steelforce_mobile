# API Integration — implementation notes

How the Flutter client implements the contracts in
[Authentication-guild-integratemobile.md](../feature/authentication/integration-guide.md)
and [depots-guidline-integrateion-mobile.md](../feature/depot/api.md).

Those two documents describe the server. This one describes **our side**: where
each rule lives in the code, which decisions were compromises, and what is still
outstanding.

---

## Verified against the running API

Login, `/auth/me` and `/mobile/depots` were exercised against a live tunnel
and the captured payloads are pinned in
`test/core/network/live_contract_test.dart`. Three things the guide does not
say, each of which was a real defect:

- **`/auth/me` returns `userId`, not `id`.** Reading only `id` left every
  profile with an empty identifier.
- **Roles arrive as display names** — `"Sales Representative"`, not `salesRep`.
  Matching on underscore-stripped enum names left a sales rep holding *no roles
  at all*, silently hiding every role-gated action. Now normalised (lowercase,
  non-alphanumerics removed) against an alias table.
- **Framework problem documents carry no `errorCode`.** A bare 403 answers with
  `type` pointing at `rfc9110#section-15.5.4`; mining the last path segment
  produced a meaningless code. Only `/errors/<Code>` URLs are mined now, and
  anything else falls back to a status-derived code.

### The test rep cannot read depots

`EMP000202` holds `outlets.read` / `outlets.create` / `outlets.update` but **no
`depots.*` permission**, so `/api/v1/mobile/depots` answers 403 for it.
The route itself is correct — it returns 403 rather than 404, and the same call
with an admin account returns the documented envelope.

This is a server-side role configuration matter, not a client one. Either the
rep role needs `depots.read` granted, or the `outlets.*` permissions are the
intended names and the endpoint's requirement should match them. Worth
confirming with the API team; nothing in the client can work around a 403, and
per the guide it must not try — a 403 hides the action, it never signs the user
out.

## Blockers

### ~~`.env` is malformed~~ — resolved

`.env` now carries the correct `API_BASE_URL`, `SAP_API_URL`, `DB_SALT` and
`GOOGLE_MAPS_IOS_KEY` keys, `build_runner` runs, and `env.g.dart` is
regenerated. `.env.example` documents the keys and `.gitignore` keeps the real
file out of git — `env.dart` always described it as "git-ignored", but no
`.gitignore` existed.

**`DB_SALT` was regenerated**, because the original was unrecoverable. Any
encrypted database created before this change is unreadable; new installs are
unaffected. Keep the new value stable from here.

Shape invariants are guarded by `test/core/config/env_wiring_test.dart` — it
asserts every field is populated and that `API_BASE_URL` is a host root without
`/api/v1`, which is the failure that started this.

**Cloudflare quick tunnels change hostname on every restart.** Rather than
re-running codegen each time, override at launch:

```
flutter run --dart-define=API_BASE_URL=https://<new-tunnel>.trycloudflare.com
```

### Historical: what the malformed `.env` looked like

`.env` currently reads:

```
backend-api = https://pine-mas-new-cooked.trycloudflare.com
```

`lib/core/config/env.dart` declares three `@EnviedField`s: `API_BASE_URL`,
`SAP_API_URL` and `DB_SALT`. None of those keys exist in the file, so
`build_runner` fails and `lib/core/config/env.g.dart` cannot be regenerated.

The committed `env.g.dart` still holds obfuscated values from an earlier, valid
`.env`, which is why the app currently builds at all.

**This must be fixed before the client can talk to the real API**, and it needs
a decision that is not ours to make:

```
API_BASE_URL=https://<host>          # no /api/v1 — ApiEndpoints.apiPrefix adds it
SAP_API_URL=https://<sap-host>
DB_SALT=<the original value>
```

`DB_SALT` is the important one. It is mixed with the hardware-sealed device key
to derive the SQLCipher passphrase, so **writing a new value silently makes
every existing encrypted database on every device unreadable.** Recover the
original from whoever holds the environment secrets rather than inventing one.
If it genuinely cannot be recovered, that is a planned migration, not a
one-line edit.

Until this is resolved, `dart run build_runner build` cannot run, which also
blocks the Drift schema change described under [Outstanding](#outstanding).

**Symptom worth recognising:** because `env.g.dart` still holds the *old*
values, `Env.sapApiUrl` points at a host that no longer answers. That used to
hang the app on its launch screen with no first frame — `AppBootstrapService`
awaited the reachability probe before `runApp`, and the probe had no
`connectTimeout` (Dio exposes it only on `BaseOptions`, and defaults it to
*no limit*), so a host that drops packets rather than refusing them stalled
boot indefinitely. Fixed in two places: [HttpReachabilityProbe] now bounds
itself with both a connect timeout and an outer wall-clock `.timeout()`, and
bootstrap no longer awaits `start()` — which is what its own doc comment,
ADR-002 §3 and OFFLINE_FIRST §2.6 already required. Regression test:
`test/core/network/reachability_probe_timeout_test.dart`.

---

## Where each rule lives

### Core

| Concern | File |
|---|---|
| Two error dialects (OAuth vs RFC 9457) | `core/network/api/api_error.dart` |
| Success envelope + paging/sync metadata | `core/network/api/api_envelope.dart` |
| `Accept-Language`, `X-Correlation-Id` | `ApiHeadersInterceptor`, `core/middleware/app_middleware.dart` |
| Refresh-on-401, once, serialised | `AuthInterceptor`, same file |
| Token storage and write ordering | `features/authentication/data/datasources/auth_local_data_source.dart` |
| Device block / `deviceId` | `core/device/device_identity.dart` |
| Money as `{amount, currency}` | `core/utils/money.dart` |
| Live-vs-mock switch | `core/config/data_source_mode.dart` |
| Sign-in identifier field | `features/authentication/presentation/widgets/login/username_field.dart` |

### The two error formats

`ApiError.fromBody` is the only place that knows the difference. It normalises
both dialects onto a single stable `code`:

- OAuth (`/auth/login`, `/auth/refresh`, `/auth/token`) → `{error,
  error_description, error_uri}` at HTTP **400**. The code is the last path
  segment of `error_uri`, falling back to the bare `error` token.
- Everything else → RFC 9457, keyed on `errorCode`.

`ApiErrorCodes` lists the codes worth handling by name. User-facing copy is
keyed off `code`, never off `detail` — `detail` is English and belongs in logs.

**403 never signs the user out.** `ApiError.isPermissionDenied` and
`isUnauthenticated` are deliberately disjoint, `AuthInterceptor` only reacts to
401, and `AuthRepositoryImpl._failure` maps 403 to a `ServerFailure` rather than
an `AuthenticationFailure`.

### Sign-in is two calls

`POST /auth/login` is a raw OAuth token endpoint — it returns a token pair and
nothing else. The profile, including permissions and feature flags, comes from
`GET /auth/me`, which *is* wrapped.

`AuthRepositoryImpl.login` persists the tokens between the two calls so the
profile fetch authenticates normally through the interceptor. If the profile
call fails, the tokens are dropped again rather than leaving a half-open
session that boots into an empty shell.

### Token rotation

`AuthLocalDataSourceImpl.saveTokens` writes the **refresh token first**, then
the access token, sequentially. Refresh tokens are single-use, so the moment the
new access token is in play the old refresh token is dead; the reverse order
would leave a live access token beside a retired refresh token after a crash —
a session that works for fifteen minutes and then forces a re-login.

Concurrent 401s are coalesced through a single `Completer` in `AuthInterceptor`.
Two parallel refreshes would present an already-rotated token on the second
call, and the server's reuse detection reads that as theft and revokes the
session.

### Depot sync

`DepotSyncRepositoryImpl` implements the three load-bearing rules:

1. The watermark is `metadata.syncTimestamp` from the **server**, captured from
   the *first* page and held for the whole run.
2. It is committed **once**, after every page has been applied.
3. Tombstones (`deleted: true`) are split out by
   `ApiDepotRemoteDataSource.fetchDelta` and applied via `markDeleted`.

Paging is one-based. `pageSize` is read back from `metadata`, because the server
clamps to 200 silently rather than rejecting.

Covered by `test/features/depots/depot_sync_watermark_test.dart`.

---

## Compromises

### Coordinates are stored as `(0, 0)` for "no fix"

The API sends `null` for both coordinates when a device reported no GPS fix, and
rejects `(0, 0)` on write because it is a real point in the Gulf of Guinea.

Our local Drift columns are non-null `real`, and making them nullable needs a
schema migration, which needs codegen, which is blocked on `.env`. So `(0, 0)`
is the local encoding for "unknown", and **`hasCoordinates` is the accessor
every geographic consumer must use** — it exists on both `Depot` and
`DepotStopInfo`. `StopDistanceSorter` and `GeofenceService` both check it;
without that they would measure 10 000 km to the Atlantic and either bury an
unlocated shop at the bottom of the list or fail a check-in the rep is standing
inside.

On the way *out* to the API we still send `null`, never zeros.

### The login field accepts a phone number, which the contract does not document

The sign-in form is a single `UsernameField` taking an **employee ID, e-mail
address, or phone number**, sent as `employeeId`. It replaced an e-mail/phone
tab switcher that validated the input as an e-mail address — so a rep typing
the personnel number on their own badge (`ADM000001`) was told it was not a
valid e-mail and could not sign in at all.

The auth guide documents `employeeId` as accepting a personnel number *or an
e-mail address*; **phone numbers are not mentioned.** They are accepted
client-side anyway, because the client is the wrong place to decide what
identifies an account — the server resolves whatever arrives and answers
`Auth.InvalidCredentials` when it cannot. If phone sign-in is genuinely not
supported server-side, the only cost is that a rep who tries one gets the
standard "ID or password incorrect" message. Worth confirming with the API
team either way.

Validation is intentionally limited to "not empty" plus whitespace stripping.
Anything stricter risks rejecting a legitimate identifier format — a new
employee-ID scheme, a foreign number, a `+tag` address.

`IdentifierField` (the e-mail/phone switcher) is untouched and still used by
forgot-password, where it belongs: a reset has to be *sent* somewhere, so it
needs a real contact channel rather than an account identifier.

### Status labels are resolved locally

The API returns a pre-translated `statusDisplay` beside the stable `status`
code. We render a locally translated label keyed off `status`
(`DepotStatusL10n.localizedLabel`) instead, because a row rendered from the
offline cache must read in the user's current language even if it was synced
under a different one — and because a language switch should be a rebuild, not
a re-sync. We still never branch on `statusDisplay`.

`DepotStatus` gained the real API lifecycle (`Draft`, `PendingApproval`,
`Active`, `Suspended`, `Closed`). The old `dormant` / `creditHold` values were
local inventions; they remain in the enum so mock rows and already-persisted
rows still deserialise, and are excluded from `DepotStatus.selectable` so
they are never sent as a `status` filter.

### The summary DTO has no street address

The list endpoint returns city, district and territory but no address line —
by design, it is a fifth of the full depot. A freshly synced row therefore
shows `"District, City"` as its address until the detail aggregate is fetched
via `fetchById`, which fills in `addressLine1`, contacts, the SAP block and the
metric cache.

### Device metadata is partial

`device_info_plus` and `package_info_plus` are not dependencies, so the device
block is built from `dart:io` and `defaultTargetPlatform`
(`core/platform/device_os_*.dart`):

- `deviceName` falls back to the host name, which on iOS is often generic.
- `timeZone` is the zone abbreviation (`ICT`), not the IANA name
  (`Asia/Phnom_Penh`) the API example shows.
- `appVersion` comes from `--dart-define=APP_VERSION`, defaulting to the
  `pubspec.yaml` version.

All three are display hints on the session row. Add the two packages if an exact
IANA zone or a real marketing device name is ever needed.

---

## Outstanding

Not done, in rough priority order:

1. **Fix `.env`** — see [Blockers](#blockers). Everything below depends on it.
2. **Schema migration (v16)** making `depots.latitude` / `longitude`
   nullable, and adding `city`, `canTrade` and `metricsCalculatedAt`. Follow the
   ladder in `core/database/drift/migrations/schema_migrations.dart`; the
   nullability change needs a `TableMigration` like the v10 step.
3. **Sessions UI** — `listSessions` / `revokeSession` are implemented on the
   repository but no screen consumes them. Warn before revoking the session
   flagged `isCurrent`; it signs the user out of the device in their hand.
4. **Password screens** — `changePassword`, `forgotPassword`, `resetPassword`
   are wired through the repository; the existing screens still run against the
   old mock flow. Minimum length is 12. After a successful change, sign out with
   `allDevices: true`.
5. **Depot create/update** — `POST` and `PUT /mobile/depots` are not
   implemented. Note when doing so: `depotCode` is immutable on update, the
   SAP block is never writable, and `contacts: []` **wipes every contact** while
   omitting the key leaves them untouched.
6. **`Retry-After` handling** on 429. `RetryAfter` exists as an extension in
   `api_error.dart` but nothing consumes it yet.
7. **Metric staleness labels** — `metricsCalculatedAt` is not yet persisted, so
   the "as of" label the depots guide asks for cannot be rendered. Blocked on
   item 2.

---

## Debug logging

Every API call is logged: method, path, status, duration, error code and
correlation id, plus row counts and paging metadata for list responses. Records
go through `AppLogger` (`dart:developer`), so they appear in the `flutter run`
console and in DevTools, tagged `isi.debug` / `isi.info` / `isi.error`.

Filter for `api.`, `auth.` or `depots.sync.` to follow one flow:

```
api.request   method=POST path=/api/v1/auth/login signedIn=false language=en-US
auth.login.start   identifierKind=employeeId rememberDevice=true
api.response  method=POST path=/api/v1/auth/login status=200 ms=412
api.response  method=GET  path=/api/v1/auth/me   status=200 ms=155
auth.login.success permissions=14 roles=[salesRep] territory=PP-NORTH flags=3

depots.sync.initial.start  pageSize=200
api.response  method=GET path=/api/v1/mobile/depots status=200 ms=890
              rows=[depots:200] page=1 pageSize=200 records=412 hasNextPage=true
depots.sync.initial.done   pages=3 upserted=412 watermark=2026-08-12T09:44:12Z
```

On failure, `api.error` and the matching `auth.login.failed` /
`depots.sync.*.failed` record carry `errorCode`, `status` and
`correlationId` — quote the correlation id and support can find the exact
request server-side.

### What is not in the logs, and why

`docs/skills/security.md` §10 forbids logging passwords, tokens, e-mail addresses,
phone numbers, employee IDs, depot data and money, and `LogRedactor`
enforces it by key name *and* by value shape. Logs outlive the session that
produced them: they get pasted into bug reports, and on Android any app holding
`READ_LOGS` can read them.

This is why login logs `identifierKind=employeeId` rather than the identifier,
and never the password. It is also why fields are named `signedIn` rather than
`authorized` and `records` rather than `totalRecords` — the redactor masks any
key containing `auth` or `total`, so the obvious names would print
`***REDACTED***` and hide the very thing being debugged.

Two deliberate adjustments were made to the redactor to keep it usable:

- `employee` / `personnel` / `staff` / `badge` were **added** to the masked key
  fragments. An employee ID names a specific person, and `ADM000001` is too
  short to trip the digit-run rule, so nothing else caught it.
- `correlationId` / `traceId` are **exempt from the digit-run rule only**,
  because a trace id like `0HNNOE4PB87QD:00000001` was being masked outright.
  The exemption is an anchored exact-key match and still redacts anything
  JWT- or e-mail-shaped. Checked *before* the sensitive-key pass, since
  `correlationId` incidentally contains `lat`.

Covered by `test/core/logging/api_log_redaction_test.dart`, which pins both
halves: what must never survive, and what must.

### Seeing the actual payloads

When you need the real request and response bodies:

```
flutter run --dart-define=API_LOG_BODIES=true
```

Bodies are still redacted before printing, and the flag is ignored entirely in
release builds. Keep it to your own machine.

## Running against mocks

Live is the default. The mock data sources are still registered behind a switch:

```
flutter run --dart-define=USE_MOCK_DATA=true
```

Useful for demos and offline UI work. A build that silently defaults to mocks is
a build that looks like it works and ships nothing, which is why the default
went the other way.

**My Visits ignores this flag** — its fixtures were deleted when the real route
and push endpoints landed, so it is always live. See the section below.

## My Visits — routes and visit push

Three endpoints, wired behind the two data-source interfaces the feature
already had. `docs/feature/my-visits/api.md` is the contract; this section records
only what the *client* does with it.

| Interface | Live implementation | Endpoint |
|---|---|---|
| `RouteRemoteDataSource` | `ApiRouteRemoteDataSource` | `GET /api/v1/mobile/visits/routes`, `…/routes/delta` |
| `VisitSyncRemoteDataSource` | `ApiVisitSyncRemoteDataSource` | `POST /api/v1/mobile/visits/push` |

Both went in behind the existing interfaces, so nothing above the data layer
changed — `RouteSyncRepositoryImpl` and `VisitSyncRepositoryImpl` already
implemented the pending-queue and partial-acceptance behaviour the contract
asks for.

**These are now the only implementations.** The fixture sources they replaced
(`MockRouteRemoteDataSource`, `MockVisitSyncRemoteDataSource`,
`assets/mock/routes.json`, `data/mock/mock_route_data.dart` and
`tool/generate_mock_routes.dart`) have been deleted, and My Visits no longer
reads `USE_MOCK_DATA` — that flag still switches the catalog and depot
features, which keep their fixtures.

Two reasons the route fixtures could not stay. Routes are **rep- and
day-scoped**, so a committed fixture set is wrong the moment the calendar
moves; the deleted mock papered over that by rebasing its baked dates onto
today on every load. And the push mock accepted *every* row unconditionally —
the one behaviour a push endpoint must never be assumed to have, since it hides
the rejected/pending handling the whole offline queue depends on. Between them
they could make a missing or misbehaving endpoint look perfectly healthy.

Tests script the HTTP transport instead of substituting a fake feed
(`test/features/my_visits/route_feed_fixture.dart`), which is strictly more
coverage: the old mock built `RouteSyncPage` objects directly, so every test
using it skipped the JSON parsing the real app has to do.

### Paging is converted, not renumbered

The interface is **0-based** — that contract was set by the mock, and
`RouteSyncRepositoryImpl` counts from 0 to match. The API is **1-based**, like
`/mobile/depots`. `ApiRouteRemoteDataSource` adds one when building the
query and leaves both sides alone. This is not cosmetic: the depot endpoint
silently treats page 0 as page 1, so an unconverted first call would fetch page
one twice and never read the last page.

### `repId` is never sent

`RouteSyncScope` carries a `repId`, and it stays on the device. The server
derives the rep from the bearer token and is required to refuse another rep's
routes; sending a client-supplied rep id would only imply it were trusted.
Only `territory` goes on the wire, as a filter.

### Two encodings of the same models

Every capture model has a `toRow()` — that is the **Drift** shape: snake_case,
booleans as `0`/`1`. The wire shape is camelCase with real JSON booleans, and
lives separately in `data/models/visit_api_mapper.dart`. Reusing `toRow()` for
the request would send `stop_id` and `is_mocked: 1` to an endpoint documented to
read `stopId` and `isMocked: true`.

Timestamps go out through `formatIsoOffset` (`core/network/api/api_envelope.dart`),
the inverse of `parseUtc`. `DateTime.toIso8601String()` alone is unsafe here:
on a local `DateTime` — what every offline capture is stamped with — it emits
no offset at all, and a server guessing UTC moves a Cambodian morning check-in
(UTC+7) into the previous night. The client's own timestamp is never
overwritten with server time.

### What the client does with the response

`acceptedIds` are marked synced; everything else stays pending, including ids
that come back in neither list. That falls out of the existing repository
rather than needing a special case — only ids present in `acceptedIds` are ever
marked. A transport failure throws, so no row is marked at all, and re-posting
the same batch is safe because the backend is idempotent on the
client-generated row ids.

### Photos do not sync (OPEN-1, blocking)

`VisitPhoto.url` is a path on the device, and binary cannot travel in the JSON
batch. There is no upload endpoint. `toPushJson()` therefore sends `photos` as
an always-empty list and reports the held-back ids as rejected, so they stay
pending on the device.

This is deliberate and must not be "fixed" by sending the local path: the
server would accept the row, the client would mark it synced, and the image
would be lost the moment the app sandbox is cleared — a silent data-loss bug
that looks like success. A batch containing *only* photos makes no request at
all rather than posting eight empty arrays.

Unblocking it needs a backend decision between a multipart
`POST /mobile/visits/photos` and pre-signed upload URLs; the client change is
then upload-first, rewrite `url`, include the rows.

### Other open items carried in code

- **OPEN-2** — `rejectedIds` means "retry later" and there is no "permanently
  invalid" bucket, so a genuinely bad row retries forever. A `discardedIds`
  addition needs a matching client change (TODO in
  `api_visit_sync_remote_data_source.dart`).
- **OPEN-5** — route and stop status (`updateStopStatus`, `updateRouteStatus`)
  are written **locally only** and are not in the push contract. The client has
  no field to send them in, so this implementation leaves that as-is and relies
  on the server deriving the transitions from check-in/check-out, which is the
  simpler of the two options the spec leaves open. Pushing them explicitly
  would need a new payload section on both sides.
- **OPEN-6 — resolved.** `RouteSyncScope.forCurrentUser` now reads
  `AuthProfile.territoryCode` through `SessionManager.territoryCode`; the auth
  payload does carry it (`auth.session.restored … territory=PP-NORTH`). The
  old hardcoded `'Phnom Penh'` was correct only for the deleted fixture and
  returned an empty day for every real rep. When the profile names no
  territory the query key is omitted rather than sent empty, so the server
  scopes from the token alone.
