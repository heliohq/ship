#!/bin/bash
# Ship post-compact — re-inject task state into context after compaction.
# Derives state from artifacts on disk (no task_state.json).
# Returns {"additionalContext":"..."} to restore task awareness.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[ -z "$CWD" ] && exit 0

# ── STATE FILE CHECK ──────────────────────────────────────────
# No active ship-coding session → skip post-compact injection
STATE_FILE="$CWD/.claude/ship-coding.local.md"
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Session isolation
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
STATE_SESSION=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" \
  | grep '^session_id:' | sed 's/session_id: *//' | tr -d '"')
if [ -n "$STATE_SESSION" ] && [ -n "$SESSION_ID" ] && [ "$STATE_SESSION" != "$SESSION_ID" ]; then
  exit 0
fi

REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")

# Find active task directory (most recent under .ship/tasks/)
TASK_DIR=$(find "$REPO_ROOT/.ship/tasks" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
[ -z "$TASK_DIR" ] && exit 0

TASK_ID=$(basename "$TASK_DIR")

# Derive phase from artifacts
PHASE="bootstrap"
[ -s "$TASK_DIR/plan/spec.md" ] && [ -s "$TASK_DIR/plan/plan.md" ] && PHASE="implementing"
[ -s "$TASK_DIR/review.md" ] && PHASE="verifying"
[ -s "$TASK_DIR/verify.md" ] && PHASE="qa/simplify"
[ -s "$TASK_DIR/qa.md" ] && [ -s "$TASK_DIR/simplify.md" ] && PHASE="handoff"

# Check artifact status
ARTIFACTS=""
for f in "$TASK_DIR"/*.md "$TASK_DIR"/plan/*.md; do
  [ ! -e "$f" ] && continue
  NAME=$(basename "$f")
  if [ -s "$f" ]; then
    ARTIFACTS="$ARTIFACTS $NAME(filled)"
  else
    ARTIFACTS="$ARTIFACTS $NAME(EMPTY)"
  fi
done

# Count commits since main
COMMITS=$(git -C "$REPO_ROOT" rev-list --count main..HEAD 2>/dev/null || echo 0)

CONTEXT="[Ship task state restored after compaction]
Task ID: $TASK_ID | Derived phase: $PHASE | Commits since main: $COMMITS
Artifacts:$ARTIFACTS
Task dir: $TASK_DIR
Derive your current phase from which artifacts exist. You are the orchestrator — delegate all codebase work to subagents."

jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
