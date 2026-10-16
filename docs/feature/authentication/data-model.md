# Authentication — Database & Storage Documentation

> Generated 2026-07-23. Authentication is deliberately **database-free**: it owns no Drift tables, no Hive boxes, and no sync-queue rows. Its entire persistence surface is three `flutter_secure_storage` entries.

---

## 1. Drift tables

**None.** The auth feature does not read or write the encrypted Drift database (`isi_secure.db`). This is by design (`docs/skills/security.md` §3: secrets go only in secure storage; business data only in the encrypted DB — a session is a secret, not business data).

Related-but-not-owned: `SecureStorageKeys.kDbDeviceKey` / `kDbDeviceKeyVersion` (secure-storage keys for the database's composite encryption key) live beside the auth keys in `app_constant.dart` but belong to `core/database/secure/` (`docs/blueprint/local-storage-architecture.md` §2).

## 2. Hive boxes

**None owned.** `onboarding_complete` (Hive `AppPreferences`) gates the splash→language-selection routing that surrounds the auth boot check, but is owned by splash/onboarding. It is non-sensitive and defaults safely to `false`.

## 3. Secure storage (the actual store)

Backed by iOS Keychain / Android Keystore via `flutter_secure_storage`.

| Key | Type | Content | Lifecycle |
|---|---|---|---|
| `isi.access_token` | String | Access token | Written on login + every refresh; deleted on logout and on failed refresh |
| `isi.refresh_token` | String | Refresh token | Written on login; rotated on refresh when the server returns a new one; deleted with the above |
| `isi.cached_user` | String (JSON) | `UserModel.toMap()`: `id`, `email`, `full_name`, `roles[]`, `company`, `avatar_url` | Written on login; deleted on logout/failed refresh. **Not** updated by token refresh |

Write atomicity: `cacheSession` writes all three via `Future.wait` — not transactional; a mid-write crash could leave a partial session. Mitigated at read time: boot requires **both** user and token to be present, and any decode error yields `null` → Guest (fail-safe, never fail-open into a broken session).

## 4. Relationships

Logical only (no schema): `isi.cached_user` and the token pair together form one session. `SessionManager` holds the in-memory projection of `isi.cached_user`; it is rebuilt on every boot and never persisted separately.

## 5. Indexes

Not applicable (key-value secure storage).

## 6. Foreign keys

Not applicable. Forward-looking note: `User.id` will become the scoping key for per-user data (e.g. the `WorkflowSession.userId` gap in `docs/blueprint/offline-architecture.md` §3.2) — auth is the source of that identifier.

## 7. Cache

The session cache **is** the offline-boot mechanism (see [API.md](api.md) §8). Reads on boot: 2–3 secure-storage gets, no network. There is no TTL — a cached session is trusted until a refresh fails or the user logs out.

## 8. Retention policy

- Session data is retained indefinitely while the user remains signed in (field reality: reps may be offline for days; an aggressive client-side expiry would strand them). Effective session lifetime is server-controlled via refresh-token validity.
- No historical data (no login history, no audit trail) is stored on-device by this feature.

## 9. Cleanup policy

| Trigger | What is cleared | Code path |
|---|---|---|
| Logout | All three keys | `AuthLocalDataSourceImpl.clear()` via `LogoutRequested` |
| Failed token refresh | All three keys | `AuthInterceptor` → `TokenStore.clear()` (same method) |
| App uninstall | OS-dependent: Android Keystore entries removed; iOS Keychain entries **may persist across reinstall** | Platform behavior — flagged for QA (see [QA_Test_Plan.md](testing.md) SEC cases) |

⚠ Gap: nothing clears **other features'** per-user local data on logout (the encrypted DB keeps prior business data). Multi-user-per-device hygiene is an open item tracked in `docs/blueprint/offline-architecture.md` §3.2 ("clear on logout") and [Roadmap.md](roadmap.md).
