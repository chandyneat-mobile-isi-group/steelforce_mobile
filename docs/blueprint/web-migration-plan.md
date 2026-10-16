# Flutter Web Support — Migration Plan

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> How this codebase becomes a **Flutter Web + Mobile** application without redesigning it.
> Baseline: branch `feature/impossible`, Flutter `3.44.4`, plugin set resolved 2026-07-29.
> **Status: Planning — awaiting review. ADR-010 (web persistence) is decided; this plan itself is not yet approved, so no production code is authorized.** See `docs/skills/engineering-standard.md` §2, `CLAUDE.md` §1.

> ### ⚠ Historical — this plan was executed (2026-08-27)
>
> **Status above is stale.** The Flutter Web target shipped: `flutter build web
> --release` passes, tests pass, and the app deploys to GitHub Pages via
> `.github/workflows/deploy-web.yml`.
>
> **[web-architecture.md](web-architecture.md) describes what was built and
> wins on any conflict with this document.** This one is retained for the
> reasoning — why the presentation and domain layers were web-ready and the
> blocker sat entirely in `core/` persistence.


---

## 0. Summary

The presentation and domain layers are **web-ready today**. The blocker is entirely in `core/` — the same hollow-infrastructure gap `docs/blueprint/migration-plan.md` already tracks, seen from a new angle.

Three findings drive everything below:

1. **The app's security posture does not survive a naive web port.** `sqlcipher_flutter_libs` has no web implementation, and the browser has no Keychain/Keystore equivalent. A web build that persists business data locally would be storing depot PII **in plaintext in IndexedDB**, which `docs/skills/security.md` §3 forbids and `openEncryptedDatabase`'s fail-closed check exists specifically to prevent. This is an architectural decision, not an implementation detail — §10.
2. **`sqflite` does not run on web, and 17 files still use it.** This is `docs/blueprint/migration-plan.md`'s open **T1.5b** (the Orders catalog DB). Web does not add work here; it makes already-planned work a hard prerequisite.
3. **There is effectively no responsive layer.** 43 files scale through `flutter_screenutil` against a fixed `designSize: Size(390, 844)`; only 2 files use `LayoutBuilder`/`MediaQuery` sizing. On a 1920px browser window every dimension is multiplied by ~4.9. This is the largest *volume* of work but the lowest *risk*.

The good news is structural: **every platform capability is already behind a domain interface** (`LocationTrackingService`, `ProofPhotoService`, `BarcodeScannerService`, `VoiceSearchService`, `ImageSearchService`, `OrderLocationService`, `PdfShareService`). Platform divergence therefore has an existing, correct home — swap the implementation in `<feature>_injection.dart`. No new abstraction pattern needs inventing, and ADR-003's repository rule is untouched.

---

## 1. Web Migration Impact Analysis

### Current architecture

Unchanged by this plan. `presentation (BLoC) → domain → data → core`, inward dependencies only, one `<feature>_injection.dart` per feature into `core/di/injection_container.dart`, boot sequenced by `core/bootstrap/app_bootstrap_service.dart`. See `docs/blueprint/system-architecture.md` §2/§5.

Scale: 13 features, 40 screens, ~600 Dart files. `my_visits` (169 files) and `order` (163 files) carry almost all platform coupling.

### Affected features

| Feature | Files | Web impact | Why |
|---|---|---|---|
| `my_visits` | 169 | 🔴 **High** | `sqflite` datasources, `geolocator` tracking, `google_maps_flutter`, camera proof photos, `dart:io File` in check-in UI |
| `order` | 163 | 🔴 **High** | `sqflite` catalog/quotation/sync-queue (T1.5b), PDF generation + `open_filex` share, barcode scanner, voice search, image search, `dart:io File` in 7 widgets |
| `depots` | 67 | 🟢 Low | Already on Drift; repository-clean |
| `lead` | 70 | 🟢 Low | Mock datasources; no platform coupling found |
| `authentication` | 29 | 🟡 Medium | `flutter_secure_storage` semantics change materially on web (§4) |
| `shell`, `home`, `profile`, `settings`, `app_coach`, `localization`, `splash`, `notification` | ~110 | 🟡 Medium | Layout only — mobile-shaped navigation and fixed scaling (§6) |

