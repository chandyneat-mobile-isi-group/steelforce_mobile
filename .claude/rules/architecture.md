# Architecture

Authoritative: `docs/skills/engineering-standard.md` §3–§9,
`docs/blueprint/system-architecture.md`, `docs/adr/`.
This file is the enforceable summary.

---

## 1. Layering — inward dependencies only

```
presentation (BLoC/Cubit, widgets)
      ↓
domain (entities, usecases, repository interfaces)
      ↓
data (repository impls, Drift DAOs, remote datasources, models)
```

- **Domain must never import Flutter, Drift, or `dio` types.** If a domain file
  needs one, the abstraction is in the wrong place.
- Repository implementations return **domain entities**, never raw Drift rows
  or DTOs (ADR-003).
- All local reads/writes go through generated Drift DAOs in
  `core/database/drift/daos/` (ADR-004). No feature holds a private database
  handle.
- **No feature imports another feature's `data/` layer.** Cross-feature flows go
  through domain interfaces or a shared orchestration layer.
- **One usecase per business action.** No usecase branches on a "mode"
  parameter to do several unrelated things.

---

## 2. Folder ownership

| Path | Owns |
|---|---|
| `lib/core/` | Cross-cutting infrastructure only: `network/`, `database/`, `theme/`, `di/`, `sync/`, `localization/`, `responsive/`, `notifications/`, `session/`, `error/`, `logging/`, `permissions/`, `platform/`, `animations/`, `camera/`, `pdf/`, `auth/`, `bootstrap/`, `config/`, `usecase/`, `utils/` — map and placement rules in `lib/core/README.md` |
| `lib/features/<feature>/` | `data/`, `domain/`, `presentation/`, and `<feature>_injection.dart` |
| `lib/shared/` | Widgets and animations used by **more than one** feature |
| `lib/routes/` | Navigation |

A widget used by one feature lives in that feature, not in `shared/`. Promote it
to `shared/` only when a second feature actually needs it.

**One concern, one folder.** `core/` had grown parallel homes for the same job;
these are now settled and must not be re-split:

| Concern | The one home | Not |
|---|---|---|
| Device & OS capability probing | `core/platform/` | ~~`core/device/`~~ |
| `dio` interceptors | `core/network/` | ~~`core/middleware/`~~ |
| PDF generation, storage, opening | `core/pdf/` | ~~`core/services/pdf/`~~ |
| Color tokens | `core/theme/app_colors.dart` | ~~`core/utils/colors.dart`~~ |
| API routes, timeouts, paging | `core/network/api/api_endpoints.dart`, `api_defaults.dart` | ~~`core/constants/app_constant.dart`~~ |
| Secure-storage / Hive keys | `core/database/secure/secure_storage_keys.dart`, `core/database/hive/preference_keys.dart` | ~~`AppConstants.k*`~~ |
| Transitions & interaction motion | `core/animations/` | ~~`core/utils/`~~ |

`core/utils/` is for small, dependency-light helpers only — never widgets.
A widget in `utils/` is misfiled; move it to `core/animations/`,
`lib/shared/widgets/`, or the owning feature.

---

## 3. Dependency injection

`get_it`, registered per feature in `lib/features/<feature>/<feature>_injection.dart`
and composed through `lib/core/di/injection_container.dart`. Follow the existing
registration style in the feature you are touching; do not introduce a second DI
mechanism.

---

## 4. Persistence

| Data | Home |
|---|---|
| Business data (depots, routes, visits, orders, quotations, catalog) | The **encrypted Drift database** (`core/database/drift/`) |
| Tokens, cached user, the device encryption key | `flutter_secure_storage` — **nothing else** |
| Non-sensitive local prefs (theme mode, flags) | Hive (`core/database/hive/`) |

- **Cipher path is `sqlcipher_flutter_libs`** — ratified by **ADR-008**, which
  amends the earlier `sqlite3mc` recommendation in
  `docs/blueprint/local-storage-architecture.md` §2.3. The on-disk format is
  locked; do not change it without a superseding ADR.
- Encryption uses the composite device-bound key scheme in
  `docs/blueprint/local-storage-architecture.md` §2. Never improvise crypto.
- **Local mirror tables carry no foreign keys** (ADR-011). The backend owns
  referential integrity; enforcing it again on-device turned normal conditions
  into data loss. Check `local-storage-architecture.md` §3.0 before adding any
  constraint.
- **Transactional writes**: a write to a syncable table must enqueue its
  sync-queue row in the *same* Drift transaction as the mutation (ADR-006).
  This is a correctness rule, not a style preference.

After any Drift table or DAO change:
`dart run build_runner build --delete-conflicting-outputs`.

---

## 5. Offline-first

The local database is the source of truth (ADR-002). Every write succeeds
locally first; sync is opportunistic and never blocks the UI. Connectivity means
**real reachability**, not interface-up (ADR-005) — use
`core/network/connectivity/connectivity_service.dart`, not a raw `connectivity_plus` result.

---

## 6. Naming

- `conflict_manager.dart` — not `conflict_resolver.dart`
- `dynamic_key_store.dart` — not `secure_strorage.dart`

These are deliberate corrections of drift already found in the codebase
(`docs/skills/engineering-standard.md` §9). The domain term is **depot**, not
customer — the rename is complete in `lib/features/depots/`; do not reintroduce
"customer" in new code.

---

## 7. Changing existing architecture

Do not replace a working pattern because a different one is more familiar.
Before any structural change: understand why the current shape exists, run
`graphify affected`, and state the impact to the user. If a `docs/blueprint/`
document describes a different target state than the code, that divergence is a
finding to report — see `.claude/CLAUDE.md` §6.
