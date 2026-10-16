# `.claude/` — AI agent configuration

Configuration for Claude Code on **ISI Steel Sales Mobile**. It makes the agent
work like a senior engineer on this codebase: it follows the architecture,
proves its work, and does not touch secrets. This file is for humans; the agent
starts from `CLAUDE.md`.

## Layout

| Path | Purpose | Loaded |
|---|---|---|
| `CLAUDE.md` | Role, the four gates, rule index, repo map. A router, not a manual. | Every session |
| `rules/` | Enforceable behaviour rules, one subject per file, each pointing at its authoritative `docs/` source. | When the task matches |
| `agents/` | Subagents: `flutter-developer`, `api-integrator`, `code-reviewer` (read-only), `ui-ux-reviewer` (read-only). | On delegation |
| `commands/` | `/feature` `/screen` `/api` `/debug` `/test` `/review` `/release-check` | On invocation |
| `skills/` | `secure-mobile-dev-guide` — Flutter-first MASVS guidance. | On demand |
| `hooks/` | Secret guards and auto-format. Tested by `hooks/tests/run.sh`. | Every tool call |
| `settings.json` | Permissions in three tiers (allow / ask / deny) and hook wiring. Committed. | Every session |
| `settings.local.json` | Per-machine hooks (graphify). **Gitignored. Never commit or share.** | Every session |

## Setup in a fresh clone

```bash
brew install jq            # or: apt install jq — the guards fail closed without it
graphify claude install    # writes your settings.local.json
.claude/hooks/tests/run.sh # should print: N passed, 0 failed
```

## Precedence

When sources disagree: `docs/skills/engineering-standard.md` → `docs/adr/` →
`docs/skills/ai-engineering-playbook.md` → `docs/blueprint/` →
`docs/feature/` → this directory. The **source code** is the truth about what
the app does today; a mismatch with any document is reported, never silently
"fixed".

## Changing this configuration

Treat it like code: a branch, a reviewed PR, and a `CHANGELOG.md` entry.

- Keep `CLAUDE.md` and each rule file to roughly 150 lines. Longer material
  belongs in `docs/skills/`.
- A rule must be enforceable — "do X" / "never Y", not "consider".
- Never duplicate a `docs/` rule; link to it with its section number.
- After touching a hook: `shellcheck -x .claude/hooks/*.sh` and
  `.claude/hooks/tests/run.sh`.
- After touching `settings.json`: `jq empty .claude/settings.json`.
