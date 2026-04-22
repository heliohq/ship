#!/usr/bin/env bash
set -u
# Ship auto stop gate — Ralph-style outer verifier for /ship:auto.
#
# Logic:
#   1. No active auto state → allow exit
#   2. Different session or subagent → allow exit
#   3. Active auto state, same session → run external verifier
#   4. TASK_COMPLETE → remove state file and allow exit
#   5. TASK_INCOMPLETE → block exit and feed missing work back into the loop
#   6. TASK_BLOCKED → allow exit, keep state file for resume
#
# State file: .ship/ship-auto.local.md (YAML frontmatter + description body)
# Returns {"decision":"block","reason":"..."} to prevent stop, or exits 0 to allow.

INPUT=$(cat)

# Ensure user-installed binaries (gh, ship, node) are on PATH.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_BOOTSTRAP="$_SCRIPT_DIR/path-bootstrap.sh"
[ -f "$_BOOTSTRAP" ] && source "$_BOOTSTRAP"
_PR_READINESS="$_SCRIPT_DIR/pr-readiness.sh"
[ -f "$_PR_READINESS" ] && source "$_PR_READINESS"

# Verifier subprocesses bypass Ship hooks entirely to avoid recursive stop loops.
[ "${SHIP_STOP_GATE_BYPASS:-0}" = "1" ] && exit 0

frontmatter_value() {
  local key="$1"
  echo "$FRONTMATTER" | grep "^${key}:" | head -1 | sed "s/^${key}: *//" | sed 's/^"\(.*\)"$/\1/' | tr -d '\r' || true
}

append_labeled_file() {
  local label="$1" file="$2" max_chars="$3"

  if [ ! -f "$file" ]; then
    return
  fi

  printf '\n## %s\n' "$label"
  printf 'Path: %s\n\n' "$file"

  local total_chars
  total_chars=$(wc -c < "$file" 2>/dev/null | tr -d ' ')

  if [ "$total_chars" -le "$max_chars" ]; then
    cat "$file"
    printf '\n'
    return
  fi

  head -c "$max_chars" "$file"
  printf '\n\n[truncated after %s chars; original size %s chars]\n' "$max_chars" "$total_chars"
}

