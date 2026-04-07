#!/usr/bin/env bash
set -u

# Ship phase guardrail — PreToolUse hook that enforces artifact access
# rules per pipeline phase.
#
# Only active when .ship/ship-auto.local.md exists (auto pipeline running).
# Only gates subagent calls (agent_id present), not the orchestrator itself.
#
# Rules:
#   QA phase:     block Read of review.md and plan.md (independence)
#   Review phase: block Write/Edit of source code (review finds, doesn't fix)
#   QA phase:     block Write/Edit of source code (QA reports, doesn't fix)
#   All phases:   block Write/Edit of .ship/ship-auto.local.md (auto owns state)

INPUT=$(cat)

STATE_FILE=".ship/ship-auto.local.md"

# Only active during auto pipeline
[ -f "$STATE_FILE" ] || exit 0

# Only gate subagents, not the orchestrator
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
[ -n "$AGENT_ID" ] || exit 0

TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only care about file-access tools
case "$TOOL" in
  Read|Write|Edit) ;;
  *) exit 0 ;;
esac

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
[ -n "$FILE_PATH" ] || exit 0

# Read current phase
PHASE=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" \
  | grep "^phase:" | head -1 \
  | sed 's/^phase: *//' | sed 's/^"\(.*\)"$/\1/' | tr -d '\r')

[ -n "$PHASE" ] || exit 0

# Normalize file path for matching
BASENAME=$(basename "$FILE_PATH")

block() {
  local reason="$1"
  jq -n --arg reason "$reason" '{"decision":"block","reason":$reason}'
}

# ── Rule 1: QA must not read review.md or plan.md ────────────
if [ "$PHASE" = "qa" ] || [ "$PHASE" = "qa_fix" ]; then
  if [ "$TOOL" = "Read" ]; then
    case "$BASENAME" in
      review.md)
        block "[Ship guardrail] QA phase cannot read review.md — breaks independence"
        exit 0
        ;;
      plan.md)
        block "[Ship guardrail] QA phase cannot read plan.md — breaks independence"
        exit 0
        ;;
    esac
  fi
fi

# ── Rule 2: Review must not write source code ────────────────
if [ "$PHASE" = "review" ]; then
  if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
    # Allow writing review artifacts
    case "$FILE_PATH" in
      *.ship/tasks/*/review.md) ;;  # review's own artifact
      *.ship/*) ;;                   # other .ship metadata
      *)
        block "[Ship guardrail] Review phase cannot modify source code — report findings only"
        exit 0
        ;;
    esac
  fi
fi

# ── Rule 3: QA must not write source code ────────────────────
if [ "$PHASE" = "qa" ]; then
  if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
    case "$FILE_PATH" in
      *.ship/tasks/*/qa/*) ;;  # QA's own artifacts
      *.ship/*) ;;              # other .ship metadata
      /tmp/*) ;;                # temp files
      *)
        block "[Ship guardrail] QA phase cannot modify source code — report findings only"
        exit 0
        ;;
    esac
  fi
fi

# ── Rule 4: No subagent may write the state file ─────────────
if [ "$TOOL" = "Write" ] || [ "$TOOL" = "Edit" ]; then
  case "$FILE_PATH" in
    *ship-auto.local.md)
      block "[Ship guardrail] Only the orchestrator may modify .ship/ship-auto.local.md"
      exit 0
      ;;
  esac
fi

# All checks passed
exit 0