### Mobile-only components

Authoritative, derived from the resolved plugin graph (`.flutter-plugins-dependencies`), not from memory:

| Dependency | Web impl | Files | Verdict |
|---|---|---|---|
| `sqlcipher_flutter_libs` | ❌ none | 1 | 🔴 **Blocker** — see §3/§10 |
| `sqflite` | ❌ none | 17 | 🔴 **Blocker** — finish T1.5b |
| `path_provider` | ❌ none | 3 | 🔴 Replace with a storage-location abstraction |
| `dart:io` / `dart:ffi` | ❌ none | 17 / 1 | 🔴 Conditional imports or `Uint8List` |
| `open_filex` | ❌ none | 1 | 🟡 Web uses browser download/print instead |
| `geocoding` | ❌ none | **0** | 🟢 **Unused dependency — drop it** |
| `geolocator` | ✅ `geolocator_web` | 4 | 🟡 Works; browser permission UX differs |
| `google_maps_flutter` | ✅ `google_maps_flutter_web` (0.6.3) | 1 | 🟢 **Configured** — JS API key + `drawing,geometry,marker` libraries in `web/index.html`; CSP origins allowed in `deploy-web.yml`. Behaviour deltas in §5.1 |
| `image_picker` | ✅ `image_picker_for_web` | 5 | 🟡 Returns `XFile`, never a `File` path |
| `mobile_scanner` | ✅ web | 1 | 🟡 Requires HTTPS + camera grant |
| `speech_to_text` | ✅ web | 2 | 🟡 Browser-dependent; Chrome only in practice |
| `file_picker`, `printing`, `connectivity_plus` | ✅ web | — | 🟢 No action |
| `hive_flutter` | ✅ IndexedDB | 6 | 🟢 No action — non-sensitive prefs only |
| `drift` / `sqlite3` | ✅ `wasm.dart` present | — | 🟢 Engine works; **encryption does not** (§3) |

### Required changes

1. Complete **T1.5b** — port the Orders `sqflite` catalog DB to Drift, retiring `sqflite` entirely.
2. Decide and record the **web persistence posture** (ADR-010, §10) — the one blocking decision.
3. Split the database connection behind a **conditional import** (`connection/` native vs. web), leaving `AppDatabase` and every DAO byte-identical.
4. Provide **web implementations** for the seven existing platform service interfaces; register per platform in the feature injection files.
5. Introduce a **responsive layer** (breakpoints + adaptive shell) and retire the fixed `ScreenUtil` design size on wide viewports.
6. Replace `dart:io File` in presentation with `Uint8List`/`XFile` at the widget boundary.

### Risk areas

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | **Plaintext PII in IndexedDB** on web — the exact class of finding T1.5 exists to close, reintroduced on a new platform | 🔴 Critical | ADR-010 must be decided before any web persistence code is written (§10) |
| R2 | Tokens in `flutter_secure_storage_web` are **not hardware-backed** and are XSS-reachable | 🔴 Critical | Short-lived tokens; session-cookie or in-memory strategy; strict CSP (§4) |
| R3 | Conditional-import drift — native and web connection paths diverge silently | 🟠 High | One shared `AppDatabase`; both paths covered by the same DAO test suite |
| R4 | Breaking mobile while making the app responsive | 🟠 High | Breakpoints are additive; `< 600dp` must render byte-identically. Golden tests on mobile widths gate every layout PR |
| R5 | Web build weight (PDF + maps + Lottie + fonts) on a Cambodian field connection | 🟡 Medium | Deferred loading, `--wasm`, font subsetting, measure before/after |
| R6 | Offline-first promise is weaker on web whatever we choose (browser storage is evictable) | 🟡 Medium | State the guarantee honestly in `docs/blueprint/offline-architecture.md`; do not imply parity |

