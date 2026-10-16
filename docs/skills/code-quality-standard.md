# Code Quality Standard

> **Scope:** how large a file, class or function may grow, when to split it,
> and how to refactor without changing behaviour. The rules that keep this
> codebase readable as it grows.
>
> **Not here, because each already has one home** — this document links to
> them instead of restating them:
>
> | Subject | Authoritative document |
> |---|---|
> | Layering, folder ownership, DI, repositories, usecases | [engineering-standard.md](engineering-standard.md) §3–§8, [ai-engineering-playbook.md](ai-engineering-playbook.md) §3 |
> | Naming conventions | [ai-engineering-playbook.md](ai-engineering-playbook.md) §2, [engineering-standard.md](engineering-standard.md) §9 |
> | State management | [engineering-standard.md](engineering-standard.md) §4, [`.claude/rules/state-management.md`](../../.claude/rules/state-management.md) |
> | Error handling and failures | [engineering-standard.md](engineering-standard.md) §7 |
> | Testing and coverage gates | [engineering-standard.md](engineering-standard.md) §10 |
> | Security, secrets, logging | [security.md](security.md) |
> | UI, performance, motion, localization | [feature-ui-standard.md](feature-ui-standard.md) |
> | Commits, branches, destructive commands | [`.claude/rules/git-safety.md`](../../.claude/rules/git-safety.md) |
>
> Authority: this sits beside [engineering-standard.md](engineering-standard.md).
> Where they disagree, `engineering-standard.md` wins
> ([`.claude/CLAUDE.md`](../../.claude/CLAUDE.md) §6).

---

## 1. The principle behind every number below

**Split by responsibility, never by line count.** A file, class or function
should do one thing a reviewer can name in a few words. The size limits are
the *symptom* to look for; the responsibility is the thing to fix.

A 180-line repository with one job is better than five 36-line files that
only make sense read together. Never cut a unit in half to pass a number.

---

## 2. File size

| Lines (excluding generated code) | Meaning | What to do |
|---|---|---|
| ≤ 150 | Target | Nothing. |
| 151–200 | Acceptable | Nothing, if it has one responsibility. |
| 201–300 | Review | In review, ask: does this file do more than one thing? |
| 301–500 | **Refactor required** | Split before adding to it. A change that makes it bigger needs a reason in the PR. |
| > 500 | **Strongly avoid** | Never add to it. Plan the split (§8) and do it in its own PR. |

**Exempt**, because their size is not a design choice:

- Generated code: `*.g.dart`, `*.freezed.dart`, Drift output, `env.g.dart`.
- Localization bundles (`assets/lang/*.json`).
- Fixtures and test data under `test/` — but **not** mock or demo data under
  `lib/`, which ships in the app (see §7).

Measure with:

```bash
find lib -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' \
  -exec wc -l {} + | sort -n | tail -20
```

---

## 3. One responsibility per file and per class

A file holds **one** public type and the small private helpers it needs.
A class has **one** reason to change.

Signs a file or class has more than one responsibility:

- You need the word *and* to describe it ("loads depots **and** formats
  addresses **and** shows the dialog").
- It imports from more than one layer's worth of packages — e.g. `dio`,
  `drift` *and* `flutter/material`.
- Its private methods fall into groups that never call each other.
- Tests for it need many unrelated fakes.

Typical splits in this codebase, all following the layering in
[engineering-standard.md](engineering-standard.md) §3:

| Grown-together concern | Its own home |
|---|---|
| JSON ↔ entity conversion | `data/models/<x>_model.dart` or a `<x>_mapper.dart` |
| Validation rules | A pure-Dart validator in `domain/`, unit-tested |
| A sub-section of a screen | `presentation/widgets/<x>.dart` |
| A dialog or bottom sheet | Its own widget file with a `show<X>()` function |
| Formatting for display | A presentation helper or an entity method |
| Network call | The feature's remote data source |

A widget used by **one** feature stays in that feature; it moves to
`lib/shared/` only when a second feature needs it
([`.claude/rules/architecture.md`](../../.claude/rules/architecture.md) §2).

---

## 4. Function size

| Lines | Meaning |
|---|---|
| 5–30 | Target |
| 31–50 | Review: is there a named step hiding inside? |
| > 50 | Split, unless it is a flat `switch` or a declarative widget tree that reads top to bottom |

A function does one operation at one level of abstraction:

```dart
// Each line is one named step; each step is small enough to read at a glance.
Future<void> submit() async {
  final failure = validate();
  if (failure != null) return emit(SubmitFailed(failure));
  final result = await _saveDepot(buildRequest());
  emit(result.when(success: SubmitSucceeded.new, failure: SubmitFailed.new));
}
```

For widgets: if `build()` no longer fits on one screen, extract sub-widgets
as **classes**, not methods returning `Widget` — classes get their own
element, rebuild independently and can be `const`
([feature-ui-standard.md](feature-ui-standard.md) §4).

---

## 5. Comments explain *why*

Write a comment when the code cannot say it: a constraint, a server quirk, a
decision and the alternative that was rejected, a bug this line prevents.

```dart
// BAD — repeats the code.
// Get the profile.
final profile = await _remote.getProfile();

// GOOD — says what the code cannot.
// The temporary-password flag arrives on the login response, not on the
// profile, so it is copied across before the profile is cached.
```

Never leave commented-out code; version control is the history
([ai-engineering-playbook.md](ai-engineering-playbook.md) §8).

---

## 6. No magic values

A literal whose meaning is not obvious at the use site gets a name.

| Kind of value | Home |
|---|---|
| API routes, timeouts, page sizes | `core/network/api/api_endpoints.dart`, `api_defaults.dart` |
| Secure-storage / Hive keys | `core/database/secure/secure_storage_keys.dart`, `core/database/hive/preference_keys.dart` |
| Colours, spacing, type sizes | `core/theme/` — never a raw `Color(0x…)` or font size in a widget |
| Server error codes | `ApiErrorCodes` in `core/network/api/api_error.dart` |
| A business status | An `enum`, never an `int` or a bare string compared by hand |
| A value used in one file only | A private `static const` in that file |

Do not create a catch-all constants file. A constant lives next to the
concept it belongs to ([`.claude/rules/architecture.md`](../../.claude/rules/architecture.md)
§2 lists the settled homes).

---

## 7. Dead code and shipped mocks

Remove, after confirming there are no references:

- unused imports, variables, private members (the analyzer reports these);
- files nothing imports;
- duplicated files — two copies drift, and the next fix lands in only one;
- obsolete widgets, services and their registrations in `<feature>_injection.dart`.

**Before deleting, prove it is unused**: search imports *and* string
references (DI registration, routes, reflection-like `runtimeType` checks).
Do not delete the stubs the migration plan tracks as intentionally empty
(`core/sync/`, `core/database/files/`, `core/network/sap_client.dart` —
[`.claude/rules/workflow.md`](../../.claude/rules/workflow.md) §5).

**Mock and demo data under `lib/` ships in the release binary.** It must be
either deleted, moved to `test/`, or registered only in debug builds with a
`// TODO(release-gate):` tag ([security.md](security.md) §11).

---

## 8. Refactoring process

### 8.1 Rules

- **A refactor does not change behaviour.** API contracts, database schemas,
  business rules, authentication, navigation and permissions stay exactly as
  they were. If behaviour must change, it is a feature or a fix, labelled and
  tested as one.
- **A refactor lands alone** — never in the same PR as a feature or fix
  ([ai-engineering-playbook.md](ai-engineering-playbook.md) §8).
- **One responsibility per refactor PR.** "Split `quotation_detail_screen.dart`"
  is one PR; "clean up the order feature" is not.
- **Run the blast-radius check first** for anything in `core/`, a repository,
  a DAO, the network client or sync: `graphify affected <file>`
  ([`.claude/rules/workflow.md`](../../.claude/rules/workflow.md) §4).

### 8.2 Steps

```
Understand current behaviour  →  pin it with tests if none exist
  →  identify dependents (graphify)  →  refactor in small steps
  →  dart format  →  flutter analyze (clean)  →  targeted tests
  →  feature suite  →  verify behaviour unchanged  →  report
```

Pinning tests come **first**: a refactor of untested code is a rewrite with
no safety net.

### 8.3 Priority

Work top-down; do not spend time on a lower tier while a higher one has open
items.

| Tier | What | Examples |
|---|---|---|
| **P0** | Security, data integrity, auth, crash bugs | A secret in source, a write without its sync-queue row, mock data in a release build |
| **P1** | Structure that blocks safe change | Files > 500 lines, God classes, duplicated business logic, wrong-direction imports, untestable code |
| **P2** | Friction | Naming drift, duplicated UI, needless complexity, files 300–500 lines |
| **P3** | Cosmetic | Formatting, small doc fixes |

---

## 9. Abstraction — enough, not more

- Extract shared code when two places express **the same business concept**,
  not because they look alike today.
- Do not add an interface with one implementation unless the layer boundary
  requires it (a repository interface in `domain/` does; a helper does not).
- Prefer a plain function to a class with one method and no state.
- Reuse an existing component before writing a new one — search
  `lib/shared/`, `lib/core/` and the feature first.

---

## 10. Review checklist

Add these to the review in [ai-engineering-playbook.md](ai-engineering-playbook.md) §7:

- [ ] No touched file grew past 300 lines without a stated reason; none past 500.
- [ ] Each new file and class has one nameable responsibility.
- [ ] No new function over 50 lines that is not a flat switch or widget tree.
- [ ] Comments explain why; no commented-out code.
- [ ] No new magic values; constants live in their settled home (§6).
- [ ] No dead code, duplicate file or `lib/` mock added.
- [ ] Refactors are behaviour-preserving, pinned by tests, and in their own PR.
- [ ] `dart format`, `flutter analyze` (zero issues) and the relevant tests ran.
