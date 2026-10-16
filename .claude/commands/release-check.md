---
description: Audit release readiness — gates, config, permissions, release-gate TODOs — and report real results. Read-only; never signs, uploads, or bumps versions.
argument-hint: '[platform: android | ios | web | all — defaults to all]'
---

Release check for: **$ARGUMENTS** (default: all platforms)

Follow `.claude/rules/release-and-environments.md` §3. This is an audit:
**do not fix findings in this command.** Report them; fixes are separate tasks.

## 1. State of the tree

```bash
git status
git branch --show-current
git log --oneline -10
```

An uncommitted tree or a non-`release/*` / non-`main` branch is a finding.

## 2. Gates

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test/       # if a device is available
```

## 3. Release-gate markers and debug leftovers

```bash
rg -n "TODO\(release-gate\)" lib/
rg -n "debugPrint|print\(" lib/ --glob '!*.g.dart'
```

For each `TODO(release-gate)`: is it reachable in a release build
(`kReleaseMode` guarded or not)? Reachable = **blocker**.

## 4. Configuration

- `pubspec.yaml` version and build number — report them; do not change them.
- Environment selection resolves to production for release (find the mechanism;
  do not assume it).
- `.env.example` lists every key that `lib/core/config/` reads.
- `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`:
  list every permission and confirm a feature uses it. Check cleartext traffic
  and `NSAllowsArbitraryLoads`.
- Release build settings: minification/obfuscation, `--split-debug-info`.
- Crash reporting present for release, with PII scrubbing.

## 5. Builds

Build each platform this machine can build, in release mode, and report
success or the real error. Never run signing upload or store commands.

## 6. Report

A table: check · result (pass / fail / not run) · evidence. Then **Blockers**,
**Risks**, **Not verified** (each with why), and a one-line verdict:
ready / ready with risks / blocked.
