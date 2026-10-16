# Changelog — agent configuration

## 2026-10-08

### Security
- **Closed a delete bypass:** removed `find *` from the allow list (it permitted
  `find -delete` / `-exec rm`); added explicit denies for `find -delete/-exec`
  and every `rm -r` spelling.
- **Branch deletion now denied:** `git branch *` narrowed to read-only forms;
  `-d`/`-D`/`--delete`, tag deletion, `rebase`, and all `git clean` denied.
- **New `ask` tier:** `git add/commit/switch/checkout/stash`, branch creation,
  and every `pub add/remove/upgrade` now require approval.
- **Signing material protected from reads:** `android/key.properties`,
  keystores, `.p8/.p12/.pem/.key`, provisioning profiles, Firebase and
  service-account files added to the Read deny list.
- **`guard-secrets.sh` fails closed** when `jq` is missing (it previously
  allowed the write), and now also covers `MultiEdit` and `NotebookEdit`.
- **New `guard-bash.sh`:** blocks shell access to secret files (`cat .env`,
  `cp upload.jks`), including chained commands.
- Protected-file list moved to a single shared `hooks/lib/secret-paths.sh`.
- New hook test suite, `hooks/tests/run.sh` (44 cases).

### Rules
- New `performance.md` — measure-first, budgets, isolates, startup, battery.
- New `dependencies.md` — package evaluation checklist, pinning, upgrades.
- New `release-and-environments.md` — environments, versioning, release gate,
  crash reporting, rollback strategy.
- `security.md` §6 (new) — deep links and notification payloads as untrusted
  input; §4 adds `key.properties` and "the binary will be decompiled".
- `workflow.md` §2 — explicit approval gate for Type C/D work and refactors.
- `CLAUDE.md` §1 — push back on bad designs before building; plan-then-wait.

### Fixes
- Unified the `connectivity_service.dart` path
  (`core/network/connectivity/`) across rules, agents, and commands.
- `CLAUDE.md` gate 4 and §8 pointed at the wrong `workflow.md` sections.
- `secure-mobile-dev-guide` rewritten Flutter-first; it now defers to the
  project's ADRs and key scheme instead of giving generic Kotlin/Swift crypto
  advice.

### Added
- `/release-check` command; `README.md` (human onboarding); this changelog.
- Reviewer agent and `/review` now check untrusted input, performance claims,
  and dependency changes.
