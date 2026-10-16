#!/usr/bin/env bash
# Single source of truth for files the agent must never read or write.
# Sourced by guard-secrets.sh (Write/Edit) and guard-bash.sh (Bash).
# Rationale per entry: .claude/rules/security.md §4.

# secret_reason <basename> — prints a reason and returns 0 if the file is
# protected; returns 1 otherwise.
secret_reason() {
  local base="$1"
  case "$base" in
    .env.example) return 1 ;;  # the committed template is allowed
  esac
  case "$base" in
    .env|.env.*)       echo "carries DB_SALT and environment secrets; gitignored" ;;
    Env.xcconfig)      echo "generated from .env by tool/generate_ios_env.dart" ;;
    env.g.dart)        echo "Envied output; generated and deliberately not committed" ;;
    key.properties)    echo "Android signing passwords in plaintext" ;;
    *.jks|*.keystore|*.p12|*.p8|*.pem|*.key|*.mobileprovision)
                       echo "signing or private key material" ;;
    google-services.json|GoogleService-Info.plist)
                       echo "Firebase credential file" ;;
    service-account*.json)
                       echo "cloud service-account credential" ;;
    *) return 1 ;;
  esac
}

# Regex used to spot the same files inside a shell command string.
# Keep in sync with secret_reason above (tests/run.sh checks both).
# shellcheck disable=SC2034  # consumed by guard-bash.sh
SECRET_CMD_REGEX='(^|[[:space:]/"'"'"'=<>])(\.env(\.[A-Za-z0-9_-]+)?|Env\.xcconfig|env\.g\.dart|key\.properties|[^[:space:]/]+\.(jks|keystore|p12|p8|pem|key|mobileprovision)|google-services\.json|GoogleService-Info\.plist|service-account[^[:space:]]*\.json)([[:space:]"'"'"';|&)<>]|$)'
