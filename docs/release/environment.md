# Environment Configuration

> **Purpose:** every configuration value this app reads, where it comes from, and
> what breaks when it is wrong.
> **Source:** `.env.example`, `lib/core/config/env.dart`, `tool/generate_ios_env.dart`,
> `.github/workflows/deploy-web.yml`, verified 2026-08-27.
> **No real values appear in this document, and none may be added.**

---

## How configuration reaches the app

```
.env  (git-ignored, one per environment)
  │
  │  dart run build_runner build --delete-conflicting-outputs
  ▼
Envied generator
  │
  ▼
lib/core/config/env.g.dart   ← generated, obfuscated, git-ignored
  │
  ▼
lib/core/config/env.dart     ← the only type-safe accessor: Env.apiBaseUrl, …
  │
  ├──▶ AppConfig / ApiEndpoints          (Dart side)
  └──▶ tool/generate_ios_env.dart ──▶ ios/Flutter/Env.xcconfig   (native iOS side)
```

Two consequences worth internalising:

1. **A missing or misspelled key fails code generation**, not runtime. That is
   the point — the build breaks on your machine instead of the app breaking in a
   depot.
2. **Nothing may be hardcoded.** No endpoint, key, or salt appears in source.
   See [../skills/security.md](../skills/security.md) §9.

---

## Keys consumed by Envied

Both are `obfuscate: true`. The app talks only to its own API, never to SAP
directly, so there is no SAP URL to configure.

| Key | Accessor | Purpose | If wrong |
|---|---|---|---|
| `API_BASE_URL` | `Env.apiBaseUrl` | Root of the ISI API — **scheme and host only**, no trailing slash and no `/api/v1` (`ApiEndpoints.apiPrefix` appends that). Also the target of the [ADR-0005](../adr/ADR-0005-connectivity-service.md) reachability probe | Every request 404s or hits the wrong host, and the app reports offline |
| `DB_SALT` | `Env.dbSalt` | Salt for SQLCipher key derivation, combined with the hardware-sealed device key | **Every existing encrypted database on every device becomes unreadable — including unsynced field captures.** Generate once per environment, then never change it |

`DB_SALT` generation (run once, per environment, and record it in your secret
store — never in the repo):

```bash
python3 -c "import secrets,base64;print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('='))"
```

---

## Keys consumed by the native layers

| Key | Consumed by | Purpose |
|---|---|---|
| `GOOGLE_MAPS_IOS_KEY` | `tool/generate_ios_env.dart` → `ios/Flutter/Env.xcconfig` | The iOS Google Maps SDK, which reads its key natively, not through Dart |

Re-run `dart run tool/generate_ios_env.dart` after any `.env` change, before an
iOS build.

---

## Additional keys the web workflow writes

`deploy-web.yml` generates a **placeholder** `.env` in CI rather than injecting
secrets. That file sets several keys beyond the three above — `APP_NAME`,
`APP_ENV`, `API_TIMEOUT`, `ENABLE_LOGGING`, `ENABLE_DEBUG`,
`GOOGLE_MAPS_ANDROID_KEY`, `GOOGLE_MAPS_IOS_KEY`, `MAP_PROVIDER`,
`AUTH_TOKEN_KEY`.

> **These are not declared in `.env.example` and not read by `Env`.** They are
> either historical or consumed elsewhere. Verify against
> `lib/core/config/env.dart` before treating any of them as live configuration —
> today only `API_BASE_URL` and `DB_SALT` reach Dart through
> Envied. Reconciling `.env.example`, `env.dart`, and the workflow's key list is
> outstanding work.

Web overrides come from the repository **variable** `vars.WEB_API_BASE_URL`,
not a secret, and fall back to a staging host.

---

## Why the web build gets no secrets

A web build is JavaScript. Everything compiled into it is readable by anyone who
opens devtools, so Envied's obfuscation — which defends against *native binary*
inspection — buys nothing there.

`DB_SALT` is therefore never wired into the web job. Per
[ADR-0010](../adr/ADR-0010-web-persistence.md) the web target has no encrypted
database to key, so the value is meaningless as well as unsafe. It is not
"probably tree-shaken"; it was never present.

**Never add `secrets.DB_SALT` to `deploy-web.yml`.** If the web app needs a real
API endpoint, add only that one, as a repository variable.

---

## Rules

1. **`.env` is never committed.** `.env.example` is committed and must never
   contain a real value.
2. **Every key in `.env.example` must be present in a real `.env`** — Envied
   fails generation on a missing key.
3. **`DB_SALT` is stable forever** per environment. Rotating it is a data-loss
   event, not a configuration change. Key *rotation* is a separate, supported
   path — `core/database/secure/database_key_rotator.dart` — and does not involve
   changing the salt.
4. **CI secrets live in GitHub Secrets**, non-sensitive overrides in GitHub
   Variables. Neither belongs in a workflow file literal.
5. **No secret value in `docs/`, ever** — including examples, comments, and
   "obviously fake" placeholders that get copy-pasted.

---

## Related

- [README.md](README.md) — build commands and the release gate
- [../skills/security.md](../skills/security.md) §9 secret management, §4 encryption
- [../blueprint/local-storage-architecture.md](../blueprint/local-storage-architecture.md) §2 — the composite key derivation `DB_SALT` feeds
- [../adr/ADR-0008-sqlcipher-path.md](../adr/ADR-0008-sqlcipher-path.md) — the locked cipher path
