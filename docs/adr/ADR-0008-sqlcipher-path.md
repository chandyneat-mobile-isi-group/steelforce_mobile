# ADR-008: SQLCipher Implementation Path — `sqlcipher_flutter_libs`

- **Status**: Accepted
- **Date**: 2026-07-15
- **Deciders**: Solution / Flutter / DB / Security architecture review
- **Related**: `docs/blueprint/local-storage-architecture.md` §2.3, `docs/blueprint/migration-plan.md` T1.3/T1.5, ADR-001, `docs/skills/security.md` §4

---

## Context

ADR-001 locked the decision to hold all business data in a single Drift database encrypted at rest, but deliberately left the *cipher implementation path* open. `docs/blueprint/local-storage-architecture.md` §2.3 documents two viable paths and required the choice to be recorded as an ADR **before T1.3 starts**:

| Path | Package | Guide's position |
|---|---|---|
| Legacy | `sqlcipher_flutter_libs` | Works; Drift's docs now point new integrations elsewhere; needs `cipher`/`legacy` pragmas to read a database written by a true SQLCipher build |
| Recommended for new work | SQLite3MultipleCiphers (`sqlite3mc`) via Drift's `user_defines` hook | Simpler setup; Drift 2.32+ drops the `sqlcipher_flutter_libs` dependency |

That ADR was never written, and **T1.3 shipped anyway** on `sqlcipher_flutter_libs` — a process gap (`docs/skills/engineering-standard.md` §11) discovered during the 2026-07-15 bootstrap audit. This ADR closes the gap by ratifying the shipped implementation rather than leaving an undocumented decision in production code.

The decision is now blocking: **T1.5 creates the new encrypted database file** that legacy plaintext data is imported into. The cipher path determines that file's on-disk format, so it must be locked before T1.5 writes a single row. Changing it afterwards would mean re-importing every device's data a second time.

## Decision

**Ratify `sqlcipher_flutter_libs` as the project's SQLCipher implementation path.** `docs/blueprint/local-storage-architecture.md` §2.3's recommendation is amended: `sqlite3mc` remains a valid future option, but `sqlcipher_flutter_libs` is the standard for this codebase until a superseding ADR says otherwise.

Rationale — the implementation is already built, tested, and exceeds its own acceptance criteria:

1. **Fail-closed on missing cipher**: after `PRAGMA key`, `openEncryptedDatabase` queries `PRAGMA cipher_version` and throws if it returns empty — the app refuses to open rather than silently writing plaintext. This is the literal T1.3 AC.
2. **Fail-closed on wrong key**: it additionally forces `SELECT count(*) FROM sqlite_master`, making SQLCipher decrypt the header at open time, so a wrong or rotated key fails immediately rather than on the first feature query. This exceeds the AC.
3. **Raw-key mode**: the passphrase is supplied as `PRAGMA key = "x'<hex>'"`, skipping SQLCipher's PBKDF2 — correct, because `KeyDerivation` already produces 256 bits of CSPRNG-derived material (`docs/blueprint/local-storage-architecture.md` §2.1); there is no low-entropy secret to stretch.
4. **Rotation works**: `AppDatabaseRekeyExecutor` issues `PRAGMA rekey` against the live connection, covered by unit tests (T1.6).
5. **Platform loading is handled**: `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()` plus explicit `open.overrideFor` for Android/iOS/macOS.

`docs/blueprint/local-storage-architecture.md` §2.3 itself notes the two paths are "functionally interchangeable at the schema/DAO level," so this choice constrains no other layer.

## Consequences

**Positive**

- Zero rework to proven, tested cryptography on the critical path to T1.5 — the plaintext-PII purge (the highest-severity open finding) is not delayed by re-doing working encryption.
- The on-disk format is locked *before* T1.5 writes the new encrypted file, avoiding a second forced re-import of every device.
- Documents a decision that was already live in production code, closing the `docs/skills/engineering-standard.md` §11 process gap.
- The `legacy = 4` / `cipher` compatibility pragmas §2.3 warns about are not needed: this codebase writes the database with the same SQLCipher build it reads it with, and no true-SQLCipher-authored file predates it.

**Negative**

- Diverges from Drift's current upstream recommendation, so future Drift upgrades carry some risk of the `sqlcipher_flutter_libs` integration being deprioritized upstream. Mitigation: the migration to `sqlite3mc` stays available and is cheap at the schema/DAO level — the cost is a one-time re-import, which is why this is being decided *now* rather than after T1.5.
- Keeps `sqlcipher_flutter_libs` as a dependency Drift 2.32+ would otherwise let us drop — a small dependency-surface cost, accepted.
- The choice should be revisited if the app ever needs to *read* a database written by a different SQLCipher major version, which would reintroduce the compatibility-pragma question §2.3 raises.

## Alternatives considered

- **Migrate to `sqlite3mc` now, per `docs/blueprint/local-storage-architecture.md` §2.3's recommendation.** Rejected for sequencing, not merit: it would require re-implementing and re-proving T1.3's fail-closed checks and T1.6's rotation before T1.5 could start, delaying the removal of plaintext depot PII and GPS traces from field devices. Security-severity ordering wins — the open finding is plaintext data at rest, not the choice of cipher library. Remains a valid future ADR.
- **Support both paths behind an abstraction.** Rejected: two cipher integrations means two sets of fail-closed checks, two rotation paths, and two on-disk formats to test and migrate between — real complexity for a choice the app makes exactly once per install.
- **Leave the decision unrecorded (status quo).** Rejected: `docs/skills/engineering-standard.md` §11 requires architecturally significant decisions to be ADRs, and an undocumented cipher choice is precisely the kind of thing the next engineer would "fix" without knowing the fail-closed guarantees depend on it.
