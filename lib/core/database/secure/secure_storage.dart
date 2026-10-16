// Secure-storage wrapper — TRACKED INFRASTRUCTURE, NOT DEAD CODE.
//
// Planned: `docs/blueprint/migration-plan.md` §8 (Sprint-1-adjacent backlog) — P1, 3 pts.
//   AC: one API surface for tokens *and* the device key; no feature calls
//   `flutter_secure_storage` directly.
//
// Scope note — this is NOT a duplicate of `dynamic_key_store.dart` in this same
// directory. `DynamicKeyStore` owns the 256-bit device key only (T1.1). This
// wrapper is the single façade over `flutter_secure_storage` for *both* the
// device key and auth tokens, so that `AuthLocalDataSourceImpl` (which today
// injects `FlutterSecureStorage` directly) depends on one owned API surface
// instead of the package.
//
// Intentionally empty: per `docs/skills/engineering-standard.md` §2, no production code
// is written for a module until that module's plan and dependencies are
// validated and approved. This file marks the planned home so the stub is not
// mistaken for an unneeded feature (`.claude/CLAUDE.md`, playbook §12).
//
// Renamed from the historical typo `secure_strorage.dart`
// (`docs/skills/engineering-standard.md` §9).
