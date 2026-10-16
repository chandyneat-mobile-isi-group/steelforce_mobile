# Dependencies

Every package is code we ship, patch, and answer for — on three platforms
(ADR-010), for years. Adding one is a Type B decision at minimum; a package
that touches auth, crypto, storage, networking, or native code is Type D
(`workflow.md` §2).

`flutter pub add`, `remove`, and `upgrade` are in the settings `ask` list: the
user approves every change to `pubspec.yaml` dependencies.

---

## 1. Before proposing a package

Answer these in the proposal. A "no" or "unknown" is not automatically a veto,
but it must be stated.

| Question | How to check |
|---|---|
| Does the project, the SDK, or an existing dependency already do this? | Search `pubspec.yaml`, `lib/core/`, `lib/shared/`. A few lines of our own code beat a package. |
| Is it maintained? | pub.dev: last publish, open-issue trend, verified publisher. |
| Does it support our Dart/Flutter SDK constraint **and** Android, iOS, and web? | pub.dev platform badges; the package's `pubspec.yaml` environment block. |
| What does it pull in transitively? | `flutter pub deps` after a trial add on a branch. |
| What does it cost in app size and startup? | Native SDKs and large assets especially. Measure if it is significant. |
| What data does it see or send? | Analytics, crash, and ads SDKs: read the data-collection docs; check against `security.md`. |
| What is the exit plan? | Wrap it behind our own interface if it would otherwise spread through `lib/`. |
| Licence compatible with a commercial closed-source app? | No GPL/AGPL in the shipped binary. |

## 2. Rules

- **One package per job.** Never add a second HTTP client, state library, DI
  container, database, or image cache beside the one we have
  (`architecture.md`, `state-management.md`).
- **Isolate it.** A third-party type must not leak into `domain/`. Wrap SDKs in
  `core/` behind a small interface when more than one feature uses them.
- **Pin deliberately.** Use caret constraints (`^x.y.z`); commit
  `pubspec.lock` (this is an application, not a library). Never `any`.
- **No git or path dependencies** on a release branch without an explicit,
  documented reason.
- **Dev-only tools** (`build_runner`, generators, lints, mocks) go in
  `dev_dependencies`.

## 3. Upgrades

- Upgrade on purpose, never as a side effect of another task.
- One major-version bump per change; read the changelog for breaking changes
  and migration notes first.
- After any upgrade: `flutter pub get`, `dart run build_runner build
  --delete-conflicting-outputs` if a generator moved, `flutter analyze`, the
  full `flutter test` suite, and a build on each platform you can run.
- Use `flutter pub outdated` to report what is behind; do not act on it
  unprompted.

## 4. Report

When you add, remove, or upgrade a package, the report's **Summary** names it,
the version, the §1 answers, and what you verified on which platforms.