collect_text_artifacts() {
  local task_dir="$1"

  [ ! -d "$task_dir" ] && return

  append_labeled_file "Spec" "$task_dir/plan/spec.md" 20000
  append_labeled_file "Plan" "$task_dir/plan/plan.md" 20000
  append_labeled_file "Review" "$task_dir/review.md" 16000
  append_labeled_file "Simplify" "$task_dir/simplify.md" 12000

  if [ -d "$task_dir/qa" ]; then
    local qa_file
    for qa_file in "$task_dir"/qa/*.md "$task_dir"/qa/*.txt "$task_dir"/qa/*.log; do
      [ -f "$qa_file" ] || continue
      append_labeled_file "QA Artifact" "$qa_file" 16000
    done
  fi
}

build_verifier_prompt() {
  local task_dir="$1"
  local git_status diff_stat changed_files diff_content artifact_tree text_artifacts

  git_status=$(git -C "$CWD" status --short 2>&1 || true)
  # Resolve diff base: origin/HEAD if available, else fall back to empty tree
  local diff_base="origin/HEAD"
  if ! git -C "$CWD" rev-parse origin/HEAD >/dev/null 2>&1; then
    diff_base=$(git -C "$CWD" hash-object -t tree /dev/null 2>/dev/null || echo "4b825dc642cb6eb9a060e54bf899d15006")
  fi
  diff_stat=$(git -C "$CWD" diff --stat "$diff_base"...HEAD 2>&1 || git -C "$CWD" diff --stat "$diff_base" HEAD 2>&1 || true)
  changed_files=$(git -C "$CWD" diff --name-only "$diff_base"...HEAD 2>&1 || git -C "$CWD" diff --name-only "$diff_base" HEAD 2>&1 || true)
  diff_content=$(git -C "$CWD" diff --no-ext-diff --unified=1 "$diff_base"...HEAD 2>&1 || git -C "$CWD" diff --no-ext-diff --unified=1 "$diff_base" HEAD 2>&1 | head -c 120000)
  artifact_tree=$(find "$task_dir" -maxdepth 3 -type f 2>/dev/null | sort || true)
  text_artifacts=$(collect_text_artifacts "$task_dir")

  cat <<EOF
You are Ship's external completion verifier for an active /ship:auto run.

Decide whether the user's requested task is fully complete based on the
original request, the current git diff, and the produced artifacts. Judge the
actual task outcome, not whether the worker claims it is done.

Return EXACTLY one of these formats and nothing else:

VERDICT: TASK_COMPLETE
SUMMARY: <one short sentence>

VERDICT: TASK_INCOMPLETE
MISSING:
- <specific missing item>
- <specific missing item>

VERDICT: TASK_BLOCKED
BLOCKER:
- <specific blocker>

Rules:
- Be strict. If the available evidence does not support completion, return TASK_INCOMPLETE.
- Prefer concrete missing work over vague critique.
- Only return TASK_BLOCKED for genuine external blockers or missing human decisions.
- Do not suggest implementation details unless they clarify what remains unfinished.

## Task Metadata
Task ID: $TASK_ID
Current phase: $PHASE
Branch: $BRANCH
Task dir: $task_dir

## Original User Request
$DESCRIPTION

## Git Status
$git_status

## Git Diff Stat
$diff_stat

## Changed Files
$changed_files

## Git Diff
$diff_content

## Artifact Tree
$artifact_tree
$text_artifacts
EOF
}

run_verifier() {
  local prompt_file err_file out_file rc task_dir
  task_dir="$CWD/.ship/tasks/$TASK_ID"
  prompt_file=$(mktemp)
  err_file=$(mktemp)
  out_file=$(mktemp)
  build_verifier_prompt "$task_dir" > "$prompt_file"

  if [ -n "${SHIP_AUTO_VERIFIER_CMD:-}" ]; then
    SHIP_STOP_GATE_BYPASS=1 bash -c "$SHIP_AUTO_VERIFIER_CMD" < "$prompt_file" > "$out_file" 2> "$err_file"
    rc=$?
  elif command -v codex >/dev/null 2>&1; then
    SHIP_STOP_GATE_BYPASS=1 codex exec \
      --sandbox read-only \
      --skip-git-repo-check \
      --output-last-message "$out_file" \
      < "$prompt_file" \
      > /dev/null 2> "$err_file"
    rc=$?
  elif command -v claude >/dev/null 2>&1; then
    SHIP_STOP_GATE_BYPASS=1 claude -p \
      --output-format text \
      --permission-mode bypassPermissions \
      < "$prompt_file" \
      > "$out_file" 2> "$err_file"
    rc=$?
  else
    echo "VERIFIER_ERROR: no verifier CLI available" > "$out_file"
    rc=1
  fi

  local output stderr_content
  output=$(cat "$out_file" 2>/dev/null || true)
  stderr_content=$(cat "$err_file" 2>/dev/null || true)

  rm -f "$prompt_file" "$err_file" "$out_file"

  if [ "$rc" -ne 0 ]; then
    printf 'VERIFIER_ERROR\n%s\n%s\n' "$output" "$stderr_content"
    return 1
  fi

  printf '%s' "$output"
}

verdict_line() {
  printf '%s\n' "$1" | grep '^VERDICT:' | head -1 | sed 's/^VERDICT:[[:space:]]*//' | tr -d '\r' || true
}

