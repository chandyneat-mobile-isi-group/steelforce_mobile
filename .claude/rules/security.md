# Security

Authoritative: `docs/skills/security.md` (OWASP/MASVS mapping, release
checklist). The `secure-mobile-dev-guide` skill is available for
implementation-level guidance. These rules are non-negotiable.

---

## 1. Stop and reassess

Pause and re-read the governing document before touching: private keys,
passwords, access/refresh tokens, encryption keys, customer PII, authentication,
authorization, production credentials, database encryption, or sync integrity.
These are Type D changes (`workflow.md` §2).

**Never improvise cryptography or security architecture.** Follow the composite
key-derivation scheme in `docs/blueprint/local-storage-architecture.md` §2 and
established platform primitives only.

---

## 2. Storage

| Data | Only acceptable home |
|---|---|
| Tokens, cached user, device encryption key | `flutter_secure_storage` (Keychain / Keystore) |
| Business data and PII | The encrypted Drift database |
| Non-sensitive prefs (theme, flags) | Hive |

Never put a token, password, or any PII in `SharedPreferences`, Hive, or an
unencrypted database. `docs/skills/security.md` §3.

---

## 3. Logging

**Never log** passwords, tokens, API keys, customer names or contacts, phone
numbers, emails, addresses, GPS traces, revenue or pricing data, or notification
payloads.

**Allowed**: endpoint, HTTP status, error code, and stack traces in **debug
builds only**. `docs/skills/security.md` §10.

---

## 4. Secrets in source

- Never hardcode secrets, API keys, or endpoints. Use Envied-obfuscated config
  (`lib/core/config/`) and CI secrets.
- `.env`, `.env.*`, `ios/Flutter/Env.xcconfig`, and `lib/core/config/env.g.dart`
  are gitignored and must stay that way. `.env.example` is the committed
  template.
- Before adding any config file, check `.gitignore` first.
- Treat every piece of user and customer information as sensitive business data.

---

## 5. Debug shortcuts

Any debug-only shortcut — mock SAP client, geofence bypass, permissive fraud
policy, auth skip — must be tagged:

```dart
// TODO(release-gate): <what this bypasses and what must replace it>
```

and must never ship in a release build. `docs/skills/security.md` §11.

---

## 6. Reviewing your own change

Before reporting, re-read the diff for: a leaked secret, a widened permission, a
new log line carrying PII, a disabled certificate or validation check, a
weakened default. If you added one deliberately, say so in the report.