---

## 2. Non-goals

Explicitly out of scope, per the constraints on this work:

- No project rewrite, no folder-structure change, no BLoC replacement.
- **No reduction in mobile offline capability.** Mobile behaviour is the reference implementation; web adapts to it.
- No change to ADR-001 (single database), ADR-002 (local source of truth), ADR-003 (repositories), ADR-004 (DAOs), ADR-006 (sync), ADR-007 (workflow).
- No new state-management, routing, or DI library.

---

## 3. Storage strategy

### 3.1 The conflict, stated plainly

`docs/blueprint/system-architecture.md` §3 assigns every byte to one of four stores. Three of them break on web:

| Layer | Mobile | Web reality |
|---|---|---|
| 1. Relational business data | Drift + SQLCipher, encrypted at rest | Drift runs via `sqlite3.wasm` — **a vanilla SQLite build with no SQLCipher**. Storage is OPFS/IndexedDB, readable by any script on the origin. |
| 2. Non-sensitive prefs | Hive | ✅ Hive → IndexedDB. Unchanged. |
| 3. Secrets | Keychain / Keystore, hardware-backed | `flutter_secure_storage_web` wraps WebCrypto over `localStorage`. **Not hardware-backed, not XSS-proof.** |
| 4. Media / files | App sandbox | No filesystem. Blobs in memory or object URLs. |