extract_section() {
  local heading="$1" text="$2"
  printf '%s\n' "$text" | awk -v heading="$heading" '
    $0 == heading { capture=1; next }
    capture && /^VERDICT:/ { next }
    capture && /^[A-Z_]+:/ { exit }
    capture { print }
  '
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
# Only gate the session that owns the active pipeline.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
STATE_SESSION=$(frontmatter_value "session_id")
if [ -n "$STATE_SESSION" ] && [ -n "$SESSION_ID" ] && [ "$STATE_SESSION" != "$SESSION_ID" ]; then
  exit 0
fi

# ── VALIDATE STATE ───────────────────────────────────────────
if [ -z "$PHASE" ] || [ -z "$TASK_ID" ]; then
  echo "⚠️  Ship auto: State file corrupted (missing phase or task_id). Removing." >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ── READ DESCRIPTION ─────────────────────────────────────────
DESCRIPTION=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")

# ── FAST-PATH CHECK ─────────────────────────────────────────
# With the code-driven orchestrator (v0.7+), the script manages phase
# transitions deterministically. If we're in a terminal state, trust it
# and skip the expensive external verifier call.
#
# Terminal conditions (allow exit without verifier):
#   1. phase=learn (pipeline already past handoff)
#   2. phase=handoff AND the task dir has handoff evidence (PR URL)


case "$PHASE" in
  learn)
    PR_READY_REASON=$(ship_pr_handoff_ready "$CWD" "$BRANCH" 2>&1) && exit 0

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
    ;;
  handoff)
    # Check for PR evidence (handoff) and merge readiness (both).
    # "Past handoff" does not mean the PR is merge-ready — the branch
    # could be behind main, CI could have failed, etc.
    TASK_DIR="$CWD/.ship/tasks/$TASK_ID"
    if [ ! -d "$TASK_DIR" ]; then
      :  # no PR evidence yet — fall through to verifier
    else
      PR_EVIDENCE=$(grep -rls 'github\.com.*pull/' "$TASK_DIR/" 2>/dev/null | head -1)
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
    fi
    ;;
esac

# ── RUN EXTERNAL VERIFIER ────────────────────────────────────
VERIFIER_OUTPUT=$(run_verifier)
VERIFIER_RC=$?

if [ "$VERIFIER_RC" -ne 0 ]; then
  REASON="[Ship] External auto verifier could not determine task completion. Do not exit yet.
Task: $TASK_ID
Current phase: $PHASE
Branch: $BRANCH

Continue the active /ship:auto run from the current repo state and try again.

Verifier output:
$VERIFIER_OUTPUT"
  block_with_reason "$REASON" "Ship verifier unavailable — continuing /ship:auto"
  exit 0
fi

VERDICT=$(verdict_line "$VERIFIER_OUTPUT")

case "$VERDICT" in
  TASK_COMPLETE)
    rm -f "$STATE_FILE"
    exit 0
    ;;
  TASK_BLOCKED)
    BLOCKER=$(extract_section "BLOCKER:" "$VERIFIER_OUTPUT")
    echo "🛑 Ship auto verifier: task blocked." >&2
    [ -n "$BLOCKER" ] && printf '%s\n' "$BLOCKER" >&2
    exit 0
    ;;
  TASK_INCOMPLETE)
    MISSING=$(extract_section "MISSING:" "$VERIFIER_OUTPUT")
    REASON="[Ship] External verifier determined the task is not complete yet.
Task: $TASK_ID
Current phase: $PHASE
Branch: $BRANCH

Continue the active /ship:auto run from the current state. Do not restart from scratch.

Missing work:
$MISSING"
    block_with_reason "$REASON" "Ship verifier: task incomplete — continue /ship:auto"
    exit 0
    ;;
  *)
    REASON="[Ship] External auto verifier returned an unrecognized verdict. Do not exit yet.
Task: $TASK_ID
Current phase: $PHASE

Continue the active /ship:auto run and try again.

Verifier output:
$VERIFIER_OUTPUT"
    block_with_reason "$REASON" "Ship verifier returned an invalid verdict"
    exit 0
    ;;
esac
