import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:steelforce/core/database/secure/app_database_key_provider.dart';
import 'package:sqlite3/wasm.dart';

/// Web counterpart of `encrypted_database.dart`. Selected by the conditional
/// export in `database_connection.dart` — never compiled on Android/iOS.
///
/// ## This database is NOT encrypted, and NOT persisted. Both are deliberate.
///
/// Per **ADR-010**, the web build holds business data in an in-memory
/// `sqlite3.wasm` database that is discarded when the tab closes. Read that ADR
/// before changing anything here; the two properties below are the decision,
/// not an unfinished implementation:
///
/// **No encryption.** `sqlcipher_flutter_libs` publishes no web build, and
/// `sqlite3.wasm` is a vanilla SQLite build with no cipher. There is no way to
/// get SQLCipher's guarantees in a browser today.
///
/// **No persistence.** This is what makes the missing encryption acceptable
/// rather than a `SECURITY.md` §3 violation. Drift *can* persist to
/// OPFS/IndexedDB via `WasmDatabase.open()`, and doing so here would write
/// depot PII, GPS traces, and quotation pricing to storage readable by any
/// script on the origin — reintroducing on web precisely the finding that
/// `MIGRATION_PLAN.md` T1.5 exists to remove from mobile. Encryption at rest is
/// satisfied on web by there being no rest.
///
/// > **Do not "upgrade" this to `WasmDatabase.open()` for offline persistence.**
/// > That is Option C in `docs/blueprint/web-migration-plan.md` §3.2, and it was
/// > rejected: browsers have no hardware-backed keystore, so the key would sit
/// > in the same storage as the data it claims to protect. Changing this needs
/// > an ADR superseding ADR-010, not a patch.
///
/// The consequence users feel: **web offline is session-scoped.** Unsynced work
/// is lost if the tab closes while disconnected, which is why the web shell
/// warns before unload on a non-empty sync queue.
///
/// ## Why the key provider is accepted and ignored
///
/// The signature matches the native one so `AppDatabase` needs no platform
/// branch. [keyProvider] is unused here because there is nothing to key. It is
/// deliberately *not* removed from the signature: a divergent signature would
/// push a `kIsWeb` branch up into `AppDatabase`, which is exactly the coupling
/// this seam exists to prevent.
LazyDatabase openAppDatabaseConnection(AppDatabaseKeyProvider keyProvider) {
  return LazyDatabase(() async {
    // Relative URI on purpose. It resolves against the document's <base href>,
    // so the same build works at the domain root and under a GitHub Pages
    // repository sub-path (`/isi-steel-sales-mobile/sqlite3.wasm`) with no
    // rebuild. Hardcoding a leading slash here is the single most common way to
    // break the sub-path deployment — see `docs/blueprint/web-architecture.md`.
    final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));

    // An in-memory VFS, registered as the default, is what makes "no
    // persistence" structural rather than a convention someone can forget:
    // there is no OPFS or IndexedDB filesystem registered for SQLite to write
    // to, so a stray `WasmDatabase(path: ...)` elsewhere still cannot reach
    // durable storage.
    sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);

    return WasmDatabase.inMemory(sqlite3);
  });
}