`openEncryptedDatabase` refuses to open unless `PRAGMA cipher_version` returns a value (ADR-008, fail-closed check #1). On web that pragma cannot succeed. **The current code correctly refuses to run on web** — that is the design working, not a bug to patch out.

> Anyone tempted to "just use `WasmDatabase` and move on" is proposing to write depot PII, GPS traces, and quotation pricing to unencrypted browser storage. `docs/skills/security.md` §3 forbids it. Do not do this without ADR-010.

### 3.2 Options

| | Option A — Online-only web | Option B — Session-scoped local DB | Option C — Encrypted WASM DB |
|---|---|---|---|
| **Storage** | None. Repositories hit the API. | Drift `WasmDatabase.inMemory()`, wiped on tab close | `sqlite3mc` WASM build, persisted |
| **Offline** | ❌ None | 🟡 Within a session | ✅ Across sessions |
| **PII at rest** | ✅ Never | ✅ Never (memory only) | 🔴 Key must live in browser storage — obfuscation, not protection |
| **Effort** | Medium (needs the SAP gateway, still a 0-byte stub) | Medium | High + a new ADR superseding ADR-008 |
| **Security review** | ✅ Passes | ✅ Passes | ❌ Cannot pass §3 as written |

### 3.3 Decision — Option B (ADR-010, accepted 2026-07-29)

**The web build persists no business data at rest.** It runs the same Drift `AppDatabase` against `WasmDatabase.inMemory()`, scoped to the browser session and discarded on tab close. Full rationale, consequences, and the rejected alternatives are in [ADR-010](../adr/ADR-0010-web-persistence.md).

What this means for the work below:

- `AppDatabase`, tables, DAOs, migrator, repositories, usecases, and the sync queue are **shared byte-for-byte** across platforms. Only the executor differs, selected by conditional import (§5).
- ADR-001, ADR-002, and ADR-008 are **unaffected** — nothing is superseded. Encryption at rest is satisfied on web by the absence of rest, not by a weaker cipher.
- Layer 4 media on web is in-memory `Uint8List`/`XFile`, never a filesystem path.
- **Web offline is session-scoped.** Unsynced work is lost if the tab closes while disconnected. This must be stated in `docs/blueprint/offline-architecture.md` and surfaced in the web UI — never presented as parity with mobile. The web shell must warn before unload when the sync queue is non-empty.
- Two new obligations follow directly: the DAO suite runs against **both** executors (§8, mitigating R3), and the in-memory catalog footprint must be measured before ship (ADR-010 "Negative").

---

## 4. Security deltas on web

Web is a fundamentally different threat model. These must be handled regardless of which option §3 lands on:

- **Tokens**: `flutter_secure_storage_web` is XSS-reachable. Prefer short-lived access tokens held in memory with an `HttpOnly` refresh cookie. If tokens must be stored, document the accepted risk.
- **CSP**: ship a strict `Content-Security-Policy` in `web/index.html`. Google Maps JS and any CDN font need explicit allowances.
- **`Env` obfuscation is void on web.** Envied's obfuscation defeats native binary inspection; a JS/WASM bundle is fully readable. **`Env.dbSalt` and any SAP credential must never reach a web build.** This needs a compile-time guard, not a convention.
- **No root/tamper/biometric detection** (`core/security/`, Phase 8) has any web equivalent. Those controls are mobile-only by definition.
- **Logging**: `docs/skills/security.md` §10's PII rules apply identically; browser consoles are more exposed, not less.

---

## 5. Platform abstraction strategy

The pattern already exists and is followed correctly — **extend it, do not invent a new one.**

```
lib/features/order/
├── domain/services/barcode_scanner_service.dart     ← interface (exists)
├── presentation/services/
│   ├── mobile_scanner_barcode_service.dart          ← mobile impl (exists)
│   └── web_barcode_scanner_service.dart             ← ADD
└── order_injection.dart                             ← selects by platform
```

Selection happens in one place per feature, using `kIsWeb` at the composition root only:

```dart
sl.registerLazySingleton<BarcodeScannerService>(
  () => kIsWeb ? WebBarcodeScannerService() : MobileScannerBarcodeService(),
);
```

**`kIsWeb` must not appear in domain code, repositories, DAOs, or usecases** — only in `*_injection.dart`, in `core/` connection selection, and in presentation-layer layout decisions. This is an extension of ADR-003's boundary rule and should be lint-enforced alongside `docs/blueprint/system-architecture.md` §6's import-boundary work.

For `dart:io` and `dart:ffi`, use conditional imports so neither ever reaches a web compile:

```
core/database/drift/connection/
├── database_connection.dart          ← conditional export, the only public entry
├── encrypted_database.dart           ← native (exists, unchanged)
└── web_database.dart                 ← ADD
```

### Service-by-service plan

| Interface | Mobile impl (exists) | Web approach |
|---|---|---|
| `LocationTrackingService` | `GeolocatorTrackingService` | `geolocator_web`; background tracking is impossible in a browser — degrade to foreground-only and make the UI say so |
| `OrderLocationService` | `GeolocatorOrderLocationService` | `geolocator_web` |
| `ProofPhotoService` | `CameraProofPhotoService` | `image_picker_for_web` → `XFile`/`Uint8List`, no path |
| `BarcodeScannerService` | `mobile_scanner` | `mobile_scanner` web (HTTPS + camera grant), or manual entry fallback |
| `VoiceSearchService` | `SpeechVoiceSearchService` | `speech_to_text` web (Chrome-only); hide the affordance where unsupported |
| `ImageSearchService` | `ImagePickerSearchService` | `image_picker_for_web` |
| `PdfShareService` | `open_filex` | `printing` web → browser print/download |
| `GeofenceService`, `FraudDetectionService` | pure Dart + `dart:io` | Audit: fraud detection imports `dart:io` for device signals that don't exist on web. Web needs an explicitly weaker, documented policy — tagged `// TODO(release-gate):` per `docs/skills/security.md` §11 |

### 5.1 Google Maps on web — configured, with three behaviour deltas

Setup is done: `web/index.html` loads the Maps JavaScript API in `<head>`, and
`deploy-web.yml` allows `maps.googleapis.com` / `maps.gstatic.com` in
`script-src`, `fonts.googleapis.com` in `style-src`, and `fonts.gstatic.com` in
`font-src`. No `pubspec.yaml` change was needed — `google_maps_flutter_web` is
endorsed and already resolves transitively.

**Operational precondition:** the key in `index.html` is public by construction
and must be restricted by HTTP referrer in the Google Cloud console to the Pages
origin plus `localhost`, with the Maps JavaScript API the only API enabled on
it. Unrestricted, it is billable by anyone who views source.

The one map widget ([transit_map.dart](../../lib/features/my_visits/presentation/widgets/transit_map.dart))
renders on web, but three of its behaviours do not survive the port:

| Delta | Effect on web | Fix when web maps become a priority |
|---|---|---|
| `myLocationEnabled` / `myLocationButtonEnabled` are **ignored** by the web plugin ([flutter#64073](https://github.com/flutter/flutter/issues/64073)) | No native blue dot. The GPS-diagnostic use documented in `transit_map.dart`'s `dispose` comment — comparing the OS dot against the tracked marker — is unavailable, and `LocationTrackingCubit`'s marker is the only position indicator | Optional: draw an accuracy circle from `navigator.geolocation` |
| `BitmapDescriptor.defaultMarkerWithHue` is **unsupported** on web; the plugin resolves it to a null icon | Both markers fall back to the same default red pin, so target shop and current position are visually indistinguishable | Ship two marker asset images and select by platform |
| The map is an `HtmlElementView`; Flutter widgets stacked above it **do not receive mouse events** ([flutter#73830](https://github.com/flutter/flutter/issues/73830)) | The recenter FAB in the map `Stack` is unclickable on web (touch/mobile unaffected) | Wrap the FAB in `PointerInterceptor` — adds the `pointer_interceptor` dependency |

None of these break the build or the mobile target; they are web-only fidelity
gaps, and they belong to W3 rather than to this configuration change.

---

## 6. Responsive strategy

### The problem

`ScreenUtilInit(designSize: Size(390, 844))` in [app.dart:57](../../lib/app.dart#L57) linearly scales every `.w`/`.h`/`.sp` across 43 files. That is correct for phones and wrong for every desktop viewport.

### Approach

Three breakpoints, matching Material 3 window size classes:

| Class | Width | Layout |
|---|---|---|
| Compact | `< 600` | Today's mobile layout, **unchanged**. Bottom nav. |
| Medium | `600–1024` | Navigation rail; 2-column lists where they exist |
| Expanded | `> 1024` | Navigation rail/drawer; list-detail split; **content max-width clamped ~1200px** |

Rules:

1. **Compact renders byte-identically to today.** Golden tests at 390×844 gate every layout PR (R4).
2. `ScreenUtil` stays for compact. On medium/expanded, clamp the scale factor to 1.0 and use fixed spacing tokens — do not let a 1920px window multiply every padding.
3. Add `core/responsive/` (breakpoints + a `ResponsiveBuilder`) — a new `core/` sub-module, consistent with `docs/blueprint/system-architecture.md` §5.
4. Adapt the **shell** first (`features/shell`, 23 files). The 40 screens then inherit correct chrome and can be refined by traffic priority.
5. Keyboard and pointer affordances (hover, focus, tab order, `Shortcuts`) are part of "professional web", not a follow-up.

---

## 7. Phased plan

Each phase gates the next. No phase starts before its predecessor's acceptance criteria pass.

| Phase | Work | Depends on | Acceptance |
|---|---|---|---|
| **W0** | ~~ADR-010 decided~~ ✅; **this document reviewed and approved** | — | Signed off |
| **W1** | Complete **T1.5b** — Orders sqflite → Drift; drop `sqflite` and the unused `geocoding` from `pubspec.yaml` | `docs/blueprint/migration-plan.md` T1.5 | Zero `sqflite` imports in `lib/`; existing tests green |
| **W2** | Conditional-import connection split; `path_provider` behind an abstraction; `dart:io` out of presentation | W1, ADR-010 | `flutter build web` compiles; mobile untouched |
| **W3** | Web impls for the 7 platform services; per-platform registration | W2 | Every interface resolves on both platforms; graceful degradation where a capability is absent |
| **W4** | `core/responsive/` + adaptive shell | W2 | Compact goldens unchanged; medium/expanded shell verified |
| **W5** | Screen-by-screen responsive refinement, 40 screens by priority | W4 | Per-screen goldens at 3 widths |
| **W6** | Web security hardening (§4): CSP, token strategy, `Env` guard | W3 | `docs/skills/security.md` review passes for the web target |
| **W7** | Web CI/CD — build, bundle-size budget, deploy | W6 | `docs/release/ci-cd.md` extended; size budget enforced |

**Sequencing note:** W1 is genuinely blocking and is *already on the roadmap*. Web does not add it; web makes it urgent.

---

## 8. Testing

Extends `docs/skills/engineering-standard.md` §10 rather than replacing it. Existing coverage gates (domain ≥ 90%, data ≥ 80%, crypto/sync-queue 100% branches) apply unchanged.

- **DAO tests run against both connections.** One suite, two executors. This is R3's mitigation.
- **Golden tests at 3 widths** (390 / 800 / 1440). Compact goldens are the mobile-regression gate.
- **`flutter test --platform chrome`** for anything touching a conditional import.
- **Platform-service contract tests** — one shared suite each web and mobile implementation must satisfy.
- CI runs `flutter build web --release` on every PR once W2 lands.

---

## 9. What is explicitly NOT changing

For reviewers of any web PR — if a diff touches these, it is out of scope:

- `AppDatabase`, table definitions, DAOs, migrations
- Any repository interface or implementation
- Any BLoC, Cubit, usecase, or entity
- The DI pattern (`<feature>_injection.dart` → `initDependencies()`)
- Boot ordering in `AppBootstrapService`
- Mobile behaviour at any viewport `< 600dp`

---

## 10. Decisions

| # | Decision | Status |
|---|---|---|
| ADR-010 | Web persistence posture — session-scoped in-memory Drift, nothing at rest | ✅ **Accepted 2026-07-29** ([ADR-010](../adr/ADR-0010-web-persistence.md)) |
| — | This plan (W1–W7 sequencing, phase gates) | ⏳ Awaiting review — W0 |

### Still open, but not blocking

These are scoped inside their phases and do not need resolving before W1 starts:

- **Web fraud-detection policy** (W3). `FraudDetectionService` reads `dart:io` device signals that have no browser equivalent. Web needs an explicitly weaker, documented policy tagged `// TODO(release-gate):` per `docs/skills/security.md` §11 — or the feature is disabled on web. Decide when W3 reaches that service.
- **Web token strategy** (W6). §4 recommends short-lived in-memory access tokens with an `HttpOnly` refresh cookie; that requires a server-side change and needs backend agreement. If tokens must instead live in `flutter_secure_storage_web`, the accepted risk gets documented — do not let this default silently.
- **Catalog memory ceiling** (W3/W5). ADR-010 moves the catalog into browser RAM. If measurement shows it doesn't fit, web may need pagination limits mobile doesn't have.

---

## 11. Related documents

- Target architecture and layer rules: `docs/blueprint/system-architecture.md`
- Persistence, encryption, cipher path: `docs/blueprint/local-storage-architecture.md`, ADR-001, ADR-008
- Offline guarantees this plan must not weaken on mobile: `docs/blueprint/offline-architecture.md`, ADR-002
- Storage and crypto rules §3/§4 gate every option above: `docs/skills/security.md`
- Sprint sequencing and the T1.5b prerequisite: `docs/blueprint/migration-plan.md`
- Conventions every web PR still follows: `docs/skills/ai-engineering-playbook.md`, `docs/skills/engineering-standard.md`
