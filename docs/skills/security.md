# Security Standards

> ISI Steel Sales Mobile — Offline-First Enterprise CRM (Flutter)
> Security architecture, implementation standards, and development guidelines. Implements `docs/skills/engineering-standard.md`; encryption implementation detail lives in `docs/blueprint/local-storage-architecture.md`; release-pipeline security gates reference `docs/blueprint/migration-plan.md`'s DevOps section.

This app handles depot information, sales leads, opportunity data, revenue, offline data, business documents, authentication, and user sessions. Because it is offline-first, meaningful volumes of sensitive data sit on the device between syncs — security is a core architectural concern here, not an add-on.

This project follows the **OWASP Mobile Application Security Testing Guide (MASTG)**, the **OWASP MASVS** (Mobile Application Security Verification Standard), and the **OWASP API Security Top 10**. MASVS organizes controls into eight categories — `STORAGE`, `CRYPTO`, `AUTH`, `NETWORK`, `PLATFORM`, `CODE`, `RESILIENCE`, `PRIVACY` — and this document is structured to map cleanly onto them. ([OWASP MAS](https://mas.owasp.org/))

---

## 1. Security goals

Protect depot information and company business data; prevent unauthorized access; secure offline storage; secure API communication; detect tampering; resist reverse engineering; protect authentication tokens; secure application releases.

---

## 2. Security architecture

Security logic lives inside `core/security/` and is never duplicated per feature:

```
lib/
  core/
    security/
      authentication/
      encryption/
      network/
      session/
      storage/
      device/
      logging/
      monitoring/
  features/<domain>/{data,domain,presentation}
```

Any feature that needs a security capability (token access, encrypted storage, session state) calls into `core/security/`; it never re-implements it. This is the same "hollow core, well-behaved features" gap noted throughout `docs/blueprint/system-architecture.md` — the good architectural intent exists, the implementation mostly doesn't yet.

---

## 3. Storage rules (MASVS-STORAGE)

Sensitive information is **never** stored as plain text, and never in:

- `SharedPreferences`
- Hive (unencrypted)
- SQLite/Drift (unencrypted)

Never store passwords, access tokens, or refresh tokens in any of the above. The four-layer persistence matrix in `docs/blueprint/system-architecture.md` §3 is the enforcement mechanism: secrets go only in `flutter_secure_storage` (hardware-backed Keychain/Keystore), and business data goes only in the encrypted Drift database (`docs/blueprint/local-storage-architecture.md`).

Must use encrypted storage: access token, refresh token, user session, API credentials, encryption keys.

Offline-specific data requiring protection (this app's core feature is offline capture, so this list is not optional): depots, leads, opportunities, revenue, orders, draft forms, visit reports, attachments. Requirements: local database encryption, file encryption, cache protection, queue protection (the sync queue itself carries business data and is encrypted as part of the same Drift database), secure synchronization (HTTPS + authenticated requests — §6).

---

## 4. Encryption (MASVS-CRYPTO)

Full detail is in `docs/blueprint/local-storage-architecture.md` §2. Summary of the standard:

- The local database is encrypted at rest using a composite key: `SHA256(Env.dbSalt + DeviceKey)`, where `Env.dbSalt` is compile-time obfuscated via **Envied** and `DeviceKey` is a 256-bit CSPRNG value hardware-sealed via `DynamicKeyStore` (Keychain/Keystore). Neither half alone is sufficient to derive the database key.
- **Envied obfuscation is defense-in-depth, not a secret store.** A determined attacker can recover an obfuscated compile-time constant from a binary; `Env.dbSalt` is safe only because it is combined with a value that never leaves the device's hardware-backed keystore. Never treat the salt as sufficient protection on its own, and document this rationale wherever the key derivation is implemented so a future engineer doesn't "simplify" it into a single static key.
- `.env.*` files are git-ignored; real values live only in CI secrets (§9).
- Never implement custom cryptographic primitives. Use well-established, maintained libraries only (the cipher library chosen in `docs/blueprint/local-storage-architecture.md` §2.3, platform Keychain/Keystore APIs, standard TLS).
- Encrypt: local database, cache, attachments, export files, offline sync queue.
- Key rotation: a re-key routine must exist (`docs/blueprint/local-storage-architecture.md` §6) — a key is never treated as permanent.

---

## 5. Authentication (MASVS-AUTH)

Requirements: JWT authentication, refresh tokens, secure token storage, automatic token refresh, automatic logout, session expiration, correct handling of unauthorized (401) responses.

```
Login → Access Token → API Request → 401 → Refresh Token → Retry Request
```

- The refresh flow (401 → refresh → retry) is designed and largely built (`docs/blueprint/offline-architecture.md` §2), but architecture review flagged that the interceptor implementing it (`app_middleware.dart`) showed as deleted in git history — **verify it still exists and still performs a single-flight refresh** (i.e., concurrent 401s trigger exactly one refresh call, not a stampede) before relying on it.
- Guest-first browsing (`docs/blueprint/offline-architecture.md` §2) is a deliberate product decision, not a security gap: unauthenticated users can browse cached/public data, and `AuthGuard` (`docs/blueprint/offline-architecture.md` §2.4) is the single enforcement point for anything that actually requires a session. Never inline a second `isAuthenticated` check elsewhere.
- **Biometric re-authentication** (`local_auth`, on app resume) is a planned but unbuilt control — tracked as P1 in `docs/blueprint/migration-plan.md` Phase 8.
- **Device registration/binding** is unbuilt — needed for remote revocation (e.g., a lost or terminated-employee device) and is a P1 gap.

---

## 6. Network security (MASVS-NETWORK)

Every request must: use HTTPS, validate certificates, include authentication, be checked for authorization server-side, refresh expired tokens transparently, and reject invalid/malformed responses rather than trusting them.

- **TLS 1.2+** only; no fallback to weaker protocols.
- **Timeout handling** and a defined **retry policy** on every network call — indefinite hangs and unbounded retries are both explicitly disallowed.
- **Certificate pinning** (Dio SPKI pinning) is planned but **not yet implemented** — P1, `docs/blueprint/migration-plan.md` Phase 8. Until it lands, standard OS certificate validation is the only protection against a malicious CA/MITM, which is an accepted gap for pre-GA builds but must close before production release.
- **SAP integration auth** is currently entirely mocked (`core/network/sap_client.dart` is an empty stub). The real auth model (service account + token exchange) must be contract-first with the SAP team before this ships — see `docs/blueprint/migration-plan.md` risk register.

---

## 7. Session management

Auto-login (from cached session, offline-capable — `docs/blueprint/offline-architecture.md` §2.5), auto-logout, session timeout, token refresh, and idle timeout are all requirements. Idle timeout specifically is not yet implemented and should be added alongside biometric re-auth (§5) since they solve related problems: an unattended, unlocked device with a live session.

---

## 8. Device security (MASVS-PLATFORM / MASVS-RESILIENCE)

The app should be able to detect: debug mode, running on an emulator, a rooted (Android) or jailbroken (iOS) device, and optionally developer mode. **None of this is implemented today** — it is explicitly a "future/Phase 8" control, not a current gap in an otherwise-complete list. The response to a detected condition (block, warn, degrade functionality) is a business decision to make when this is built, not purely a technical one — a rooted device might still be a legitimate field rep's personal device in some deployments.

---

## 9. Secret management

Never commit: API keys, Firebase keys, JWT secrets, passwords, certificates, private keys. Use environment variables, secret managers, and CI/CD secrets instead — concretely: GitHub Secrets and Fastlane Match for signing material, `.env.*` files that are git-ignored and populated only in CI, and Envied for compile-time obfuscation of what does need to ship inside the binary (§4).

---

## 10. Secure logging (MASVS-PRIVACY / MASVS-CODE)

**Never log**: passwords, JWT tokens, API keys, depot information, phone numbers, emails, revenue data.

**Allowed**: API endpoint, response code, error code, exception stack traces (development builds only — stripped from release, §11).

This is a hard constraint on every `catch` block and every logging call in the codebase, not just a guideline for a dedicated logging module — see `docs/skills/engineering-standard.md` §7 on error handling. Structured logging with no PII, plus a dedicated `audit_log` table (`docs/blueprint/local-storage-architecture.md` §3.2) for sensitive actions (login, logout, order submission, DLQ manual retry/discard — `docs/blueprint/sync-architecture.md` §6), is a P0 gap: crash reporting and structured, PII-free logging are effectively absent today, which means field crashes are currently invisible to the team.

---

## 11. Binary protection and release checklist

Release builds must include: R8/ProGuard (Android), code obfuscation (`--split-debug-info`/Dart obfuscation), debug disabled, verbose logging disabled, mock APIs and mock data removed.

**Before every release**, verify:

- [ ] Debug mode disabled
- [ ] Logging removed/reduced to §10's allowed set
- [ ] Mock data and mock APIs removed (including the SAP mock adapter — swappable, but must not ship active in production builds, §6)
- [ ] API URLs verified for the target environment
- [ ] Release signing enabled
- [ ] Obfuscation enabled
- [ ] Security tests passed (§13)
- [ ] Debug-only shims stripped — specifically including any `kDebugForceInsideGeofence`-style geofence bypass and any overly permissive fraud policy shim used in development; these are named, tracked risks (`docs/blueprint/migration-plan.md` risk register) precisely because "empty core stubs / dev shims" have historically been mistaken for "done"
- [ ] No plaintext database file exists on disk
- [ ] Encryption verified end-to-end (wrong key fails to open the DB)
- [ ] Migration tested on an upgrade path, not just a fresh install

This checklist is enforced by CI grep/lint for tagged shortcuts (`docs/skills/engineering-standard.md` §11) wherever automatable, not left to manual review alone.

---

## 12. CI/CD security gates

The pipeline (full detail in the CI/CD guide referenced by `docs/blueprint/migration-plan.md`'s DevOps section) includes: static analysis, dependency scanning, secret scanning, unit tests, integration tests, build verification. Optional/recommended additions: MobSF (mobile-specific static/dynamic analysis), Trivy (dependency/container vulnerability scanning), Gitleaks (secret scanning). No pull request merges if any required check fails, and no release build proceeds if a secret-scan or dependency-scan finding is open.

---

## 13. Security testing

Test areas required before release, and periodically thereafter: authentication, authorization, offline storage, API security, local database, file storage, network requests, session management, resistance to reverse engineering, tampering resistance, root/jailbreak detection.

---

## 14. Dependency security

Every dependency must be actively maintained, trusted, kept up to date, and free of known vulnerabilities at time of adoption and on an ongoing basis (dependency scan in CI, §12). New dependencies are reviewed before introduction, not merged opportunistically.

---

## 15. Security principles

Security by design · least privilege · defense in depth · secure by default · fail securely · zero trust · principle of least knowledge. These are the lens every design decision in `docs/blueprint/system-architecture.md`, `docs/blueprint/local-storage-architecture.md`, and `docs/blueprint/sync-architecture.md` is reviewed against — e.g., "server-authoritative conflict resolution" (`docs/blueprint/sync-architecture.md` §5) is a zero-trust/fail-securely decision as much as a data-integrity one.

---

## 16. Developer responsibilities

Every developer is responsible for: writing secure code, protecting sensitive data, avoiding hardcoded secrets, following secure coding guidelines, reviewing new dependencies, participating in security testing, and updating vulnerable packages promptly. Security is a shared responsibility across the whole development lifecycle, not a gate owned solely by one reviewer at the end.

---

## 17. Future improvements (tracked, not yet built)

Certificate pinning, Runtime Application Self-Protection (RASP), device attestation, biometric authentication, jailbreak/root detection, anti-tampering, anti-debugging, threat monitoring, security analytics. See `docs/blueprint/migration-plan.md` Phase 8 for sequencing.

---

## 18. Suggested security documentation set (fast-follow)

For teams that want this security standard broken into per-topic reference docs as the program matures:

```
docs/security/
├── README.md                # Overview (this document's summary)
├── 01-authentication.md
├── 02-secure-storage.md
├── 03-network-security.md
├── 04-offline-security.md
├── 05-encryption.md
├── 06-session-management.md
├── 07-device-security.md
├── 08-api-security.md
├── 09-release-checklist.md
├── 10-security-testing.md
├── SECURITY_CHECKLIST.md
├── THREAT_MODEL.md
└── SECURITY_AUDIT.md
```

---

## 19. Related documents

- Encryption implementation detail: `docs/blueprint/local-storage-architecture.md` §2
- Guest-first auth flow this section's requirements apply to: `docs/blueprint/offline-architecture.md` §2
- Sequencing of security work relative to feature work: `docs/blueprint/migration-plan.md`
- Coding-level error handling and logging rules: `docs/skills/engineering-standard.md` §7

Sources: [OWASP Mobile Application Security (MAS)](https://mas.owasp.org/), [OWASP MASTG](https://mas.owasp.org/MASTG/), [OWASP MASVS](https://mas.owasp.org/MASVS/).

Version: 1.0 · Status: Enterprise Security Standard · Maintained by: Mobile Engineering Team.
