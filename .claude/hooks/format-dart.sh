#!/usr/bin/env bash
# PostToolUse (Write|Edit) — format the Dart file that was just written.
#
# `flutter analyze` is a merge gate and `dart format --set-exit-if-changed .`
# runs in CI, so formatting every edit as it happens keeps the final diff free
# of formatting churn. Never fails the tool call: a formatter problem must not
# block an edit that already succeeded.
set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0
command -v dart >/dev/null 2>&1 || exit 0

file="$(jq -r '.tool_response.filePath // .tool_input.file_path // empty')"
[ -n "$file" ] || exit 0
[ -f "$file" ] || exit 0
case "$file" in
  *.dart) ;;
  *) exit 0 ;;
esac
# Generated files are formatted by their generator; reformatting them creates
# spurious diffs on the next build_runner run.
case "$file" in
  *.g.dart|*.freezed.dart|*.gen.dart) exit 0 ;;
esac

dart format "$file" >/dev/null 2>&1 || true
exit 0
