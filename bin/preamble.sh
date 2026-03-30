#!/bin/bash
# Ship preamble — pre-flight checks, then setup.
# Called by ship-coding skill as the first step.
# Usage: bash preamble.sh <task_description> [cwd]

set -u

TASK_DESCRIPTION="${1:-}"
CWD="${2:-$PWD}"

# --- Pre-flight: CLI availability ---

if command -v codex &>/dev/null; then
  echo "DELEGATE_FAST=codex exec"
elif command -v claude &>/dev/null; then
  echo "DELEGATE_FAST=claude -p --model sonnet"
else
  echo "DELEGATE_FAST=AGENT_TOOL"
  echo "WARN: Neither codex nor claude CLI found. Will use Agent tool for delegation."
fi

if command -v claude &>/dev/null; then
  echo "DELEGATE_OPUS=claude -p"
else
  echo "DELEGATE_OPUS=AGENT_TOOL"
  echo "WARN: claude CLI not found. Will use Agent tool for opus-level delegation."
fi

# --- Pre-flight: gh CLI ---
if command -v gh &>/dev/null; then
  echo "GH_AVAILABLE=true"
else
  echo "GH_AVAILABLE=false"
  echo "WARN: gh CLI not found. PR creation will be skipped — push branch only."
fi

# --- Pre-flight: ship-init check ---
if [ ! -f "$CWD/AGENTS.md" ] && [ ! -f "$CWD/CLAUDE.md" ]; then
  echo "SHIP_INIT_NEEDED=true"
  echo "WARN: No AGENTS.md or CLAUDE.md found. Consider running /ship-init for better results."
else
  echo "SHIP_INIT_NEEDED=false"
fi

# --- Setup (state file + repo detection + git hooks) ---
# Only /ship:auto needs the full pipeline setup (state file, stop gate, guard).
# Other skills (setup, debug, review, etc.) just need the pre-flight checks above.
# Non-pipeline skills pass a known keyword; auto passes the user's task description.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
NON_PIPELINE_SKILLS="setup debug refactor review clean test qa plan implement handoff"
if [ -n "$TASK_DESCRIPTION" ] && [[ " $NON_PIPELINE_SKILLS " != *" $TASK_DESCRIPTION "* ]]; then
  bash "$SCRIPT_DIR/setup-ship-coding.sh" "$TASK_DESCRIPTION" "$CWD"
fi
