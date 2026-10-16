#!/usr/bin/env bash
# PreToolUse (Write|Edit|MultiEdit|NotebookEdit) — refuse to write secret-bearing
# or deliberately-uncommitted generated files.
#
# Fails CLOSED: a security guard that cannot inspect the payload blocks the
# write rather than waving it through. (format-dart.sh fails open on purpose;
# this one must not.)
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/lib/secret-paths.sh
source "$here/lib/secret-paths.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "guard-secrets: jq is not installed, so the write cannot be checked. Install jq (brew install jq / apt install jq)." >&2
  exit 2
fi

file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')"
[ -n "$file" ] || exit 0

if reason="$(secret_reason "$(basename "$file")")"; then
  jq -nc --arg f "$file" --arg why "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Refused to write \($f): \($why). See .claude/rules/security.md §4. If this is genuinely needed, the user must do it by hand.")
    }
  }'
fi
exit 0
