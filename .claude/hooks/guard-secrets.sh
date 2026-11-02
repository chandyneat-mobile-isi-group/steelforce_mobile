#!/usr/bin/env bash
# PreToolUse (Write|Edit) — refuse to write secret-bearing or generated files.
#
# These paths are gitignored for a reason (.claude/rules/security.md §4): they
# carry the SQLCipher salt, signing material, or Envied output that must never
# be committed. A deny here is cheaper than noticing it in review.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_input.file_path // empty')"
[ -n "$file" ] || exit 0

base="$(basename "$file")"
deny=""

case "$base" in
  .env|.env.*)            deny="the .env file carries DB_SALT and is gitignored" ;;
  Env.xcconfig)           deny="generated from .env by tool/generate_ios_env.dart" ;;
  env.g.dart)             deny="Envied output — generated, deliberately not committed" ;;
  *.jks|*.keystore|*.p12|*.pem|*.key|*.mobileprovision)
                          deny="signing / private key material" ;;
  google-services.json|GoogleService-Info.plist)
                          deny="Firebase credential file" ;;
esac
case "$base" in .env.example) deny="" ;; esac

if [ -n "$deny" ]; then
  jq -nc --arg f "$file" --arg why "$deny" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("Refused to write \($f): \($why). See .claude/rules/security.md §4. If this is genuinely needed, the user must do it by hand.")
    }
  }'
  exit 0
fi
exit 0
