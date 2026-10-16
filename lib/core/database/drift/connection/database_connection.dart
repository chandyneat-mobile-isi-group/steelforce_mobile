/// Platform-selected executor for the single application [AppDatabase].
///
/// This file is the **only** thing `AppDatabase` imports. It resolves to one of
/// two implementations at compile time, so neither platform ever sees the
/// other's dependencies:
///
/// | Platform | File | Backing store |
/// |---|---|---|
/// | Android / iOS | `encrypted_database.dart` | SQLCipher on the native filesystem, encrypted at rest (ADR-008) |
/// | Web | `web_database.dart` | `sqlite3.wasm` in memory, **nothing persisted** (ADR-010) |
///
/// ## Why a conditional export rather than a runtime `kIsWeb` branch
///
/// `kIsWeb` is a runtime check, so both branches still have to *compile*. The
/// native path imports `dart:ffi` (via `sqlite3` and `sqlcipher_flutter_libs`),
/// and `dart:ffi` does not exist on web — the compile fails before any runtime
/// check could help. `dart.library.ffi` is therefore the correct discriminator:
/// it is evaluated by the compiler, and the unused branch is never loaded.
///
/// Note the condition tests for **`dart.library.ffi`**, not `dart.library.io`.
/// They are not interchangeable here: what breaks the web build is FFI
/// specifically, and testing the thing that actually breaks keeps the reason
/// legible to the next reader.
///
/// ## Invariant
///
/// Both implementations expose exactly one symbol, [openAppDatabaseConnection],
/// with an identical signature. Everything above this seam — `AppDatabase`,
/// every table, every DAO, every repository — is byte-identical across
/// platforms, which is the whole point of ADR-010's chosen option: one
/// codebase, one schema, one set of DAO tests (run against both executors).
library;

export 'web_database.dart' if (dart.library.ffi) 'encrypted_database.dart';
