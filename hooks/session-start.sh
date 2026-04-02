#!/usr/bin/env bash
# Ship plugin — SessionStart hook
# Injects .ship/rules/CONVENTIONS.md into conversation context.
# If no CONVENTIONS.md exists, outputs nothing (no-op).

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONVENTIONS_FILE="$REPO_ROOT/.ship/rules/CONVENTIONS.md"

if [[ ! -f "$CONVENTIONS_FILE" ]]; then
  exit 0
fi

CONTENT=$(cat "$CONVENTIONS_FILE" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' '\\' | sed 's/\\/\\n/g')

cat << EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "The following project-specific conventions MUST be followed. These are semantic rules that require your judgment — violations cause bugs, security issues, or architectural breakage.\n\n${CONTENT}"
  }
}
EOF

exit 0
