# Flutter Web — Architecture, Deployment, Troubleshooting

> ISI Steel Sales — Android · iOS · **Web**, one codebase.
> Companion to `docs/blueprint/web-migration-plan.md` (the plan) and [ADR-010](../adr/ADR-0010-web-persistence.md) (the persistence decision). This document describes what was **built**.
> Verified against Flutter `3.44.4`, 2026-07-29.

---

## 0. Status

| | |
|---|---|
| `flutter build web --release` | ✅ Passes |
| `flutter analyze` | ✅ 0 errors (15 pre-existing warnings/infos, none web-related) |
| `flutter test` | ✅ **230 pass, 0 fail** |
| Foreign keys in the live schema | ✅ **6/6** — see §8; asserted by `test/core/database/drift/foreign_key_schema_test.dart`, so CI blocks on regression |

> **Updated 2026-08-27.** This row read "22/22" when written on 2026-07-29. [ADR-0011](../adr/ADR-0011-local-mirror-no-foreign-keys.md) (2026-08-24) removed the foreign keys from tables that mirror backend-owned state, leaving 6. The test asserts both the survivors and the deliberate absences — read ADR-0011 before changing that number, and never simply update it to make a build pass.
| Android / iOS | ✅ Unchanged. No mobile behaviour was altered. |

---

## 1. What changed, in one picture

```
                        ┌──────────────────────────────┐
                        │  presentation / domain / data│  ← 100% shared, untouched
                        └──────────────┬───────────────┘
                                       │
                        ┌──────────────▼───────────────┐
                        │  AppDatabase · DAOs · tables │  ← 100% shared
                        └──────────────┬───────────────┘
                                       │
       ┌───────────────────────────────┴───────────────────────────────┐
       │            conditional imports (compile-time)                  │
       ├────────────────────────────────┬──────────────────────────────┤
       │  dart.library.ffi / io present │  otherwise (web)             │
       │  ── Android · iOS ──           │  ── Browser ──               │
       │  SQLCipher, encrypted at rest  │  sqlite3.wasm, in memory     │
       │  app-sandbox files             │  blob URLs, nothing at rest  │
       │  open_filex, NetworkInterface  │  download / not available    │
       └────────────────────────────────┴──────────────────────────────┘
```

**No business logic is duplicated.** Every platform difference sits in a matched pair of files behind a conditional export. There are exactly six such seams (§3).

---

## 2. Storage on web (ADR-010)

The web build runs the **same** `AppDatabase`, schema, DAOs, migrations, and repositories as mobile, against an **in-memory** `sqlite3.wasm` database.

- **Nothing is persisted.** Closing the tab discards the data.
- **Nothing is encrypted**, and that is acceptable *only because* nothing is at rest. `sqlite3.wasm` is a vanilla SQLite build; SQLCipher has no web port.
- **Offline is session-scoped.** A rep can work disconnected for as long as the tab stays open. Unsynced work is lost if the tab closes while offline.

> ### Do not "add persistence" to the web build
> Switching `WasmDatabase.inMemory()` to `WasmDatabase.open()` would write depot PII, GPS traces, and quotation pricing to OPFS/IndexedDB — storage readable by any script on the origin. That is the exact finding `docs/blueprint/migration-plan.md` T1.5 exists to remove from mobile, reintroduced on a new platform, and it violates `docs/skills/security.md` §3. It needs an ADR superseding ADR-010, not a one-line change.
>
> The in-memory VFS is registered as the **default** so this is structural, not a convention: there is no durable filesystem for SQLite to write to even if someone passes a path.

Implementation: [`web_database.dart`](../../lib/core/database/drift/connection/web_database.dart).

---

## 3. Platform seams

Every seam follows the same shape: a doc-only facade file with a conditional `export`, plus two implementations exposing identical signatures.

| Facade | Mobile | Web |
|---|---|---|
| `core/database/drift/connection/database_connection.dart` | SQLCipher, encrypted (ADR-008) | `sqlite3.wasm`, in memory |
| `core/database/drift/migrations/legacy/legacy_source_factory.dart` | `sqflite` reader for legacy DBs | always "absent" — a browser never ran the sqflite build |
| `core/services/pdf/pdf_file_store.dart` | writes to app sandbox | keeps bytes in memory |
| `core/services/pdf/pdf_opener.dart` | `open_filex` | unreachable (share path is used) |
| `core/platform/storage/local_files.dart` | `dart:io` `File` reads/exists | reports absent |
| `core/platform/storage/captured_media_store.dart` | writes captured media to disk | session-lifetime `blob:` URL |
| `core/platform/environment/vpn_probe.dart` | `NetworkInterface` scan | **always false — see §7** |

