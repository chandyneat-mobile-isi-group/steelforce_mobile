# SteelForce Mobile — Security Overview

> What protects this app today, what each protection defends against, and what
> is still missing.
>
> **Last reviewed:** 2026-10-24 · branch `feat/auth`
>
> **New to security?** Start with [explained.md](explained.md),
> a plain-language guide with diagrams and a glossary.
>
> This page describes the app's **current state**. The engineering rules every
> change must follow live in [`docs/skills/security.md`](../skills/security.md)
> (OWASP MASVS mapping). Where the two disagree, the code is the truth and this
> page needs updating.

---

## 1. At a glance

| Attack | Status | Main defence |
|---|---|---|
| Stolen or lost phone: reading the data | ✅ Strong | SQLCipher database, key bound to the device ([§3](#3-data-on-the-device)) |
| Copying data off via a backup or a new-phone transfer | ✅ Strong | Backups disabled; device-only Keychain; Android 12+ transfer blocked ([§3](#3-data-on-the-device)) |
| Eavesdropping on the network (public Wi-Fi) | ✅ Strong | TLS only; release builds refuse `http://` ([§4](#4-network)) |
| Intercepting traffic with Burp or mitmproxy | ⚠️ Partial | Android ignores user-installed CAs. **Certificate pinning is built but off until CA certificates are added** ([§4.4](#44-certificate-pinning)) |
| Reverse engineering the app | ⚠️ Partial | R8 + Dart obfuscation via `tool/build_release.sh`; no secrets in the binary ([§5](#5-reverse-engineering)) |
| Tampering, repackaging, hooking (Frida), rooted or jailbroken phones | ❌ Gap | Nothing detects them yet ([§6](#6-app-integrity-and-tampering)) |
| Scripting the API outside the app | ❌ Gap | App Check protects Firebase only, **not** the SteelForce API ([§8](#8-api-protection)) |
| Faking a visit location | ✅ Good | Release builds always block mock GPS; accuracy and speed checks ([§10](#10-anti-fraud)) |
| Secrets or PII leaking into logs | ✅ Strong | Redacting logger; no bodies logged in release ([§9](#9-logging-and-privacy)) |
| Token theft and replay | ✅ Good | Secure storage, single-use rotating refresh tokens, device id ([§7](#7-authentication-and-session)) |

✅ in place · ⚠️ partly in place, or needs one more step · ❌ not yet built

---

## 2. Threat model

| Who | What they want | Where they attack |
|---|---|---|
| Someone holding a **lost or stolen phone** | Customer list, prices, orders | Files on the device, backups |
| A **curious or dishonest user** (sometimes a rep) | Fake visits, change prices or discounts, see other reps' data | GPS spoofing, editing requests, calling the API directly |
| A **competitor or reverse engineer** | Pricing logic, API surface, endpoints | Decompiling the APK or IPA |
| An **attacker on the network** | Tokens, credentials | Public Wi-Fi, malicious proxies |
| An **automated attacker** | Account takeover, data scraping | Brute-forcing login, scripted API calls |

Rule of thumb: **anything shipped inside the app is public.** The app can make
attacks slower and more expensive. Only the **backend** can make them fail.

---

## 3. Data on the device

| Data | Where it lives | Protection | Code |
|---|---|---|---|
| Business data (depots, routes, visits, orders, catalogue) | Drift database | **SQLCipher** (AES-256). Key = `sha256(salt + 256-bit random device key)`; re-keying supported | [`app_database_key_provider.dart`](../../lib/core/database/secure/app_database_key_provider.dart), [`key_derivation.dart`](../../lib/core/database/secure/key_derivation.dart), [`dynamic_key_store.dart`](../../lib/core/database/secure/dynamic_key_store.dart) |
| Access and refresh tokens, cached user, device id, the database device key | `flutter_secure_storage` | Android Keystore (`encryptedSharedPreferences`); iOS Keychain, **`first_unlock_this_device`** | [`app_secure_storage.dart`](../../lib/core/database/secure/app_secure_storage.dart) |
| Session data in Hive | Hive `kic_secure_box` | AES-256 (key kept in secure storage) | [`hive_service.dart`](../../lib/core/database/hive/hive_service.dart) |
| Non-sensitive preferences (theme, flags) | Hive `kic_cache_box` | None needed | — |

**Backups and phone-to-phone transfer**

- Android: `android:allowBackup="false"`. On Android 12+ that flag no longer
  stops device-to-device transfer, so
  [`data_extraction_rules.xml`](../../android/app/src/main/res/xml/data_extraction_rules.xml)
  excludes every domain from cloud backup **and** device transfer.
- iOS: all Keychain items are **ThisDeviceOnly**, so tokens and the database
  key never go into an iCloud or encrypted backup, or through Quick Start.
  Items written before this change are moved over once, at startup, by a
  crash-safe migration
  ([`keychain_accessibility_migration.dart`](../../lib/core/database/secure/keychain_accessibility_migration.dart)).

**What happens on a new phone:** the rep signs in and data syncs from the server.
Anything not yet synced on the old phone stays on the old phone. That is
intended.

---

## 4. Network

### 4.1 TLS everywhere

- Release builds **refuse to start** if the API URL is `http://`
  (`AppConfig.validateApiUrl`). Debug builds still allow `http://` for a LAN
  backend.
- iOS App Transport Security is on. Only `NSAllowsLocalNetworking` is relaxed.

### 4.2 Android network security config

[`network_security_config.xml`](../../android/app/src/main/res/xml/network_security_config.xml)
(release and profile builds):

- no cleartext HTTP to any host, including from plugins and WebViews;
- **system CAs only**: a user-installed CA, the first step of intercepting the
  app with Burp, is not trusted.

Debug builds swap in a permissive
[`debug` copy](../../android/app/src/debug/res/xml/network_security_config.xml), so a
LAN backend and a debugging proxy keep working.

### 4.3 Rejected certificates are named

When TLS verification fails, the logger records the certificate's subject and
issuer. The certificate is still rejected. Example: on 2026-10-19 this showed
that an office FortiGate DNS filter was answering for the API host.
[`tls_rejection_report.dart`](../../lib/core/network/transport/tls_rejection_report.dart)

### 4.4 Certificate pinning

**Built, tested, and OFF until CA certificates are added.**

- Pinning **anchors trust in the TLS handshake**: only certificate chains that
  end at the CAs listed in
  [`api_trust_anchors.dart`](../../lib/core/network/transport/api_trust_anchors.dart)
  connect. The platform root store is not used.
- **Why not dio's `validateCertificate`?** It runs *after* the request has
  been sent, so the bearer token would already be with the attacker. With
  handshake anchoring, an intercepting proxy receives nothing. A test proves
  this: the server sees **zero** requests.
- **Turning it on:** paste the PEM of the API's root CA **plus a backup root**
  into `apiTrustAnchorsPem`. A test then requires at least two anchors.
  Instructions are in the file.
- **Scope:** only API clients built by `AppNetwork`. Map tiles, images and the
  reachability probe use the normal trust store.
- **Risk to know:** if the API moves to a CA that isn't listed, every installed
  app stops reaching the API until it is updated. Always ship a backup anchor,
  and plan a CA change one app release ahead.

---

## 5. Reverse engineering

| Protection | Status | Details |
|---|---|---|
| Dart obfuscation | ✅ | `tool/build_release.sh <apk\|appbundle\|ipa>` builds with `--obfuscate --split-debug-info`. Symbols go to `build/symbols/<target>/<version>/` |
| Java/Kotlin shrinking and obfuscation | ✅ | R8 `isMinifyEnabled` + `isShrinkResources` ([`build.gradle.kts`](../../android/app/build.gradle.kts), [`proguard-rules.pro`](../../android/app/proguard-rules.pro)) |
| No secrets in the binary | ✅ | API URLs and the DB salt are Envied-obfuscated. They are **not secrets**: the salt alone cannot open the database without the device-bound key |
| Native log stripping | ✅ | R8 removes `Log.d/v/i` |
| Commercial obfuscator (DexGuard, iXGuard) | ❌ | Optional; only if the threat justifies the cost |

> ⚠️ **Archive the symbol folder privately for every release.** It is the only
> way to read an obfuscated crash stack
> (`flutter symbolize -i stack.txt -d build/symbols/...`), and it maps every
> obfuscated name back to the source. Never upload it anywhere public.

> ⚠️ **Never build a release with a bare `flutter build … --release`.** It
> skips Dart obfuscation.

---

## 6. App integrity and tampering

| Protection | Status | Details |
|---|---|---|
| Firebase App Check: Android | ✅ | reCAPTCHA Enterprise provider in release; debug provider in debug ([`firebase_app_check.dart`](../../lib/core/firebase/firebase_app_check.dart)) |
| Firebase App Check: iOS | ✅ | App Attest with DeviceCheck fallback. The **App Attest entitlement** is now in [`Runner.entitlements`](../../ios/Runner/Runner.entitlements) |
| Release-signing guard | ✅ | Gradle refuses to build a release signed with the debug key |
| Root / jailbreak detection | ❌ | — |
| Hooking (Frida) and debugger detection | ❌ | — |
| Repackaging / re-signing detection | ❌ | — |

**App Attest signing note:** automatic signing (this project's setting) adds the
capability to the App ID on the next Xcode build. A manually managed
provisioning profile must be regenerated with **App Attest** enabled, or
signing fails.

**Plan for the ❌ rows:** see [§12](#12-remaining-work).

---

## 7. Authentication and session

- Tokens live only in secure storage ([§3](#3-data-on-the-device)), never in
  Hive, preferences or logs.
- **Refresh is reactive** (only after a 401) and **single-flight**. Concurrent
  401s share one refresh, so the server's reuse detection never mistakes the
  app for a thief.
  ([`auth_interceptor.dart`](../../lib/core/network/interceptors/auth_interceptor.dart))
- The refresh token **rotates** on every use and is sent with the `deviceId`
  given at sign-in.
- Only a definitive rejection (400/401 from the refresh endpoint) ends the
  session. Being offline never signs a rep out.
- A 403 is treated as "not allowed", not as "signed out".
- Sign-out clears tokens and rep-scoped state through `SessionResetService`.
- Password reset proves phone ownership with Firebase Phone Auth; the backend
  still authorises the reset.

---

## 8. API protection

Most of this is **backend work**. The app cannot enforce it.

| Control | Owner | Status |
|---|---|---|
| Authorisation on every object, so a rep only sees their own depots and orders (prevents IDOR) | Backend | ❓ Confirm |
| Rate limiting and lockout on login, refresh and password reset | Backend | ❓ Confirm (the API docs mention a 5-attempt lockout) |
| Server-side recalculation of prices, discounts and totals | Backend | ❓ Confirm |
| Refresh-token reuse detection and device binding | Backend | ❓ Confirm |
| Idempotency keys and replay protection on writes | Backend | ❓ Confirm |
| **App attestation on the SteelForce API** | App + Backend | ❌ Not built. App Check tokens are sent to Firebase only |

**Why the last row matters:** today anyone with valid credentials can call the
API from Postman or a modified app. Fixing it needs both sides to agree on a
header contract (for example `X-Firebase-AppCheck` with a limited-use token on
login, refresh, order submit and check-in) and the backend to verify it. Each
token costs a reCAPTCHA Enterprise assessment on Android, so the endpoint list
also needs a budget decision.

---

## 9. Logging and privacy

- Structured logger with a **redactor** that masks by key name *and* by value
  shape (JWTs, phone numbers and the like).
  ([`app_logger.dart`](../../lib/core/logging/app_logger.dart))
- Request and response **bodies are never logged in release**, even with
  `API_LOG_BODIES=true`.
  ([`api_log_interceptor.dart`](../../lib/core/network/interceptors/api_log_interceptor.dart))
- Query parameters log keys only, never values.
- Notification payloads are never logged in release (`.claude/rules/firebase.md`).

---

## 10. Anti-fraud

[`fraud_policy.dart`](../../lib/features/my_visits/domain/entities/fraud_policy.dart)

- **Mock GPS locations are always blocked in release builds.** Debug builds
  tolerate them because emulators always report mocked GPS.
- Checks accuracy (≤ 50 m) and speed (≤ 150 km/h).
- A VPN probe exists; blocking on VPN is off by default.
- A check-in override needs a written reason.

These checks run on the device, so a tampered app can bypass them. The backend
should re-check location plausibility from the data it receives.

---

## 11. Platform hardening

| Item | Status |
|---|---|
| Least-privilege permissions: background location and broad media access removed | ✅ |
| Deep links (`app://…`): resolved through an **allowlist**, navigation only, never an action | ✅ [`notification_deep_link.dart`](../../lib/core/notifications/notification_deep_link.dart) |
| Secrets gitignored: `.env`, `env.g.dart`, `google-services.json`, `GoogleService-Info.plist`, `key.properties`, `Env.xcconfig` | ✅ |
| Google Maps key injected at build time, not committed | ✅ |
| Screenshot / screen-recording protection | ❌ Needs a product decision ([§12](#12-remaining-work)) |
| Web: Content-Security-Policy | ❌ |

---

## 12. Remaining work

Ordered by impact. **Owner** says who has to act.

| # | Item | Owner | What is needed before it can be built |
|---|---|---|---|
| 1 | **App attestation on the SteelForce API** ([§8](#8-api-protection)) | Backend + App | Header contract, list of protected endpoints, backend verification, reCAPTCHA budget |
| 2 | **Turn on certificate pinning** ([§4.4](#44-certificate-pinning)) | App | The API's root CA and a backup root (PEM). Pasting them in is the whole change |
| 3 | **Rotate exposed values**: `lib/core/config/env.g.dart` (API URLs, `DB_SALT`) was committed once in `4978d40`; an older Google Maps key is also in git history | DevOps | Confirm the Maps key was rotated and restricted to package + SHA-1 (Android) and bundle id (iOS). Changing `DB_SALT` needs a database re-key migration, so treat it as public instead (it is defence-in-depth only) |
| 4 | **Runtime protection (RASP)**: root, jailbreak, Frida, debugger, emulator, repackaging | App | Choose a library (recommended: **freeRASP** by Talsec), the **Play App Signing** certificate SHA-256 (from Play Console, *not* the upload key), the Apple Team ID, a security contact email, and the **response policy**. Recommendation: warn, report to the backend, and block order submit and check-in while browsing stays allowed |
| 5 | **Screenshot protection** on price, customer and order screens (Android `FLAG_SECURE`, iOS app-switcher blur) | Product | Decide which screens; support teams often rely on rep screenshots |
| 6 | **Biometric / PIN app lock** after inactivity (`local_auth`) | Product | Timeout value; whether it is mandatory |
| 7 | **Backend controls** in [§8](#8-api-protection) | Backend | Confirm each ❓ |
| 8 | **Web build**: add a Content-Security-Policy; confirm the GitHub Pages repo (`dydev99.github.io`) is **private** and approved for company code | App + IT | A CSP that still allows CanvasKit, Maps and wasm needs testing on the deployed site |
| 9 | Key derivation: the code uses `sha256(salt + key)`; the blueprint describes a KDF | Architecture | Decide in an ADR. Not urgent, because the device key is 256 random bits |
| 10 | Penetration test (MobSF, Frida/objection, Burp) before production | Security | A staging environment |

---

## 13. Release security checklist

Before every store release:

- [ ] Built with `tool/build_release.sh` (obfuscated), **not** bare `flutter build`
- [ ] `build/symbols/<target>/<version>/` archived privately
- [ ] API URL is `https://` (the app refuses to start otherwise)
- [ ] Signed with the release key (`keytool -printcert -jarfile …` is not `CN=Android Debug`)
- [ ] `flutter test test/core/` passes
- [ ] No `TODO(release-gate)` behaviour reachable in release (`grep -rn "release-gate" lib`)
- [ ] App Check enforcement is on in the Firebase console for Phone Auth
- [ ] If pinning is on: tested against staging **and** production with a release build
- [ ] iOS: provisioning profile includes App Attest and Push

---

## 14. Verifying the protections

```bash
# Unit tests for the protections in this document
flutter test test/core/network/http_transport_test.dart            # pinning, against a real TLS handshake
flutter test test/core/database/secure/                            # keychain migration and DB key handling
flutter test test/core/config/api_url_validation_test.dart         # https-only release

# Hardened release build
tool/build_release.sh apk

# Check an APK for leftovers (needs apktool / jadx)
jadx -d out build/app/outputs/flutter-apk/app-release.apk
```

Manual checks that unit tests cannot make:

- **iOS Keychain migration:** install the previous build, sign in, install this
  build, and confirm the rep stays signed in and offline data is intact.
- **Android network config:** install a user CA plus a proxy on a release build;
  every API call must fail.
- **App Attest:** on a real iPhone release build, the Firebase console shows
  App Attest (not DeviceCheck) tokens.
