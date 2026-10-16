#!/usr/bin/env bash
# PreToolUse (Bash) — block shell commands that touch secret-bearing files.
#
# The Read deny list and guard-secrets.sh only cover the Read/Write tools;
# `cat .env`, `echo x > key.properties` or `cp release.jks /tmp` would walk
# straight past them. This closes that gap. It is a best-effort string match,
# not a sandbox: it raises the cost of an accident, it does not stop a
# determined attacker. Fails closed.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/secret-paths.sh
source "$here/lib/secret-paths.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "guard-bash: jq is not installed, so the command cannot be checked. Install jq (brew install jq / apt install jq)." >&2
  exit 2
fi

cmd="$(jq -r '.tool_input.command // empty')"
[ -n "$cmd" ] || exit 0

# Mentions of the committed template are fine; strip them before matching.
scan="${cmd//.env.example/}"

# A single read-only git query (`git check-ignore .env`, `git ls-files`) never
# prints file contents, so it is allowed — but only when nothing is chained
# after it; `git status && cat .env` must still be caught.
if printf '%s' "$scan" | grep -Eq '^git (check-ignore|ls-files|status)( [^;&|`$<>()]*)?$'; then
  exit 0
fi

if printf '%s' "$scan" | grep -Eq "$SECRET_CMD_REGEX"; then
  jq -nc '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Refused: this command touches a secret-bearing file (.env, signing keys, key.properties, Firebase credentials). See .claude/rules/security.md §4. If it is genuinely needed, the user must run it by hand."
    }
  }'
fi
exit 0
