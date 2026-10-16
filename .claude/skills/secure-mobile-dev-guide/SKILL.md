---
name: secure-mobile-dev-guide
description: Flutter-first secure implementation guidance for ISI Steel Sales Mobile, mapped to OWASP MASVS v2 and MASTG. Use when implementing or reviewing anything touching tokens, storage, crypto, networking, deep links, permissions, logging, or release hardening, or when asked "how do I do X securely". Defers to the project's ADRs and blueprint, which override generic advice.
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Secure mobile development — Flutter, this project

Topic: `$ARGUMENTS`

## 0. Precedence — read first

This project has **locked** security decisions. Generic best practice never
overrides them:

1. `.claude/rules/security.md` — non-negotiable rules.
2. `docs/skills/security.md` — OWASP/MASVS mapping and release checklist.
3. `docs/blueprint/local-storage-architecture.md` §2 — the composite
   device-bound key scheme. **Never propose a different key derivation,
   cipher, or storage format.** Database cipher is `sqlcipher_flutter_libs`
   (ADR-008).
4. `docs/adr/` — locked decisions.

Before answering, read the relevant one. If generic guidance below conflicts
with them, the project document wins and you say so. If the code diverges from
them, that is a finding.

## 1. How to answer

1. **Current state** — find what the repo already does (`graphify query`,
   then the files). Never advise from assumption.
2. **Guidance** — the MASVS control, then the Dart/Flutter implementation
   using packages already in `pubspec.yaml`. Native Kotlin/Swift only when the
   fix genuinely lives in native config (manifest, `Info.plist`, network
   security config, platform channel).
3. **Common mistakes** — with the MASTG test ID where one applies.
4. **Verification** — how to prove it: a unit/negative test, a manual check,
   or a release-build inspection. Security tests need negative paths
   (`.claude/rules/testing.md`).

Keep it proportionate: answer the question asked, not all nine sections.

## 2. Reference by MASVS area

**STORAGE-1/2** — Tokens, cached user, device key → `flutter_secure_storage`
only (Keychain with an `afterFirstUnlock`-class accessibility; Android
Keystore-backed). Business data and PII → encrypted Drift. Hive → non-sensitive
prefs only. Never `SharedPreferences` for anything sensitive. Exclude sensitive
data from Android auto-backup and iCloud backup deliberately. No PII in logs
(`security.md` §3). Disable autocorrect/suggestions on secret fields
(`autocorrect: false`, `enableSuggestions: false`).

**CRYPTO-1/2** — Use the project scheme; do not design crypto. Randomness from
`Random.secure()` only. No hardcoded keys, salts, or IVs in Dart — Envied
obfuscation is not secrecy. Key rotation and versioning follow the blueprint.

**AUTH-1/2/3** — All token handling through `lib/features/authentication/` and
`lib/core/session/`. Short-lived access token, refresh with rotation, one
in-flight refresh shared by concurrent 401s (no refresh stampede). On sign-out
or refresh failure: clear secure storage and reset rep-scoped state through
`SessionResetService`. Biometrics (`local_auth`) unlock a key in secure
storage; a biometric boolean alone is not authentication.

**NETWORK-1/2** — HTTPS only through the one `dio` client. Android: no
cleartext (`usesCleartextTraffic="false"` / network security config). iOS: no
`NSAllowsArbitraryLoads`. Never override `badCertificateCallback` to return
`true` — not even "temporarily for UAT". Certificate pinning is a trade-off
(rotation can brick installed apps); propose it with backup pins and a rotation
plan, never add it silently.

**PLATFORM-1/2/3** — Deep links, notification payloads, intents: validate per
`security.md` §6. Android components `exported="false"` unless intended;
`PendingIntent.FLAG_IMMUTABLE`. Hide sensitive screens from the app switcher
and screenshots where the business requires it. WebViews: JavaScript off unless
needed; never load untrusted content with a JS bridge.

**CODE-1..4** — Validate input client-side for UX and assume the server
re-validates. Drift's generated queries are parameterised — never build SQL by
string concatenation in `customSelect`. Sanitise filenames and guard path
traversal in file and PDF code. Dependencies per `rules/dependencies.md`.

**RESILIENCE-1..4** — Release builds with `--obfuscate --split-debug-info`.
Root/jailbreak detection and integrity checks (Play Integrity, App Attest) are
product decisions with false-positive cost — present the trade-off; do not add
them unprompted.

**PRIVACY-1..4** — Request permissions just-in-time with a rationale, and only
the ones a feature uses. GPS at the coarsest accuracy that works, only while
needed. Minimise data sent to third-party SDKs. Keep the App Store privacy
manifest and Play data-safety form in sync with reality.

## 3. Never

Weaken validation to make a test or a UAT environment pass · log a token or
payload "just for debugging" · store a secret in the app that only the server
should hold · ship a debug bypass without `// TODO(release-gate):`.