**The discriminator is `dart.library.ffi` / `dart.library.io`, not `kIsWeb`.** `kIsWeb` is a runtime check, so both branches must still compile; `dart:ffi` does not exist on web, so the compile fails before any runtime check could help. `kIsWeb` is used only for *behaviour* selection at a point where the imports are already resolved (e.g. `PdfShareService.openSaved`) and in presentation-layer layout decisions.

**Rule:** `kIsWeb` must not appear in domain code, repositories, DAOs, or usecases — only in `*_injection.dart`, in `core/` seam selection, and in layout code.

---

## 4. T1.5b — sqflite is gone

The web target could not compile while 10 files imported `sqflite`, which has no web implementation. Rather than stub them, **T1.5b was completed** (it was already the next item on `docs/blueprint/migration-plan.md`):

- New Drift tables: `quotations`, `sales_orders`, `sync_queue` (schema **v12**), `workflow_state` (**v13**).
- New DAOs: `QuotationDao`, `SalesOrderDao`, `SyncQueueDao`, `WorkflowStateDao`.
- The four datasource impls now sit on Drift. **Interfaces, `DataMap` row shapes, and exception messages are unchanged**, so no repository or bloc was touched.
- `LegacyOrdersImporter` drains the plaintext `catalog.db` into the encrypted database on first launch after upgrade — **without it, every device upgrading would silently lose its saved quotations and, worse, its unsynced sync-queue rows.**
- `catalog_database.dart` and `routes_database.dart` (legacy schema owners) were deleted, as were three retained-but-unregistered sqflite datasource impls superseded by their Drift equivalents.

`sqflite` now appears in exactly one file — [`legacy_sqlite_source_native.dart`](../../lib/core/database/drift/migrations/legacy/legacy_sqlite_source_native.dart) — whose only job is draining the two legacy files on upgrading devices. Once both imports are confirmed across the fleet, that file, its web twin, both importers, and the dependency go together.

