# ADR-010: Web Persistence Posture — Session-Scoped In-Memory Drift

- **Status**: Accepted
- **Date**: 2026-07-29
- **Deciders**: Solution / Flutter / DB / Security architecture review
- **Related**: `docs/blueprint/web-migration-plan.md` §3/§10, `docs/skills/security.md` §3/§4, `docs/blueprint/system-architecture.md` §3, ADR-001, ADR-002, ADR-008

---

## Context

`docs/blueprint/web-migration-plan.md` establishes that the presentation and domain layers of this app are web-ready, and that the blocker to a Flutter Web target sits entirely in `core/` persistence. The specific problem:

`docs/blueprint/system-architecture.md` §3 assigns every byte of application state to one of four stores, and three of them have no faithful web equivalent.

| Layer | Mobile | Web reality |
|---|---|---|
| 1. Relational business data | Drift + SQLCipher, encrypted at rest | Drift on web runs `sqlite3.wasm` — **a vanilla SQLite build with no SQLCipher**. Storage is OPFS/IndexedDB, readable by any script on the origin. |
| 2. Non-sensitive prefs | Hive | ✅ Hive → IndexedDB. Faithful. |
| 3. Secrets | Keychain / Keystore, hardware-backed | `flutter_secure_storage_web` wraps WebCrypto over `localStorage` — **not hardware-backed, XSS-reachable**. |
| 4. Media / files | App sandbox, path stored in Drift | No filesystem. Blobs in memory or object URLs; a stored path is meaningless. |

`sqlcipher_flutter_libs` (ratified by ADR-008) publishes no web implementation, and `openEncryptedDatabase` fails closed when `PRAGMA cipher_version` returns empty. **On web, the existing code therefore refuses to open the database.** That is the ADR-008 guarantee working as designed, not a defect — but it means a web target cannot ship until this ADR says what web persistence *is*.

The decision is architecturally significant and cannot be inferred from the mobile design, because the mobile design assumes a hardware-backed keystore that browsers do not have. Left undecided, the path of least resistance for the next engineer is `WasmDatabase` + IndexedDB, which writes depot PII, GPS traces, and quotation pricing to unencrypted browser storage — reintroducing on a new platform the exact finding `docs/blueprint/migration-plan.md` T1.5 exists to close.

## Decision

**The web build persists no business data at rest. It runs the same Drift `AppDatabase` against an in-memory WASM executor (`WasmDatabase.inMemory()`), scoped to the browser session and discarded when the tab closes.**

Consequently:

1. **`docs/blueprint/system-architecture.md` §3 Layer 1 is amended for the web target only**: business data lives in an *ephemeral* Drift database. Encryption at rest is not required because there is no rest — the requirement is satisfied by absence of persistence, not by a weaker cipher.
2. **ADR-008 is unaffected.** The SQLCipher path and its fail-closed checks remain the mobile standard, unchanged. This ADR supersedes nothing.
3. **ADR-001 (single database) and ADR-002 (local DB is the source of truth) hold on web.** The schema, DAOs, migrator, repositories, usecases, sync queue, and optimistic-UI paths are byte-identical across platforms. Only the executor differs, selected by conditional import.
4. **Layer 4 (media) on web is in-memory `Uint8List`/`XFile`**, never a filesystem path. Presentation code must not assume `dart:io File`.
5. **Layer 3 (secrets) on web is explicitly weaker** and is handled separately under `docs/blueprint/web-migration-plan.md` §4/W6 — short-lived in-memory access tokens, strict CSP, and a compile-time guard ensuring `Env.dbSalt` and SAP credentials never reach a web bundle. **Envied obfuscation provides no protection in a JS/WASM bundle** and must not be relied on there.

Offline capability on web is therefore **session-scoped**: a rep can work disconnected for the length of a browser session, and unsynced work is lost if the tab closes while offline. This limitation must be stated honestly in `docs/blueprint/offline-architecture.md` and surfaced in the web UI — it must not be presented as parity with mobile.

**Mobile behaviour is unchanged in every respect.** Mobile remains the reference implementation; web adapts to it.

## Consequences

**Positive**

- **No plaintext PII at rest on any platform.** The web target cannot reintroduce the highest-severity finding in `docs/blueprint/migration-plan.md` §9's risk register, because it writes nothing to disk.
- **One codebase, not two.** Because `AppDatabase`, the DAOs, and every repository are shared, web inherits the sync queue, conflict handling, and optimistic UI for free — and future work on those lands on both platforms simultaneously. A remote-backed web repository layer (the Option A alternative) would have forked the data layer permanently.
- **No new cryptography.** Nothing to design, review, or get wrong. `docs/skills/security.md` §4's "never implement custom cryptography" rule is satisfied trivially.
- **Not blocked on `sap_client.dart`.** That file is still a 0-byte stub (`docs/blueprint/migration-plan.md` Phase 4/7); an online-only web build would have pulled the entire SAP gateway onto the web critical path.
- **Reversible.** If persistent web offline later proves to be a real field requirement, this ADR can be superseded without unwinding schema or repository work — the change is confined to executor selection.

**Negative**

- **Web offline is genuinely weaker than mobile**, and unsynced captures are lost on tab close while disconnected. Accepted: the realistic web use case is desk and back-office work, not a full field day. Mitigation: the web UI must warn before closing with a non-empty sync queue.
- **Cold start on web re-pulls data**, since nothing is cached across sessions. This makes first-load latency a real UX concern on a Cambodian field connection and interacts with the bundle-size budget (`docs/blueprint/web-migration-plan.md` R5/W7).
- **Two executor paths to keep honest.** Divergence between the native and in-memory connections is a live risk (R3). Mitigation is mandatory and non-negotiable: the DAO test suite runs against **both** executors, per `docs/blueprint/web-migration-plan.md` §8.
- **Memory ceiling.** A large catalog pull now sits in browser RAM rather than on disk. Needs measurement before the web target ships; may force pagination limits that mobile does not have.
- **`docs/blueprint/system-architecture.md` §3's four-layer matrix now has a documented platform exception**, which is a small ongoing comprehension cost for new engineers. Mitigated by this ADR being linked from that section.

## Alternatives considered

- **Option A — online-only web (no local database).** Repositories on web call the API directly; nothing is stored client-side. Rejected on cost and coupling, not on security: it forks the data layer into two permanently divergent implementations, discards the sync-queue and optimistic-UI machinery on web, contradicts ADR-002's "local database is the source of truth" rather than merely narrowing it, and is blocked on the unbuilt SAP gateway. Its security properties are equivalent to the chosen option, so it buys nothing for its extra cost. Remains the fallback if the in-memory memory ceiling proves unworkable.

- **Option C — persistent encrypted WASM database (`sqlite3mc`).** The only option offering true persistent offline on web. Rejected because **there is nowhere safe to put the key.** Browsers have no hardware-backed keystore; the key would live in `localStorage`/IndexedDB alongside the data it protects, reachable by any XSS on the origin. That is obfuscation presented as encryption — the most dangerous outcome of the three, because it would let the app claim `docs/skills/security.md` §3 compliance it does not have. It would also require superseding ADR-008, re-proving fail-closed behaviour on a second cipher stack, and maintaining two on-disk formats. Revisit only if a hardware-backed browser key primitive becomes broadly available *and* persistent web offline is shown to be a real field requirement.

- **Leave web unsupported.** Rejected: the business goal is a professional Flutter Web + Mobile product, and the analysis shows the presentation and domain layers already support it. The blocker is one decision, which this ADR makes.
