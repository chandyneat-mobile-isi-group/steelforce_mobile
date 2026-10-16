# `.claude/hooks/` — project hooks

Committed, machine-independent hooks, wired in `.claude/settings.json` via
`$CLAUDE_PROJECT_DIR` so they work in any clone. **Requires `jq`**
(`brew install jq` / `apt install jq`).

| Script | Event | What it does | On error |
|---|---|---|---|
| `guard-secrets.sh` | `PreToolUse` · `Write\|Edit\|MultiEdit\|NotebookEdit` | Denies writes to `.env*`, `Env.xcconfig`, `env.g.dart`, `key.properties`, keystores, certificates, private keys, Firebase and service-account credentials. `.env.example` is allowed. | **Fails closed** |
| `guard-bash.sh` | `PreToolUse` · `Bash` | Denies shell commands that mention the same files (`cat .env`, `cp upload.jks …`, `… > key.properties`), including when chained after an allowed command. A lone `git check-ignore` / `git ls-files` / `git status` is allowed. | **Fails closed** |
| `format-dart.sh` | `PostToolUse` · `Write\|Edit\|MultiEdit` | Runs `dart format` on the `.dart` file just written. Skips `*.g.dart`, `*.freezed.dart`, `*.gen.dart`. | Fails open — never blocks an edit that already succeeded |

The protected-file list lives in **one place**, `lib/secret-paths.sh`, and both
guards source it. Add a new secret type there, then add a case to the tests.

## Limits — read this

These guards are a seatbelt, not a sandbox. `guard-bash.sh` matches the command
string; it cannot see through variables, globs, or a script that opens the file
itself. The real protections are: secrets are gitignored, true secrets live on
the backend (`rules/security.md` §4), and the user reviews every `ask`-tier
command.

## Tests

```bash
.claude/hooks/tests/run.sh      # exits non-zero on any failure — CI-safe
```

Covers deny and allow cases for both guards, chained-command bypass attempts,
and fail-closed behaviour when `jq` is missing. Run it after every hook change.

## Machine-specific hooks live elsewhere

The `graphify hook-guard` hooks embed an absolute path to a binary in the
developer's home directory, so they belong in `.claude/settings.local.json`,
which `.gitignore` excludes. Install them in a fresh clone with:

```bash
graphify claude install
```

Do not move them into the committed `settings.json` — the absolute path breaks
for everyone else on the team. Never share or zip `settings.local.json`.

## Conventions for new hooks

- Read the payload with `jq -r` into a quoted variable. Never unquoted `xargs`.
- A **guard** (PreToolUse that protects something) fails closed: `exit 2` with
  a message on stderr when it cannot decide.
- A **convenience** hook (formatting, notifications) fails open and must never
  fail the tool call.
- Deny with a `hookSpecificOutput.permissionDecision: "deny"` JSON object and a
  reason that tells the agent what to do instead.
- `chmod +x` the script, run `shellcheck -x`, add test cases to
  `tests/run.sh`, and add a row to the table above.
