#!/usr/bin/env bash
set -u
# Ship workflow stop gate — mechanical exit gate for /ship:auto.
#
# The orchestrator's state machine is the source of truth:
#   - emit_done archives the state file when the workflow completes
#   - emit_escalate archives it when a run blocks on the user
# So an EXISTING state file means work remains, by definition.
#
# Logic:
#   1. No active auto state → allow exit (completed, escalated, or never started)
#   2. Different session or subagent → allow exit
#   3. phase=handoff with PR evidence → allow iff the PR is merge-ready
#   4. Any other active phase → block: continue /ship:auto from current state
#
# No LLM verifier here (removed 2026-07-02): a model call can only
# re-derive what the state machine already knows — or hallucinate
# TASK_COMPLETE and delete a live run. Upstream evidence: superpowers
# v5.0.6 measured LLM artifact verification at ~25 min/run for zero
# quality gain.
#
# State file: .ship/ship-auto.local.md (YAML frontmatter + description body)
# Returns {"decision":"block","reason":"..."} to prevent stop, or exits 0 to allow.

INPUT=$(cat)

# Ensure user-installed binaries (gh, jq) are on PATH.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_BOOTSTRAP="$_SCRIPT_DIR/path-bootstrap.sh"
[ -f "$_BOOTSTRAP" ] && source "$_BOOTSTRAP"
_PR_READINESS="$_SCRIPT_DIR/pr-readiness.sh"
[ -f "$_PR_READINESS" ] && source "$_PR_READINESS"

# Escape hatch for tooling that must exit despite an active run.
[ "${SHIP_STOP_GATE_BYPASS:-0}" = "1" ] && exit 0

frontmatter_value() {
  local key="$1"
  echo "$FRONTMATTER" | grep "^${key}:" | head -1 | sed "s/^${key}: *//" | sed 's/^"\(.*\)"$/\1/' | tr -d '\r' || true
}

block_with_reason() {
  local reason="$1" system_message="$2"
  jq -n \
    --arg reason "$reason" \
    --arg systemMessage "$system_message" \
    '{"decision":"block","reason":$reason,"systemMessage":$systemMessage}'
}

# ── SUBAGENT BYPASS ──────────────────────────────────────────
# Subagents should never be blocked by the stop gate.
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // ""')
[ -n "$AGENT_ID" ] && exit 0

# ── STATE FILE CHECK ─────────────────────────────────────────
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[ -z "$CWD" ] && exit 0

STATE_FILE="$CWD/.ship/ship-auto.local.md"
[ ! -f "$STATE_FILE" ] && exit 0

# ── PARSE FRONTMATTER ────────────────────────────────────────
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")

PHASE=$(frontmatter_value "phase")
TASK_ID=$(frontmatter_value "task_id")
BRANCH=$(frontmatter_value "branch")

# ── SESSION ISOLATION ────────────────────────────────────────
# Only gate the session that owns the active workflow.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
STATE_SESSION=$(frontmatter_value "session_id")
if [ -n "$STATE_SESSION" ] \
  && [ "$STATE_SESSION" != "unknown" ] \
  && [ -n "$SESSION_ID" ] \
  && [ "$STATE_SESSION" != "$SESSION_ID" ]; then
  exit 0
fi

# ── VALIDATE STATE ───────────────────────────────────────────
if [ -z "$PHASE" ] || [ -z "$TASK_ID" ]; then
  echo "⚠️  Ship workflow: State file corrupted (missing phase or task_id). Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ── HANDOFF: MECHANICAL PR-READINESS CHECK ──────────────────
if [ "$PHASE" = "handoff" ]; then
  TASK_DIR="$CWD/.ship/tasks/$TASK_ID"
  PR_EVIDENCE=""
  [ -d "$TASK_DIR" ] && PR_EVIDENCE=$(grep -rls 'github\.com.*pull/' "$TASK_DIR/" 2>/dev/null | head -1)

  if [ -n "$PR_EVIDENCE" ]; then
    PR_READY_REASON=$(ship_pr_handoff_ready "$CWD" "$BRANCH" 2>&1) && exit 0

    # PR exists but is not handoff-ready — block with actionable hint
    MERGE_STATE=$(cd "$CWD" && gh pr view "$BRANCH" --json mergeStateStatus --jq '.mergeStateStatus' 2>/dev/null || echo "UNKNOWN")
    REASON="[Ship] PR is not handoff-ready (mergeStateStatus: $MERGE_STATE).
Task: $TASK_ID
Current phase: $PHASE
Branch: $BRANCH

$PR_READY_REASON

The PR needs to be updated before the pipeline can complete.
Sync with the base branch or resolve conflicts as needed, push, then resume /ship:auto."
    block_with_reason "$REASON" "Ship: PR not handoff-ready ($MERGE_STATE) — sync and resume"
    exit 0
  fi

  REASON="[Ship] Handoff phase is active but no PR evidence exists yet.
Task: $TASK_ID
Branch: $BRANCH

Continue the /ship:auto handoff phase: push the branch, create the PR, and drive checks to green. Do not restart from scratch."
  block_with_reason "$REASON" "Ship: handoff in progress — continuing /ship:auto"
  exit 0
fi

# ── ANY OTHER ACTIVE PHASE: WORK REMAINS BY DEFINITION ──────
# The orchestrator archives this state file on completion and on
# escalation; if it still exists, the pipeline has not finished.
REASON="[Ship] An active /ship:auto run is in progress.
Task: $TASK_ID
Current phase: $PHASE
Branch: $BRANCH

Continue the workflow from its current state (the auto skill's resume flow — auto-orchestrate.sh resume — emits the next dispatch). Do not restart from scratch.

To abandon the run instead: delete .ship/ship-auto.local.md and stop again."
block_with_reason "$REASON" "Ship: /ship:auto active (phase: $PHASE) — continuing"
exit 0