**Security consequence:** the last plaintext business data on mobile (quotation pricing, depot identifiers, and the sync queue's pending payloads) is now encrypted at rest.

---

## 5. Responsive design

Three Material 3 window size classes in [`core/responsive/breakpoints.dart`](../../lib/core/responsive/breakpoints.dart):

| Class | Width | Layout |
|---|---|---|
| compact | `< 600` | **The existing mobile design, unchanged.** |
| medium | `600–1024` | Navigation rail (icons), content clamped |
| expanded | `> 1024` | Navigation rail (labelled), content clamped to 1200px |

### The ScreenUtil problem, and the one-line fix

43 files scale through `flutter_screenutil` against `designSize: Size(390, 844)`. That multiplies every padding, radius, and font size by `screenWidth / 390` — about **4.9×** on a 1920px browser window.

Rather than edit 43 files, the design size itself is now responsive ([`app.dart`](../../lib/app.dart)):

- compact → `390×844`, exactly as before, so **phone rendering is unchanged**;
- wider → the real viewport, making the scale factor `1.0`, so `16.w` means 16 logical pixels and layout is driven by breakpoints and constraints.

### Navigation

Phones navigate between the five shell sections via the app bar and the home "My Work" grid — there is no bottom bar. On medium/expanded a `NavigationRail` is **added** (nothing is replaced), driving the same `ShellTabController`, so deep links and `goTo()` calls from anywhere stay in sync with it automatically.

`ResponsiveContentFrame` is a **pass-through on compact** — it returns its child with no wrapper at all, so it cannot affect mobile sizing, scrolling, or goldens.

---

## 6. GitHub Pages deployment

**Live URL:** `https://dydev99.github.io/isi-steel-sales-mobile/`
**Source branch:** `web`
**Workflow:** [`.github/workflows/deploy-web.yml`](../../.github/workflows/deploy-web.yml) — triggers on push to `web`, plus manual dispatch.

### Required one-time repository setup

**Settings → Pages → Build and deployment → Source: `GitHub Actions`.**

This cannot be set from a workflow file, and **until it is set, nothing this workflow produces reaches the site.**

While the Source is left at its default, "Deploy from a branch", Pages ignores the workflow completely and serves the branch's raw contents through Jekyll. Jekyll renders `README.md` as the home page — so the site shows the README's *"A new Flutter project"* boilerplate rather than the app. If you are seeing that text, this setting is the reason; it is not a build failure, and rebuilding will not change it.

### Why refresh and deep links work

The app uses Flutter's **default hash URL strategy** (`/#/depots`). A browser never sends the fragment to the server, so a refresh requests only `/isi-steel-sales-mobile/`, which Pages serves as `index.html`, and Flutter restores the route client-side. Back/forward work through normal browser history.

**This is why no GoRouter migration was needed.** `usePathUrlStrategy()` would produce `/isi-steel-sales-mobile/depots`, which GitHub Pages — a static file host with no rewrite rules — would answer with a 404. The existing `onGenerateRoute` navigation was left exactly as it is.

A `404.html` copy of `index.html` is published anyway as defence for stale links, hand-typed paths, or a future switch to path URLs. A `.nojekyll` marker stops Pages' Jekyll pass from dropping underscore-prefixed files.

### Content Security Policy

The CSP is **injected into `build/web/index.html` by the deploy workflow**, not declared in `web/index.html`.

That is deliberate. `flutter run -d chrome` serves the source `index.html`, and the debug bootstrap — the DDC module loader and the hot-reload client — executes inline scripts. A policy strict enough to be worth having blocks every one of them, so putting it in the source file would trade a real security control against every developer's ability to run the app. Injecting at deploy time gives production the strict policy and leaves debug alone. The `404.html` copy is made *after* injection, so it carries the policy too.

The policy:

```
default-src 'self';
script-src  'self' 'wasm-unsafe-eval';
style-src   'self' 'unsafe-inline';
img-src     'self' data: blob: https:;
font-src    'self' data:;
connect-src 'self' https:;
worker-src  'self' blob:;
object-src  'none';
base-uri    'self'
```

- `'wasm-unsafe-eval'` is required — CanvasKit and `sqlite3.wasm` both instantiate WebAssembly. It permits WASM compilation only; it does **not** re-enable `eval()` for JavaScript.
- `'unsafe-inline'` appears for **styles only**, because Flutter injects stylesheets at runtime. Scripts have no such escape hatch: the first-paint loader lives in [`web/boot.js`](../../web/boot.js) rather than an inline `<script>` precisely so `script-src` can stay at `'self'`.
- Adding Google Maps on web later means adding its exact origin to `script-src` and `connect-src`. Never widen either to a wildcard.

**`frame-ancestors` is not included, and clickjacking is therefore not blocked.** Browsers ignore that directive when it arrives via `<meta>` — it requires a real HTTP response header, and GitHub Pages cannot send custom headers. The same limitation rules out `Strict-Transport-Security` and `X-Content-Type-Options`. If those matter for a production rollout, Pages is the wrong host; put the build behind a CDN or reverse proxy that can set headers.

### CanvasKit is bundled, not loaded from a CDN

The build passes `--no-web-resources-cdn`, which ships CanvasKit from our own origin instead of fetching it from `https://www.gstatic.com` at runtime. Three reasons, in order:

1. It lets `script-src` stay `'self'`. With the CDN the renderer is a cross-origin script and the app **does not start at all** under a strict policy — a blank page, not a degraded one.
2. It removes a third-party runtime dependency from an app whose users are on unreliable connections. gstatic being slow or blocked would mean a blank screen.
3. Fewer trusted origins is the point of having a policy.

The string `gstatic.com` still appears in `flutter_bootstrap.js`; it is the dead fallback branch. `useLocalCanvasKit: true` in the same file is what actually applies.

### Secrets: the web job never receives them

`Env` is Envied-obfuscated, which defends against **native binary** inspection. A web build is JavaScript — everything in it is readable in devtools, and obfuscation buys nothing.

So the workflow writes a **placeholder `.env`** and never wires `secrets.DB_SALT` into the web job. `DB_SALT` is meaningless on web anyway (ADR-010: no encrypted database to key), and this way it is not merely tree-shaken-and-probably-absent — it was never present at build time.

If the web app needs a real API endpoint, add that one value as a repository variable (`WEB_API_BASE_URL`). Never add the salt.

### Building locally

```bash
flutter build web --release --base-href "/isi-steel-sales-mobile/" --no-web-resources-cdn
```

> **Git Bash on Windows:** MSYS rewrites the leading `/` into a Windows path and the build fails with *"--base-href should start and end with /"*. Prefix the command:
> ```bash
> MSYS_NO_PATHCONV=1 flutter build web --release --base-href "/isi-steel-sales-mobile/"
> ```
> PowerShell, cmd, macOS, Linux, and CI are unaffected.

To serve the built output exactly as Pages will:

```bash
cd build/web && python3 -m http.server 8080
# then open http://localhost:8080/  (base-href must match, or rebuild with "/")
```

---

## 7. Platform differences a user will notice

| Capability | Mobile | Web |
|---|---|---|
| Offline persistence | Full, encrypted, across sessions | **Session only** — lost on tab close |
| Location tracking | Foreground + background | **Foreground only** — browsers cannot track in the background |
| Camera proof photo | Captured, stamped, saved to sandbox | Captured and stamped; blob URL, session-scoped |
| Previously captured photos / drawings | Displayed | **Not displayed** — no filesystem path to read. Screens take their existing "image missing" placeholder branch |
| PDF export | Saved to sandbox, opened in viewer | Print dialog / download |
| Barcode scanner, voice search | Native | Work, but need HTTPS + browser permission; voice is Chrome-only in practice |
| VPN / mock-location detection | Interface scan | **Not available — see below** |

### ⚠️ Web has no VPN detection

Browsers expose no way to enumerate network interfaces (a deliberate privacy protection). `probeVpnInterfaces()` returns `false` on web, so **the web build is permissive**: a rep using a VPN to spoof apparent location is not flagged by this heuristic there.

This is a real, accepted weakening of an anti-fraud control, tagged `// TODO(release-gate):` in [`vpn_probe_web.dart`](../../lib/core/platform/environment/vpn_probe_web.dart) per `docs/skills/security.md` §11.

**Decide before any web release:** is that acceptable for what web exposes, or must location-sensitive actions (geofenced check-in, visit capture) stay mobile-only?

---

## 8. ✅ Resolved — drift_dev silently dropped every foreign key

**Fixed.** All 22 foreign keys are back, all 227 tests pass, and CI now guards
against a recurrence. This section is kept because the defect is still live in
the toolchain and will bite again on upgrade.

### What was happening

Running `dart run build_runner build` with the locked toolchain
(`drift_dev 2.31.0`, `analyzer 10.2.0`) produced a schema with **zero**
foreign-key constraints. The committed `app_database.g.dart` contained 22;
regenerating dropped all of them — silently, with no warning or error.

Lost constraints included `route_stops.depot_id → depots(id)` and the nine
`ON DELETE CASCADE` links from visit captures to `route_stops` — precisely the
referential integrity ADR-001 was adopted to gain.

> **Update (2026-08-24, ADR-011).** Those two particular constraints have since
> been removed *deliberately*, in schema v18, because they destroyed data rather
> than protecting it. That does not retire this section: the codegen bug is
> real, it is still silent, and the six foreign keys the schema **does** still
> declare rely on the `customConstraints` workaround described below. The guard
> test now asserts both halves — that the survivors reach SQLite, and that the
> removed ones do not creep back. See `docs/adr/ADR-0011-local-mirror-no-foreign-keys.md`.

### Why it was not caused by the web work

- The FK-bearing table sources were **untouched** by the web change set.
- `drift`, `drift_dev`, `analyzer`, `sqlite3` and `build_runner` versions were
  **identical** between `HEAD` and the working tree. The committed generated
  file was simply **stale** — it predated the locked toolchain. Regenerating at
  `HEAD` would have dropped the FKs too.
- Reproduced minimally: a fresh two-table database with a textbook
  `text().references(Parents, #id)` also generated **0** constraints.

The web work merely **forced the regeneration** that surfaced it. Anyone running
codegen for any reason would have hit it.

### Root cause

In `drift_dev`'s `resolveDartReference`, the reference resolves to neither
`ReferencesItself` nor `ResolvedReferenceFound`, so the constraint is dropped
through a silent `else` with no diagnostic. Consistent with analyzer 10's
element-model change (`drift_dev 2.31.0` allows `analyzer >=8.1.0 <11.0.0`).

Two upgrade paths were tried and rejected:

- Downgrading `drift`/`drift_dev` to 2.20.3 does not resolve against the current
  dependency set.
- Pinning `analyzer: ^9.0.0` via `dependency_overrides` breaks `dart_style`
  (`PrimaryConstructorBody` isn't a type), so codegen cannot run at all.

### The fix

Each affected table declares its constraints explicitly via drift's
`customConstraints`, which the generator **does** honour:

```dart
class RouteStops extends Table with SyncableTable {
  @override
  String get tableName => 'route_stops';

  @override
  List<String> get customConstraints => [
        'FOREIGN KEY (route_id) REFERENCES routes (id) ON DELETE CASCADE',
        'FOREIGN KEY (depot_id) REFERENCES depots (id)',
      ];

  TextColumn get routeId =>
      text().references(Routes, #id, onDelete: KeyAction.cascade)();
  ...
}
```

Applied to 18 table classes across four files —
`catalog_tables.dart` (4), `depot_related_tables.dart` (5),
`route_tables.dart` (5), `visit_tables.dart` (8) — restoring all 22 constraints.

Notes on the shape of the fix:

- **`references()` is deliberately kept.** It still drives drift's Dart-side
  relation API and manager queries; only the *SQL emission* was broken. Deleting
  it would turn a generator bug into a permanent source change.
- **`customConstraints` is additive** — drift documents it as "custom table
  constraints that should be added", and `PRIMARY KEY` / `CHECK` output is
  unaffected. Verified by inspecting the live `sqlite_master` SQL, not inferred.
- **This is a workaround, not a repair.** When the generator is fixed, these
  overrides should be removed and the FK tests re-run to confirm `references()`
  is emitting again.

### The guard

Because the failure mode was *silent*, the fix ships with a dedicated test:
[`test/core/database/drift/foreign_key_schema_test.dart`](../../test/core/database/drift/foreign_key_schema_test.dart).
It asserts the count is 22, spot-checks the specific relationships ADR-001
depends on, and confirms `PRAGMA foreign_keys` is actually on — a constraint
that exists but is not enforced is decorative.

It queries the **live `sqlite_master` schema**, and that choice matters:

- **Not the table sources** — they were correct the whole time; codegen dropped
  the constraints.
- **Not `app_database.g.dart`** — `customConstraints` is an override on the
  *source* table class, so the generated `$…Table` subclass inherits it and the
  string never appears in generated output. A grep there returns 0 even when the
  schema is perfect. (This was tried first and would have failed every build.)

`sqlite_master` is the only place the truth is visible.

### If you upgrade drift

Re-run codegen and check the count **before** committing. If it drops again, the
generator has regressed further (or the overrides were removed prematurely). Do
not "fix" a failing FK test by weakening the test.

## 9. Troubleshooting

**Blank page under the repo sub-path, 404s on `main.dart.js`**
`--base-href` was omitted or does not match the repository name. Check `<base href="...">` in the deployed `index.html`.

**`sqlite3.wasm` 404 → app hangs after first frame**
The file must be committed at `web/sqlite3.wasm` (~730 KB) and is loaded via a **relative** URI so it resolves against `<base href>`. Never change that to a leading-slash path — it works on localhost and breaks on Pages. The workflow fails the build if the file is missing.

**`Dart library 'dart:ffi' is not available on this platform`**
Something reached the web compile through a native-only path. Find the offending import and route it through a seam (§3) — do not add a `kIsWeb` runtime check, which cannot help at compile time.

**Wasm dry-run warnings during build**
Expected and harmless. `flutter_secure_storage_web` and `geolocator_web` still use legacy `dart:html`, so `--wasm` is not used; the default JS build is unaffected. Revisit when those plugins move to `package:web`.

**Everything is enormous in the browser**
The responsive `designSize` in `app.dart` is not taking effect. Confirm the widget tree still has `LayoutBuilder` above `ScreenUtilInit`.

**`--base-href should start and end with /` on Windows**
Git Bash path conversion — see §6.

**CSP errors in the console**

These have specific causes; do not "fix" them by adding `'unsafe-inline'`, which removes most of the policy's value.

| Console message | Cause and fix |
|---|---|
| `'frame-ancestors' is ignored when delivered via a <meta> element` | Expected and unavoidable on GitHub Pages — see §6. Not a regression. |
| `Loading the script 'https://www.gstatic.com/flutter-canvaskit/...' violates...` | The build omitted `--no-web-resources-cdn`. The app will show a blank page. Rebuild with the flag. |
| `Executing inline script violates...` | Something added an inline `<script>` to `index.html`. Move it to an external file next to `boot.js`. |
| Inline-script violations from `client.js` / `ddc_module_loader.js` during `flutter run -d chrome` | A CSP leaked into the **source** `web/index.html`. It belongs only in the deploy step — debug bootstraps run inline scripts by design. |
| Violations naming a `kaspersky-labs.com` origin | Local antivirus injecting itself into the page and rewriting the policy. A property of that machine, not of the build — verify in a clean profile before investigating. |

---

## 10. Related documents

- Decision and rejected alternatives for web storage: [ADR-010](../adr/ADR-0010-web-persistence.md)
- The analysis and phased plan this implements: [`docs/blueprint/web-migration-plan.md`](web-migration-plan.md)
- Storage/crypto rules every option was measured against: [`docs/skills/security.md`](../skills/security.md)
- Layer rules the seams preserve: [`docs/blueprint/system-architecture.md`](system-architecture.md), ADR-003, ADR-004
- T1.5b's place in the roadmap: [`docs/blueprint/migration-plan.md`](migration-plan.md)
