# Code quality

Authoritative: `docs/skills/code-quality-standard.md`. This file is the
enforceable summary; layering, naming, errors, testing and security keep
their own homes (see that document's table).

---

## 1. Split by responsibility, not by line count

Every file and class has one responsibility you can name in a few words.
The numbers below are what to look for, not what to cut to. Never split a
unit in half just to pass a limit.

| | Target | Review | Must act |
|---|---|---|---|
| File (non-generated) | ≤ 150 | 201–300 | > 300: split before adding; > 500: never add to it |
| Function | 5–30 | 31–50 | > 50 (except a flat `switch` or widget tree) |

Generated code, `assets/lang/*.json` and test fixtures are exempt.
Mock/demo data under `lib/` is **not** — it ships (§3).

## 2. When you write or change code

- **Reuse first.** Search the feature, `lib/shared/` and `lib/core/` before
  creating a widget, helper or service. Do not duplicate one that exists.
- **No new file or abstraction without a reason.** No interface with one
  implementation unless a layer boundary needs it; prefer a plain function
  to a stateless one-method class.
- **Extract widgets as classes**, not `Widget _buildX()` methods.
- **Comments say why**, never what. No commented-out code.
- **No magic values.** Constants live in their settled home
  (`.claude/rules/architecture.md` §2); never a catch-all constants file.
- **Do not touch unrelated code.** Boy-scout fixes stay local; anything
  larger is a separate refactor.
- If a file you touch is already over 300 lines, do not make it bigger
  without saying why in your report; over 500, raise the split instead.

## 3. Dead code and mocks

- Delete unused imports, members, files and duplicate files — after
  proving no references (imports **and** DI registrations, routes, string
  lookups).
- Never delete the migration-plan stubs in `core/sync/`,
  `core/database/files/`, `core/network/sap_client.dart`.
- Mock data in `lib/` must be deleted, moved to `test/`, or debug-only with
  `// TODO(release-gate):` (`security.md` §5).

## 4. Refactoring

- **Behaviour does not change**: API contracts, schemas, business rules,
  auth, navigation, permissions stay identical.
- **A refactor is its own change** — never mixed with a feature or fix.
- **Pin behaviour with tests first** if none exist.
- Run `graphify affected <file>` first for anything shared (`workflow.md` §4).
- Priority: P0 security / data / auth → P1 files > 500, God classes,
  duplicated logic, wrong-direction imports → P2 naming, 300–500-line files →
  P3 cosmetic. Never work a lower tier while a higher one is open.

## 5. Gate

After every change: `dart format`, `flutter analyze` (zero issues), targeted
tests, then the feature suite. Report sizes before → after for any file you
split. Never claim a split preserved behaviour without the tests that show it.
