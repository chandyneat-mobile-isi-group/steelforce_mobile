# `.claude/rules/` — agent behaviour rules

These files govern **how the agent works in this repository**. They are
deliberately thin: where an authoritative document already exists in `docs/`,
the rule points at it instead of restating it. One subject has one home.

| File | Scope |
|---|---|
| `workflow.md` | Task lifecycle, classification, graph analysis, verification ladder, failure recovery, reporting. Read on every task. |
| `architecture.md` | Layering, DI, repositories, DAOs, folder ownership, naming. |
| `flutter.md` | Dart/Flutter code style, widget structure, performance, error handling. |
| `ui-ux.md` | Visual language, responsive/adaptive, motion, localization, accessibility. |
| `state-management.md` | BLoC/Cubit conventions and state modelling. |
| `api-integration.md` | Backend calls, endpoint discovery, models, error mapping. |
| `firebase.md` | FCM, channels, permissions, deep links, web no-ops. |
| `testing.md` | Which tests a change requires and how to run them. |
| `security.md` | Secrets, PII, encryption, logging, release gating. |
| `git-safety.md` | Branching, committing, and destructive-command policy. |

## Editing these files

- Keep each file under ~150 lines. Longer material belongs in `docs/skills/`.
- Never duplicate a `docs/` rule here — link to it with its section number.
- A rule must be **enforceable**: state what to do or not do, not what is nice.
- When a rule and a `docs/` document disagree, the `docs/` document wins
  (see `.claude/CLAUDE.md` §6) and the rule here is the bug.
