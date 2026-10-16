#!/usr/bin/env bash
# Hook test suite. Run from the repo root:  .claude/hooks/tests/run.sh
# Exits non-zero on any failure, so it can run in CI next to flutter analyze.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

pass=0; fail=0
check() {  # check <hook> <expect: deny|allow> <json payload> <label>
  local out decision
  out="$(printf '%s' "$3" | "./$1" 2>/dev/null)"
  decision=allow  # no output from a PreToolUse hook means "no objection"
  [ -n "$out" ] && decision="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"')"
  if [ "$decision" = "$2" ]; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL [$1] expected $2, got $decision: $4"; fi
}
w() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1"; }
b() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }

# --- guard-secrets.sh: writes ---
for f in .env .env.production ios/Flutter/Env.xcconfig lib/core/config/env.g.dart \
         android/key.properties android/app/upload.jks release.keystore cert.p12 \
         AuthKey_ABC.p8 server.pem private.key app.mobileprovision \
         android/app/google-services.json ios/Runner/GoogleService-Info.plist \
         service-account-prod.json; do
  check guard-secrets.sh deny "$(w "$f")" "write $f"
done
for f in .env.example lib/main.dart lib/features/depots/data/depot_model.dart \
         pubspec.yaml assets/lang/km.json lib/core/keys/key_store.dart; do
  check guard-secrets.sh allow "$(w "$f")" "write $f"
done
check guard-secrets.sh deny \
  '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":".env"}}' "notebook .env"

# --- guard-bash.sh: shell access ---
for c in "cat .env" "cat ./.env.staging" "less android/key.properties" \
         "cp android/app/upload.jks /tmp/" "echo DB_SALT=x > .env" \
         "base64 release.keystore" "grep storePassword android/key.properties" \
         "git status && cat .env" "git ls-files; cat key.properties" \
         'cat "ios/Runner/GoogleService-Info.plist"' "openssl x509 -in server.pem"; do
  check guard-bash.sh deny "$(b "$c")" "$c"
done
for c in "flutter test test/features/depots/" "cat .env.example" "git status" \
         "git check-ignore .env" "git ls-files android/key.properties" \
         "grep -rn environment lib/" "dart run build_runner build --delete-conflicting-outputs" \
         "cat lib/core/config/env.dart" "ls android/app"; do
  check guard-bash.sh allow "$(b "$c")" "$c"
done

# --- fail-closed when jq is missing ---
nojq="$(mktemp -d)"; for t in bash dirname basename cat; do ln -s "$(command -v $t)" "$nojq/$t"; done
if printf '%s' "$(w lib/main.dart)" | PATH="$nojq" ./guard-secrets.sh >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL guard-secrets.sh did not fail closed without jq"; else pass=$((pass+1)); fi
if printf '%s' "$(b ls)" | PATH="$nojq" ./guard-bash.sh >/dev/null 2>&1; then
  fail=$((fail+1)); echo "FAIL guard-bash.sh did not fail closed without jq"; else pass=$((pass+1)); fi
rm -rf "$nojq"

echo "hooks: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
