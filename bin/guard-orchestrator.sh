#!/bin/bash
# Ship orchestrator guard — blocks dangerous Bash patterns during ship-coding.
# Write/Edit enforcement is at skill level (allowed-tools), not here,
# because plugin hooks cannot distinguish orchestrator from subagent.
# Receives PreToolUse JSON on stdin.
#
# CONDITIONAL: Only active when .claude/ship-coding.local.md exists.
# This allows the hook to be registered at plugin level without
# affecting non-ship-coding sessions.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[ -z "$CWD" ] && exit 0

# ── STATE FILE CHECK ──────────────────────────────────────────
# No active ship-coding session → allow everything
STATE_FILE="$CWD/.claude/ship-coding.local.md"
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

# Session isolation: only enforce for the session that started ship-coding
STATE_SESSION=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" \
  | grep '^session_id:' | sed 's/session_id: *//' | tr -d '"')
if [ -n "$STATE_SESSION" ] && [ -n "$SESSION_ID" ] && [ "$STATE_SESSION" != "$SESSION_ID" ]; then
  exit 0
fi

# ── GUARD LOGIC (only runs when ship-coding is active) ────────

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# ── Write/Edit: enforced at skill level, not here ──────────────
# ship-coding SKILL.md does not include Write/Edit in allowed-tools,
# so the orchestrator cannot write. Subagents define their own tools
# and must not be blocked by this plugin-level hook.
# (Previously this was ALWAYS DENY, but plugin hooks cannot distinguish
# orchestrator from subagent — both run in the same workspace.)

# ── Bash guard ───────────────────────────────────────────────────
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
  CMD_STRIPPED=$(echo "$COMMAND" | sed 's/^timeout [0-9]* //')

  # Block ANY command that writes files via redirection
  if echo "$CMD_STRIPPED" | grep -qE '>\s|>>\s|tee\s'; then
    deny "You are the orchestrator — you cannot write files via shell redirection. Use 'codex exec' to implement, or dispatch a subagent for other phases."
  fi

  # Allowed commands (read-only or delegation)
  case "$CMD_STRIPPED" in
    codex\ exec*|codex\ *) exit 0 ;;
    claude\ -p*|claude\ --print*) exit 0 ;;
    git\ *) exit 0 ;;
    gh\ *) exit 0 ;;
    mkdir\ *) exit 0 ;;
    cat\ *|ls\ *|pwd) exit 0 ;;
    echo\ *) exit 0 ;;   # stdout-only (redirection blocked above)
    jq\ *) exit 0 ;;
    find\ *) exit 0 ;;
    wc\ *|head\ *|tail\ *) exit 0 ;;
    command\ *) exit 0 ;;
    # Allow setup script
    *setup-ship-coding.sh*) exit 0 ;;
    # Allow reading state file
    *ship-coding.local.md*) exit 0 ;;
  esac
fi

# Allow everything else (Read, Agent, AskUserQuestion)
exit 0
