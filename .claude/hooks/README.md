# `.claude/hooks/` — project hooks

Committed, machine-independent hooks, wired in `.claude/settings.json` via
`$CLAUDE_PROJECT_DIR` so they work in any clone.

| Script | Event | What it does |
|---|---|---|
| `format-dart.sh` | `PostToolUse` on `Write\|Edit` | Runs `dart format` on the `.dart` file just written. Skips generated files (`*.g.dart`, `*.freezed.dart`, `*.gen.dart`) so `build_runner` output is not churned. Never fails the tool call. |
| `guard-secrets.sh` | `PreToolUse` on `Write\|Edit` | Denies writes to `.env*`, `Env.xcconfig`, `env.g.dart`, keystores, certificates, private keys, and Firebase credential files. `.env.example` is allowed. |

## Machine-specific hooks live elsewhere

The `graphify hook-guard` hooks embed an absolute path to a binary in the
developer's home directory, so they belong in `.claude/settings.local.json`,
which `.gitignore` excludes. Reinstall them in a fresh clone with:

```bash
graphify claude install
```

Do not move them back into the committed `settings.json` — the absolute path
breaks for everyone else on the team.

## Conventions for new hooks

- Read the payload with `jq -r` into a quoted variable. Never unquoted `xargs`.
- Guard on `command -v <tool>` and exit 0 if it is missing.
- A `PostToolUse` hook must not fail the tool call it follows.
- Test before wiring:
  `echo '{"tool_name":"Edit","tool_input":{"file_path":"…"}}' | .claude/hooks/<script>.sh`
- `chmod +x` the script, and add a row to the table above.
