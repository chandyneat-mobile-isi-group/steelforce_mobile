# How to manage the documentation

> The rules that keep `docs/` small, findable and free of duplicates.
> Read this before adding, moving or deleting a document.
> `dart run tool/check_docs.dart` enforces the mechanical parts.

---

## 1. Where does my document go?

Answer the questions in order. The first **yes** decides.

```
Is it a decision we must not silently reverse?        → adr/ADR-00NN-<decision>.md
Is it about building, shipping or releasing the app?   → release/
Is it a rule or how-to that applies to ANY feature?    → skills/
Does it describe the app's overall architecture?       → blueprint/
Is it about ONE feature (API, screens, data, tests)?   → feature/<feature>/
Is it a business requirement written by the business? → requirement/
Is it the app's current security posture?             → security/
None of the above?                                     → ask before creating a file
```

| Folder | Holds | Does **not** hold |
|---|---|---|
| `adr/` | Locked decisions, one per file, numbered | Proposals still being argued (keep them in the PR) |
| `blueprint/` | Architecture of the whole app: storage, sync, navigation, web | Anything about one feature |
| `feature/<name>/` | How one feature works and where its code is | Rules that apply to every feature |
| `skills/` | Engineering standards and how-to guides | App-specific facts that change with the code |
| `requirement/` | Business requirements, including the business's own `.docx` files | Technical design |
| `release/` | Build, environment, CI/CD, distribution | Feature behaviour |
| `security/` | Current security posture and the plain-language guide | Engineering security rules (`skills/security.md`) |
| `style-rule/` | Brand guide | Code conventions (`skills/feature-ui-standard.md`) |

**Feature folder names** match `lib/features/`, hyphenated:
`lib/features/my_visits` → `feature/my-visits/`. One exception, kept for
history: `lib/features/depots` → `feature/depot/`.

---

## 2. One topic, one home

**Before creating a file, search for the topic first:**

```bash
grep -ril "check-in" docs/            # is it already documented?
```

- If a document already covers the topic, **edit that document**. Don't
  start a new one beside it.
- If two documents overlap, the more specific one is authoritative; the other
  **links** to it in one line and does not restate it.
- **Never copy a document** to make a "v2", "new", "final" or "mobile" copy.
  Git keeps history; edit in place.
- **Never vendor a backend document.** Link it in plain text with the marker
  `⧉ backend repo` (for example: `notification-architecture.md ⧉ backend repo`).
  A copy drifts out of date the day it is made.

---

## 3. Naming

| Kind | Rule | Example |
|---|---|---|
| Document | lowercase `kebab-case.md` | `check-in-api.md` |
| Folder | lowercase `kebab-case` | `my-visits/` |
| Entry point | `README.md` in every folder | `feature/depot/README.md` |
| ADR | `ADR-00NN-short-decision.md`, never renumbered | `ADR-0011-local-mirror-no-foreign-keys.md` |
| Binary reference (`.pdf`, `.docx`, `.xlsx`, `.drawio`) | No spaces; keep it next to the doc that uses it, in a `reference/` subfolder | `feature/depot/reference/bp-creation-fields-sap.xlsx` |

Never use version or state words in a name: `final`, `new`, `v2`, `old`, `copy`,
`(3)`.

---

## 4. Standard per-feature files

Create **only the files that have real content**. A feature with one
`README.md` is fine.

| File | When to create it |
|---|---|
| `README.md` | **Always**: what it is, screens, API, offline behaviour, where the code lives |
| `api.md` | The feature calls the backend. Use `api/mobile.md` + `api/admin.md` only if the two contracts differ |
| `architecture.md` | Layering or data flow is not obvious from the README |
| `workflow.md` | Multi-step user or sync flows |
| `business-rules.md` | Rules the business owns (limits, statuses, approvals) |
| `data-model.md` | Local tables or entities worth explaining |
| `testing.md` | Test strategy beyond the defaults |
| `changelog.md` | Only for features with frequent contract changes |

The worked example is [feature/authentication/](feature/authentication/). The
full template is [skills/feature-documentation-template.md](skills/feature-documentation-template.md).

---

## 5. The header every document starts with

```markdown
# <Title>

> **Status:** Current · **Owner:** <role or team> · **Last reviewed:** 2026-10-24
> **Code:** `lib/features/<feature>/`
```

| Status | Meaning |
|---|---|
| **Draft** | Being written; may be wrong |
| **Current** | Matches the code; safe to rely on |
| **Proposed** | Describes something not built yet |
| **Deprecated** | Kept only until its replacement is linked; delete soon |

Add the header when you create or substantially edit a document. Older
documents get it when they are next touched.

---

## 6. Life of a document

```
Draft ──► Current ──► (code changes) ──► update in the same PR
                │
                └──► replaced? ──► delete it; put a one-line link in its successor
```

- **Update docs in the same PR as the code.** A doc that disagrees with `lib/`
  is a bug. The code wins (see [README.md](README.md#authority-precedence)).
- **Completed plans** (`*-plan.md`, change requests, upgrade plans): when the
  work ships, move the outcome into the feature's `README.md` and **delete the
  plan**.
- **One-off reports and backend handoff notes**: delete them once acted on.
- **Deleted is not lost.** Git history is the archive: `git log --all --
  docs/<path>` finds any deleted document. There is no `archive/` folder: an
  archive is where stale duplicates go to be found by mistake.

---

## 7. Before you commit a docs change

```bash
dart run tool/check_docs.dart
```

It fails on broken relative links, badly named files, byte-identical
duplicates and junk files (`.DS_Store`). Then check yourself:

- [ ] Searched for an existing doc on this topic first
- [ ] Linked from the folder's `README.md` index (new files)
- [ ] Header block present (new or substantially edited files)
- [ ] No secrets, tokens, keys, customer data or production URLs
- [ ] Removed or redirected anything this change made obsolete
