# Release — build, configure, sign, ship

> **Purpose:** how this application is configured, built, signed, and
> distributed.
> **Verified:** 2026-08-27, branch `web` @ `142de9b`, Flutter 3.44.9.
> **Never document a secret here.** No tokens, keys, certificates, passwords, or
> keystores — not even a redacted one.

---

## Documents

| Document | What it covers | Status |
|---|---|---|
| [android-release.md](android-release.md) | Release keystore, local/CI signing, signed AAB, Firebase App Distribution, release notes, future GitLab CI variables | ✅ Describes what exists |
| [environment.md](environment.md) | Envied configuration, every `.env` key, iOS `Env.xcconfig` generation, and the web build's deliberate absence of secrets | ✅ Describes what exists |
| [demo-mode.md](demo-mode.md) | Building and presenting the app with static demo data and no backend (`USE_MOCK_DATA=true`), the online/offline switch, and its limits | ✅ Describes what exists |
| [ci-cd.md](ci-cd.md) | The intended CI/CD pipeline — branch strategy, PR gates, Fastlane, store distribution | ⚠ **Largely aspirational** — see below |

---

## What is actually automated today

One workflow: [`.github/workflows/deploy-web.yml`](../../.github/workflows/deploy-web.yml).

```
push to `web`  (or manual workflow_dispatch)
      │
      ▼
checkout ─▶ flutter-action, pinned to 3.44.4 ─▶ write placeholder .env
      │                                              (no real secrets)
      ▼
flutter build web --release --base-href /isi-steel-sales-mobile/
      │
      ▼
GitHub Pages ─▶ https://dydev99.github.io/isi-steel-sales-mobile/
```

Two deliberate choices worth preserving:

- **The Flutter version is pinned** (`3.44.4`), not floating on `stable`. An
  upstream release must not be able to break a deploy with no change on our side.
- **The web job is never given real secrets.** A web build is JavaScript;
  everything compiled in is readable in devtools, so Envied obfuscation buys
  nothing. `DB_SALT` in particular is meaningless there — per
  [../adr/ADR-0010-web-persistence.md](../adr/ADR-0010-web-persistence.md) the
  web build has no encrypted database to key. It is not tree-shaken-and-probably-absent;
  it was never present.

`concurrency: {group: pages, cancel-in-progress: false}` — deploys queue rather
than cancel, because cancelling a half-finished Pages deployment can leave the
site broken.

> **One-time manual setup:** GitHub → Settings → Pages → Source must be
> **GitHub Actions**. While it is left as "Deploy from a branch", Pages ignores
> the workflow entirely and serves the branch through Jekyll, rendering
> `README.md` as the home page. That is the cause if the site shows README text
> instead of the app.

---

## What is not automated

| Concern | Reality |
|---|---|
| Android release build & upload | Manual. Signing config **does** exist — `android/app/build.gradle.kts` reads either `ANDROID_KEYSTORE_*` env vars or a git-ignored `android/key.properties`. Without either, debug builds still work but **release packaging fails** — it never falls back to the debug key. Keystore, signing, and Firebase App Distribution: [android-release.md](android-release.md). |
| iOS build, TestFlight, App Store | Manual. `tool/generate_ios_env.dart` writes `ios/Flutter/Env.xcconfig` from `.env`. |
| Fastlane | **No `fastlane/` directory exists.** [ci-cd.md](ci-cd.md) describes it as though it does. |
| `flutter analyze` / `flutter test` on PR | No workflow runs them. [../skills/engineering-standard.md](../skills/engineering-standard.md) §10 requires coverage gates that nothing enforces. |
| Branch strategy | `main` and `web` exist. `develop`, `release/*`, `hotfix/*` do not. |
| Versioning | `1.0.0+1` in `pubspec.yaml`, unchanged since the initial commit. |

**The highest-value gap is a PR workflow running `dart format --set-exit-if-changed`,
`flutter analyze`, and `flutter test`.** Everything in the engineering standard
about quality gates is currently enforced by convention alone.

---

## Local build commands

```bash
# Prerequisites: .env present, code generation run
cp .env.example .env            # then fill in real values
dart run build_runner build --delete-conflicting-outputs

# Verify before building
dart format --set-exit-if-changed .
flutter analyze
flutter test

# Android
flutter build apk   --release
flutter build appbundle --release

# iOS  (regenerate the xcconfig first)
dart run tool/generate_ios_env.dart
flutter build ipa   --release

# Web
flutter build web --release --base-href /isi-steel-sales-mobile/
```

`dart run build_runner build` is **required** after any change to a Drift table,
a DAO, a `json_serializable` model, or `.env` — Envied compiles `.env` into
`lib/core/config/env.g.dart`, so a missing key fails code generation rather than
failing at runtime.

---

## Release gate

Before tagging a release, confirm every one of these:

- [ ] `dart format --set-exit-if-changed .` clean
- [ ] `flutter analyze` clean
- [ ] `flutter test` — all pass
- [ ] `dart run build_runner build --delete-conflicting-outputs` produces no diff
- [ ] No `// TODO(release-gate):` remains — every debug shortcut (mock SAP
      client, geofence bypass, permissive fraud policy) must be tagged that way
      and must not ship. See [../skills/security.md](../skills/security.md) §11.
- [ ] No plaintext database file ships; `PRAGMA cipher_version` assertion intact
- [ ] `.env` is not committed; `.env.example` contains no real values
- [ ] `pubspec.yaml` version bumped
- [ ] Store metadata and screenshots current

---

## Related

- [environment.md](environment.md) — the configuration surface
- [../skills/security.md](../skills/security.md) §11–§12 — release and CI security gates
- [../blueprint/web-architecture.md](../blueprint/web-architecture.md) — what the web target actually is
- [../adr/ADR-0010-web-persistence.md](../adr/ADR-0010-web-persistence.md) — why web has no secrets
