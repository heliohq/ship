#!/usr/bin/env bash
# Ship plugin — SessionStart hook
# Injects project context into conversation:
#   1. .learnings/LEARNINGS.md — project learnings (verified rules + pending observations)
#   2. docs/DESIGN_INDEX.md — design doc index for architectural guardrails
# If no files exist, outputs nothing (no-op).

set -u

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LEARNINGS_FILE="$REPO_ROOT/.learnings/LEARNINGS.md"
DESIGN_INDEX_FILE="$REPO_ROOT/docs/DESIGN_INDEX.md"

PARTS=""

# Part 1: Learnings (verified rules + pending observations)
if [[ -f "$LEARNINGS_FILE" ]]; then
  PARTS="Project learnings loaded. Verified entries are rules — follow them. Pending entries are recent observations — check them before making decisions in the affected areas.

$(cat "$LEARNINGS_FILE")"
fi

# Part 2: Design doc index
if [[ -f "$DESIGN_INDEX_FILE" ]]; then
  SEPARATOR=""
  [[ -n "$PARTS" ]] && SEPARATOR="

---

"
  PARTS="${PARTS}${SEPARATOR}Design doc index loaded. Before making architectural changes, check if a design doc covers the affected area. Read the relevant doc to understand boundaries and trade-offs before proceeding.

$(cat "$DESIGN_INDEX_FILE")"
fi

# Nothing to inject
if [[ -z "$PARTS" ]]; then
  exit 0
fi

# Use jq for proper JSON escaping, fall back to python if jq unavailable
if command -v jq &>/dev/null; then
  CONTEXT=$(printf '%s' "$PARTS" | jq -Rs .)
elif command -v python3 &>/dev/null; then
  CONTEXT=$(printf '%s' "$PARTS" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
else
  exit 0
fi

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": %s\n  }\n}\n' "$CONTEXT"

exit 0
