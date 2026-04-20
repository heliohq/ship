#!/usr/bin/env bash
set -u

# Ship auto orchestrator — code-based state machine for /ship:auto.
#
# All deterministic logic lives here: state management, artifact validation,
# phase transitions, retry tracking, and prompt generation from templates.
# The LLM skill is a thin relay that dispatches Agent() calls and reports
# verdicts back to this script.
#
# Commands:
#   init "<description>"     Bootstrap a new task, output first dispatch action
#   resume                   Read state, output dispatch for current phase
#   complete <phase> --verdict=<V> [--summary="..."] [--findings-file=<path>]
#                            Validate artifacts, decide next action
#   status [--json]          Print current state (debugging)

_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$(dirname "$_SCRIPT_DIR")}}"

# Anchor all paths at repo root so invocations from subdirectories don't
# create duplicate .ship/ trees. Falls back to cwd if not in a git repo.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

STATE_FILE=".ship/ship-auto.local.md"
STATE_SCRIPT="${SHIP_PLUGIN_ROOT}/scripts/auto-state.sh"
TASK_ID_SCRIPT="${SHIP_PLUGIN_ROOT}/scripts/task-id.sh"
PROMPTS_DIR="${SHIP_PLUGIN_ROOT}/skills/auto/prompts"

MAX_RETRIES=3

# ── Output Protocol ─────────────────────────────────────────

emit() {
  local key="$1" value="$2"
  printf '%s:%s\n' "$key" "$value"
}

emit_dispatch() {
  local phase="$1" prompt_file="$2" message="$3"
  emit "ACTION" "dispatch"
  emit "PHASE" "$phase"
  emit "PROMPT_FILE" "$prompt_file"
  emit "MESSAGE" "$message"
}

emit_done() {
  # Archive the state file so init can start a fresh task.
  if [ -f "$STATE_FILE" ]; then
    local task_id
    task_id=$(state_get "task_id" 2>/dev/null || echo "unknown")
    local archive_dir=".ship/tasks/$task_id"
    mkdir -p "$archive_dir"
    mv "$STATE_FILE" "$archive_dir/ship-auto.completed.md"
  fi
  emit "ACTION" "done"
  emit "MESSAGE" "$1"
}

emit_escalate() {
  local reason="$1" phase="${2:-}"
  # Archive the state file so init can start a fresh task.
  # The task dir is preserved for inspection.
  if [ -f "$STATE_FILE" ]; then
    local task_id
    task_id=$(state_get "task_id" 2>/dev/null || echo "unknown")
    local archive_dir=".ship/tasks/$task_id"
    mkdir -p "$archive_dir"
    mv "$STATE_FILE" "$archive_dir/ship-auto.escalated.md"
  fi
  emit "ACTION" "escalate"
  emit "REASON" "$reason"
  [ -n "$phase" ] && emit "PHASE" "$phase"
}

emit_error() {
  emit "ACTION" "error"
  emit "MESSAGE" "$1"
}

# ── State Helpers ───────────────────────────────────────────

state_get() { bash "$STATE_SCRIPT" get "$1"; }
state_set() { bash "$STATE_SCRIPT" set "$1" "$2" > /dev/null; }
state_bump() { bash "$STATE_SCRIPT" bump "$1" > /dev/null; }

# Detect whether the task is refactor-shaped based on the leading verb
# of the description. Conservative: only mode-shifts on clear signals,
# defaults to "full" for everything else. Refactor mode skips the
# design phase's execution drill (Phase 6) but keeps peer investigation.
detect_scope_mode() {
  local description="$1"
  if printf '%s' "$description" \
    | grep -Eqi '^[[:space:]]*(refactor(ing)?|simplify|optimi[sz]e|clean[[:space:]]?up|rename|extract|dedupe|deduplicate|reorganis?e|restructure|tidy)\b'; then
    echo "refactor"
  else
    echo "full"
  fi
}

require_state_file() {
  if [ ! -f "$STATE_FILE" ]; then
    emit_error "No active task. State file not found: $STATE_FILE"
    exit 1
  fi
}

read_description() {
  awk '/^---$/{i++; next} i>=2' "$STATE_FILE"
}

# ── Git Helpers ─────────────────────────────────────────────

has_branch_changes() {
  # Check if the current branch has commits diverging from origin's default.
  [ "$(git log --oneline origin/HEAD..HEAD 2>/dev/null | wc -l | tr -d ' ')" -gt 0 ]
}

current_head() {
  git rev-parse HEAD 2>/dev/null || echo "unknown"
}

current_branch() {
  git branch --show-current 2>/dev/null || echo ""
}

resolve_session_id() {
  local sid
  sid="$(cat .ship/session-id.local 2>/dev/null || printf '%s' "${SHIP_SESSION_ID:-${CLAUDE_CODE_SESSION_ID:-${CODEX_SESSION_ID:-unknown}}}")"
  sid="$(printf '%s' "$sid" | tr -d '\r\n')"
  [ -n "$sid" ] || sid="unknown"
  printf '%s' "$sid"
}

# ── Template Engine ─────────────────────────────────────────

generate_prompt() {
  local template_name="$1"
  local task_id branch head_sha description task_dir scope_mode
  task_id=$(state_get "task_id")
  branch=$(state_get "branch")
  head_sha=$(current_head)
  description=$(read_description)
  task_dir=".ship/tasks/$task_id"
  scope_mode=$(state_get "scope_mode")
  [ -z "$scope_mode" ] && scope_mode="full"

  local template_file="${PROMPTS_DIR}/${template_name}.md.tmpl"
  if [ ! -f "$template_file" ]; then
    emit_error "Template not found: $template_file"
    exit 1
  fi

  local prompt_dir="${task_dir}/prompts"
  mkdir -p "$prompt_dir"
  local out_file="${prompt_dir}/${template_name}.md"

  local findings="" outcome="" extra_context=""
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --findings-file=*)
        local ff="${1#--findings-file=}"
        [ -f "$ff" ] && findings=$(cat "$ff")
        ;;
      --outcome=*) outcome="${1#--outcome=}" ;;
      --extra=*) extra_context="${1#--extra=}" ;;
    esac
    shift
  done

  SHIP_T_TASK_ID="$task_id" \
  SHIP_T_BRANCH="$branch" \
  SHIP_T_HEAD_SHA="$head_sha" \
  SHIP_T_TASK_DIR="$task_dir" \
  SHIP_T_DESCRIPTION="$description" \
  SHIP_T_FINDINGS="$findings" \
  SHIP_T_OUTCOME="$outcome" \
  SHIP_T_EXTRA="$extra_context" \
  SHIP_T_SCOPE_MODE="$scope_mode" \
  awk '
  BEGIN {
    task_id      = ENVIRON["SHIP_T_TASK_ID"]
    branch       = ENVIRON["SHIP_T_BRANCH"]
    head_sha     = ENVIRON["SHIP_T_HEAD_SHA"]
    task_dir     = ENVIRON["SHIP_T_TASK_DIR"]
    description  = ENVIRON["SHIP_T_DESCRIPTION"]
    findings     = ENVIRON["SHIP_T_FINDINGS"]
    outcome      = ENVIRON["SHIP_T_OUTCOME"]
    extra        = ENVIRON["SHIP_T_EXTRA"]
    scope_mode   = ENVIRON["SHIP_T_SCOPE_MODE"]
  }
  {
    gsub(/\{\{TASK_ID\}\}/, task_id)
    gsub(/\{\{BRANCH\}\}/, branch)
    gsub(/\{\{HEAD_SHA\}\}/, head_sha)
    gsub(/\{\{TASK_DIR\}\}/, task_dir)
    gsub(/\{\{DESCRIPTION\}\}/, description)
    gsub(/\{\{FINDINGS\}\}/, findings)
    gsub(/\{\{OUTCOME\}\}/, outcome)
    gsub(/\{\{SCOPE_MODE\}\}/, scope_mode)
    gsub(/\{\{EXTRA_CONTEXT\}\}/, extra)
    print
  }' "$template_file" > "$out_file"

  printf '%s' "$out_file"
}

# ── Artifact Validation ────────────────────────────────────

file_exists_nonempty() { [ -f "$1" ] && [ -s "$1" ]; }

dir_has_files() {
  local dir="$1" pattern="${2:-*}"
  [ -d "$dir" ] && [ -n "$(find "$dir" -maxdepth 1 -name "$pattern" -type f 2>/dev/null | head -1)" ]
}

validate_artifacts() {
  local phase="$1"
  local task_id task_dir
  task_id=$(state_get "task_id")
  task_dir=".ship/tasks/$task_id"

  case "$phase" in
    design)
      file_exists_nonempty "$task_dir/plan/spec.md" || { echo "spec.md missing or empty"; return 1; }
      file_exists_nonempty "$task_dir/plan/plan.md" || { echo "plan.md missing or empty"; return 1; }
      # Spec must have acceptance criteria
      grep -qi "acceptance\|criteria\|requirements\|must\|should" "$task_dir/plan/spec.md" \
        || { echo "spec.md lacks acceptance criteria"; return 1; }
      # Plan must have at least one story/task
      grep -qiE "^##|^-|^[0-9]+\." "$task_dir/plan/plan.md" \
        || { echo "plan.md has no stories or tasks"; return 1; }
      # Peer evaluation artifacts are always required (no focused/broad split)
      file_exists_nonempty "$task_dir/plan/peer-spec.md" \
        || { echo "peer-spec.md missing — peer evaluation did not run"; return 1; }
      file_exists_nonempty "$task_dir/plan/diff-report.md" \
        || { echo "diff-report.md missing — spec divergence resolution did not run"; return 1; }
      ;;
    dev|dev_fix)
      has_branch_changes || { echo "no code changes on branch"; return 1; }
      ;;
    review)
      file_exists_nonempty "$task_dir/review.md" || { echo "review.md missing or empty"; return 1; }
      ;;
    qa)
      [ -d "$task_dir/qa" ] && [ -n "$(find "$task_dir/qa" -maxdepth 1 \( -name '*.md' -o -name '*.txt' -o -name '*.log' -o -name '*.png' \) -type f 2>/dev/null | head -1)" ] \
        || { echo "no QA reports in $task_dir/qa/"; return 1; }
      ;;
    e2e)
      # SKIP is allowed — validated only if there's an e2e/ directory.
      # If the skill decided to skip (docs-only diff etc.), it writes a
      # report.md with a justification and the verdict is 'skip'.
      if [ -d "$task_dir/e2e" ]; then
        file_exists_nonempty "$task_dir/e2e/report.md" \
          || { echo "e2e/report.md missing or empty"; return 1; }
      fi
      ;;
    handoff)
      # Deep check: use gh CLI to verify PR status if available
      if command -v gh >/dev/null 2>&1; then
        local branch; branch=$(state_get "branch")
        local pr_state
        pr_state=$(gh pr view "$branch" --json state,statusCheckRollup --jq '.state' 2>/dev/null || true)
        if [ -n "$pr_state" ] && [ "$pr_state" != "OPEN" ] && [ "$pr_state" != "MERGED" ]; then
          echo "PR is $pr_state, not OPEN or MERGED"; return 1
        fi
      fi
      ;;
    simplify)
      file_exists_nonempty "$task_dir/simplify.md" || { echo "simplify.md missing or empty"; return 1; }
      ;;
    learn) ;;
  esac
  return 0
}

# ── Retry Logic ─────────────────────────────────────────────

LOCAL_RETRY_FILE=""

init_local_retries() {
  LOCAL_RETRY_FILE=$(mktemp /tmp/ship-auto-retries-XXXXXX)
  trap "rm -f '$LOCAL_RETRY_FILE'" EXIT
}

get_retry_count() {
  local phase="$1"
  case "$phase" in
    review_fix) state_get "review_fix_round" ;;
    qa_fix)     state_get "qa_fix_round" ;;
    e2e_fix)    state_get "e2e_fix_round" ;;
    *)
      if [ -n "$LOCAL_RETRY_FILE" ] && [ -f "$LOCAL_RETRY_FILE" ]; then
        grep "^${phase}:" "$LOCAL_RETRY_FILE" 2>/dev/null | cut -d: -f2 || echo 0
      else
        echo 0
      fi
      ;;
  esac
}

bump_retry_count() {
  local phase="$1"
  case "$phase" in
    review_fix) state_bump "review_fix_round" ;;
    qa_fix)     state_bump "qa_fix_round" ;;
    e2e_fix)    state_bump "e2e_fix_round" ;;
    *)
      if [ -n "$LOCAL_RETRY_FILE" ]; then
        local current next
        current=$(get_retry_count "$phase")
        next=$((current + 1))
        grep -v "^${phase}:" "$LOCAL_RETRY_FILE" > "${LOCAL_RETRY_FILE}.tmp" 2>/dev/null || true
        echo "${phase}:${next}" >> "${LOCAL_RETRY_FILE}.tmp"
        mv "${LOCAL_RETRY_FILE}.tmp" "$LOCAL_RETRY_FILE"
      fi
      ;;
  esac
}

phase_template() {
  case "$1" in
    design)           echo "design" ;;
    dev)              echo "dev" ;;
    review_fix)       echo "dev-fix" ;;
    qa_fix)           echo "dev-fix" ;;
    e2e_fix)          echo "dev-fix" ;;
    review)           echo "review" ;;
    qa)               echo "qa" ;;
    qa_recheck)       echo "qa-recheck" ;;
    e2e)              echo "e2e" ;;
    e2e_recheck)      echo "e2e-recheck" ;;
    simplify)         echo "simplify" ;;
    # simplify_verify removed — simplify handles its own verification
    handoff)          echo "handoff" ;;
    learn)            echo "learn" ;;
    *)                echo "" ;;
  esac
}

# ── INIT Command ────────────────────────────────────────────

cmd_init() {
  local description="$1"

  if [ -f "$STATE_FILE" ]; then
    # Check if the old task's branch still exists — if not, state is stale.
    local old_branch
    old_branch=$(awk '/^branch:/{print $2}' "$STATE_FILE" 2>/dev/null)
    if [ -n "$old_branch" ] && git rev-parse --verify --quiet "$old_branch" >/dev/null 2>&1; then
      emit_error "Active task already exists. Use 'resume' instead, or delete $STATE_FILE to start fresh."
      exit 1
    else
      # Stale state — branch is gone (merged/deleted). Archive and continue.
      local old_task_id
      old_task_id=$(awk '/^task_id:/{print $2}' "$STATE_FILE" 2>/dev/null || echo "unknown")
      local archive_dir=".ship/tasks/$old_task_id"
      mkdir -p "$archive_dir"
      mv "$STATE_FILE" "$archive_dir/ship-auto.stale.md"
      emit "INFO" "Cleared stale task '$old_task_id' (branch '$old_branch' no longer exists)."
    fi
  fi

  local task_id
  task_id=$(bash "$TASK_ID_SCRIPT" "$description" 2>/dev/null)
  if [ -z "$task_id" ]; then
    emit_error "Failed to generate task ID"
    exit 1
  fi

  mkdir -p ".ship/tasks/$task_id"

  local cur_branch branch
  cur_branch=$(current_branch)
  # Check if we're on the remote's default branch (by name, not commits —
  # a fresh feature branch with no commits should still be kept).
  local is_default=false
  if [ -z "$cur_branch" ]; then
    is_default=true
  else
    local default_ref
    default_ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
    [ "$cur_branch" = "${default_ref:-main}" ] && is_default=true
  fi

  if $is_default; then
    git checkout -b "ship/$task_id" origin/HEAD >/dev/null 2>&1 \
      || git checkout -b "ship/$task_id" >/dev/null 2>&1
    branch="ship/$task_id"
  else
    # On a feature branch — stay on it
    branch="$cur_branch"
  fi

  local session_id
  session_id=$(resolve_session_id)

  local started_at
  started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local scope_mode
  scope_mode=$(detect_scope_mode "$description")

  mkdir -p .ship
  cat > "$STATE_FILE" <<EOF
---
active: true
task_id: $task_id
session_id: $session_id
branch: $branch
phase: design
scope_mode: $scope_mode
review_fix_round: 0
qa_fix_round: 0
e2e_fix_round: 0
post_qa_fix: false
started_at: "$started_at"
---

$description
EOF

  init_local_retries

  local prompt_file
  prompt_file=$(generate_prompt "design")

  emit_dispatch "design" "$prompt_file" "[Auto] Task \"$task_id\" created (scope: $scope_mode). Starting design phase..."
}

# ── RESUME Command ──────────────────────────────────────────

cmd_resume() {
  require_state_file

  local task_id phase branch
  task_id=$(state_get "task_id")
  phase=$(state_get "phase")
  branch=$(state_get "branch")

  if [ -z "$task_id" ] || [ -z "$phase" ]; then
    emit_error "State file corrupted: missing task_id or phase"
    exit 1
  fi

  local session_id
  session_id=$(resolve_session_id)
  state_set "session_id" "$session_id"

  if ! git rev-parse --verify --quiet "$branch" >/dev/null 2>&1; then
    emit_error "Task branch '$branch' not found. Cannot resume."
    exit 1
  fi
  git checkout "$branch" >/dev/null 2>&1

  init_local_retries

  local dispatch_phase="$phase"
  local extra_args=""

  case "$phase" in
    review_fix)
      dispatch_phase="review_fix"
      local task_dir=".ship/tasks/$task_id"
      [ -f "$task_dir/review.md" ] && extra_args="--findings-file=$task_dir/review.md"
      ;;
    qa_fix)
      dispatch_phase="qa_fix"
      local task_dir=".ship/tasks/$task_id"
      local latest_qa
      latest_qa=$(find "$task_dir/qa/" -name "*.md" -type f 2>/dev/null | sort | tail -1)
      [ -n "$latest_qa" ] && extra_args="--findings-file=$latest_qa"
      ;;
    e2e_fix)
      dispatch_phase="e2e_fix"
      local task_dir=".ship/tasks/$task_id"
      [ -f "$task_dir/e2e/report.md" ] && extra_args="--findings-file=$task_dir/e2e/report.md"
      ;;
  esac

  local template
  template=$(phase_template "$dispatch_phase")
  [ -z "$template" ] && { emit_error "Unknown phase: $phase"; exit 1; }

  local prompt_file
  if [ -n "$extra_args" ]; then
    prompt_file=$(generate_prompt "$template" "$extra_args")
  else
    prompt_file=$(generate_prompt "$template")
  fi

  emit_dispatch "$dispatch_phase" "$prompt_file" "[Auto] Resuming task \"$task_id\" — phase: $phase"
}

# ── COMPLETE Command ────────────────────────────────────────

cmd_complete() {
  require_state_file

  local phase="" verdict="" summary="" findings_file=""
  phase="$1"; shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --verdict=*)  verdict="${1#--verdict=}" ;;
      --summary=*)  summary="${1#--summary=}" ;;
      --findings-file=*) findings_file="${1#--findings-file=}" ;;
    esac
    shift
  done

  [ -z "$phase" ] || [ -z "$verdict" ] && { emit_error "Usage: complete <phase> --verdict=<V>"; exit 1; }

  local task_id task_dir
  task_id=$(state_get "task_id")
  task_dir=".ship/tasks/$task_id"

  if [ "$verdict" = "success" ] || [ "$verdict" = "findings" ]; then
    local validation_err
    validation_err=$(validate_artifacts "$phase" 2>&1)
    if [ $? -ne 0 ] && [ -n "$validation_err" ]; then
      verdict="fail"
      summary="Artifact validation failed: $validation_err"
    fi
  fi

  # Deterministic override: if the relay says review passed but review.md
  # contains P1/P2 findings, force the verdict to "findings".
  if [ "$phase" = "review" ] && [ "$verdict" = "success" ]; then
    if [ -f "$task_dir/review.md" ] && grep -qiE '\bP[12][-:]' "$task_dir/review.md"; then
      verdict="findings"
      findings_file="$task_dir/review.md"
      summary="Review contains P1/P2 findings (relay misclassified as success)"
    fi
  fi

  case "${phase}:${verdict}" in
    design:success)
      # Design skill has its own internal evaluation (peer investigation, diff-report,
      # execution drill). Artifact validation already checks spec quality and peer
      # eval completeness. No separate evaluator needed.
      state_set "phase" "dev"
      state_set "pre_dev_sha" "$(current_head)"
      local pf; pf=$(generate_prompt "dev")
      emit_dispatch "dev" "$pf" "[Auto] Design complete. Starting dev..."
      ;;
    design:fail|design:blocked) retry_or_escalate "design" "$summary" ;;

    dev:success)
      state_set "phase" "e2e"
      local pf; pf=$(generate_prompt "e2e")
      emit_dispatch "e2e" "$pf" "[Auto] Dev complete. Writing E2E tests..."
      ;;
    dev:fail|dev:blocked) retry_or_escalate "dev" "$summary" ;;

    review:success)
      state_set "phase" "qa"
      local pf; pf=$(generate_prompt "qa")
      emit_dispatch "qa" "$pf" "[Auto] Review clean. Starting QA..."
      ;;
    review:findings)
      local round; round=$(state_get "review_fix_round")
      if [ "${round:-0}" -ge "$MAX_RETRIES" ]; then
        dispatch_learn_then_escalate "Review fix exhausted after $MAX_RETRIES rounds. $summary"
      else
        state_set "phase" "review_fix"
        local ff_arg=""
        [ -n "$findings_file" ] && [ -f "$findings_file" ] && ff_arg="--findings-file=$findings_file"
        [ -z "$ff_arg" ] && [ -f "$task_dir/review.md" ] && ff_arg="--findings-file=$task_dir/review.md"
        if [ -z "$ff_arg" ]; then
          # No findings file available — retry review instead of dispatching empty fix
          retry_or_escalate "review" "findings reported but no findings file available"
        else
          local pf; pf=$(generate_prompt "dev-fix" ${ff_arg:+"$ff_arg"})
          emit_dispatch "review_fix" "$pf" "[Auto] Review found issues (round $((round + 1))/$MAX_RETRIES). Fixing..."
        fi
      fi
      ;;
    review:fail|review:blocked) retry_or_escalate "review" "$summary" ;;

    dev_fix:success|review_fix:success)
      state_set "phase" "review"
      local pf; pf=$(generate_prompt "review")
      emit_dispatch "review" "$pf" "[Auto] Review fixes applied. Re-reviewing..."
      ;;
    dev_fix:fail|dev_fix:blocked|review_fix:fail|review_fix:blocked)
      state_bump "review_fix_round"
      local round; round=$(state_get "review_fix_round")
      if [ "$round" -ge "$MAX_RETRIES" ]; then
        dispatch_learn_then_escalate "Review fix failed after $MAX_RETRIES rounds. $summary"
      else
        local ff_arg=""
        [ -n "$findings_file" ] && ff_arg="--findings-file=$findings_file"
        [ -z "$findings_file" ] && [ -f "$task_dir/review.md" ] && ff_arg="--findings-file=$task_dir/review.md"
        local pf; pf=$(generate_prompt "dev-fix" ${ff_arg:+"$ff_arg"})
        emit_dispatch "review_fix" "$pf" "[Auto] Review fix retry (round $round/$MAX_RETRIES)..."
      fi
      ;;

    qa:success|qa:skip)
      state_set "phase" "simplify"
      state_set "pre_simplify_sha" "$(current_head)"
      local pf; pf=$(generate_prompt "simplify")
      emit_dispatch "simplify" "$pf" "[Auto] QA passed. Running simplify..."
      ;;
    qa:fail)
      local round; round=$(state_get "qa_fix_round")
      if [ "${round:-0}" -ge "$MAX_RETRIES" ]; then
        dispatch_learn_then_escalate "QA fix exhausted after $MAX_RETRIES rounds. $summary"
      else
        state_set "phase" "qa_fix"
        local ff_arg=""
        [ -n "$findings_file" ] && ff_arg="--findings-file=$findings_file"
        local pf; pf=$(generate_prompt "dev-fix" ${ff_arg:+"$ff_arg"})
        emit_dispatch "qa_fix" "$pf" "[Auto] QA failed (round $((round + 1))/$MAX_RETRIES). Fixing..."
      fi
      ;;
    qa:blocked) retry_or_escalate "qa" "$summary" ;;

    qa_fix:success)
      # QA fix changed code — re-run the committed E2E suite as a regression
      # gate before the manual QA recheck. This mirrors how real CI runs on
      # every commit and catches cases where a fix for a QA-reported issue
      # accidentally breaks a previously-passing E2E test. The `post_qa_fix`
      # flag tells the e2e:success handler to route to qa-recheck rather than
      # back to review (which already passed earlier in the pipeline).
      state_set "phase" "e2e"
      state_set "post_qa_fix" "true"
      local pf; pf=$(generate_prompt "e2e-recheck")
      emit_dispatch "e2e" "$pf" "[Auto] QA fixes applied. Running E2E regression gate..."
      ;;
    qa_fix:fail|qa_fix:blocked)
      state_bump "qa_fix_round"
      local round; round=$(state_get "qa_fix_round")
      if [ "$round" -ge "$MAX_RETRIES" ]; then
        dispatch_learn_then_escalate "QA fix failed after $MAX_RETRIES rounds. $summary"
      else
        local ff_arg=""
        [ -n "$findings_file" ] && ff_arg="--findings-file=$findings_file"
        local pf; pf=$(generate_prompt "dev-fix" ${ff_arg:+"$ff_arg"})
        emit_dispatch "qa_fix" "$pf" "[Auto] QA fix retry (round $round/$MAX_RETRIES)..."
      fi
      ;;

    e2e:success|e2e:skip)
      if [ "$(state_get "post_qa_fix")" = "true" ]; then
        # Returning from the regression gate that was inserted after a qa_fix.
        # Review already passed earlier — don't re-run it. Go straight to the
        # QA recheck so the human-like exploratory sweep confirms the fix.
        state_set "post_qa_fix" "false"
        state_set "phase" "qa"
        local pf; pf=$(generate_prompt "qa-recheck")
        emit_dispatch "qa" "$pf" "[Auto] E2E regression gate passed. Re-running QA..."
      else
        # Normal forward flow: fresh e2e after dev → review.
        state_set "phase" "review"
        local pf; pf=$(generate_prompt "review")
        emit_dispatch "review" "$pf" "[Auto] E2E tests green. Starting review..."
      fi
      ;;
    e2e:fail)
      local round; round=$(state_get "e2e_fix_round")
      if [ "${round:-0}" -ge "$MAX_RETRIES" ]; then
        dispatch_learn_then_escalate "E2E fix exhausted after $MAX_RETRIES rounds. $summary"
      else
        state_set "phase" "e2e_fix"
        local ff_arg=""
        [ -n "$findings_file" ] && ff_arg="--findings-file=$findings_file"
        [ -z "$ff_arg" ] && [ -f "$task_dir/e2e/report.md" ] && ff_arg="--findings-file=$task_dir/e2e/report.md"
        local pf; pf=$(generate_prompt "dev-fix" ${ff_arg:+"$ff_arg"})
        emit_dispatch "e2e_fix" "$pf" "[Auto] E2E failed (round $((round + 1))/$MAX_RETRIES). Fixing..."
      fi
      ;;
    e2e:blocked) retry_or_escalate "e2e" "$summary" ;;

    e2e_fix:success)
      state_set "phase" "e2e"
      local pf; pf=$(generate_prompt "e2e-recheck")
      emit_dispatch "e2e" "$pf" "[Auto] E2E fixes applied. Re-testing..."
      ;;
    e2e_fix:fail|e2e_fix:blocked)
      state_bump "e2e_fix_round"
      local round; round=$(state_get "e2e_fix_round")
      if [ "$round" -ge "$MAX_RETRIES" ]; then
        dispatch_learn_then_escalate "E2E fix failed after $MAX_RETRIES rounds. $summary"
      else
        local ff_arg=""
        [ -n "$findings_file" ] && ff_arg="--findings-file=$findings_file"
        [ -z "$findings_file" ] && [ -f "$task_dir/e2e/report.md" ] && ff_arg="--findings-file=$task_dir/e2e/report.md"
        local pf; pf=$(generate_prompt "dev-fix" ${ff_arg:+"$ff_arg"})
        emit_dispatch "e2e_fix" "$pf" "[Auto] E2E fix retry (round $round/$MAX_RETRIES)..."
      fi
      ;;

    simplify:success)
      # Simplify handles its own verification internally (runs tests after changes,
      # reverts if broken). simplify.md must exist (validated above).
      state_set "phase" "handoff"
      local pf; pf=$(generate_prompt "handoff")
      emit_dispatch "handoff" "$pf" "[Auto] Simplify done. Starting handoff..."
      ;;
    simplify:fail|simplify:blocked|simplify:skip)
      # No skip allowed — simplify must always produce simplify.md.
      # Even if nothing changed, the agent should write a brief summary.
      retry_or_escalate "simplify" "$summary"
      ;;

    handoff:success)
      state_set "phase" "learn"
      local pf; pf=$(generate_prompt "learn" "--outcome=completed")
      emit_dispatch "learn" "$pf" "[Auto] Handoff complete. Capturing learnings..."
      ;;
    handoff:fail|handoff:blocked) retry_or_escalate "handoff" "$summary" ;;

    learn:*)
      local esc_reason esc_phase
      esc_reason=$(state_get "escalation_reason")
      esc_phase=$(state_get "escalation_phase")
      if [ -n "$esc_reason" ]; then
        emit_escalate "$esc_reason" "$esc_phase"
      else
        emit_done "[Auto] Pipeline complete. $summary"
      fi
      ;;

    *) emit_error "Unknown phase:verdict combination: ${phase}:${verdict}" ;;
  esac
}

retry_or_escalate() {
  local phase="$1" reason="${2:-}"
  bump_retry_count "$phase"
  local count
  count=$(get_retry_count "$phase")
  if [ "$count" -ge "$MAX_RETRIES" ]; then
    dispatch_learn_then_escalate "$phase blocked after $MAX_RETRIES retries. $reason"
  else
    local template pf
    template=$(phase_template "$phase")
    pf=$(generate_prompt "$template" "--extra=$reason")
    emit_dispatch "$phase" "$pf" "[Auto] Retrying $phase (attempt $count/$MAX_RETRIES)..."
  fi
}

dispatch_learn_then_escalate() {
  local reason="$1"
  local orig_phase
  orig_phase=$(state_get "phase")
  state_set "phase" "learn"
  state_set "escalation_reason" "$reason"
  state_set "escalation_phase" "$orig_phase"
  local pf; pf=$(generate_prompt "learn" "--outcome=escalated at $orig_phase")
  emit_dispatch "learn" "$pf" "[Auto] Capturing learnings before escalation..."
}

# ── STATUS Command ──────────────────────────────────────────

cmd_status() {
  local json_mode=0
  while [ $# -gt 0 ]; do
    case "$1" in --json) json_mode=1 ;; esac
    shift
  done

  if [ ! -f "$STATE_FILE" ]; then
    if [ "$json_mode" -eq 1 ]; then printf '{"active":false}\n'; else echo "No active task."; fi
    exit 0
  fi

  local task_id phase branch rfr qfr efr head_sha
  task_id=$(state_get "task_id")
  phase=$(state_get "phase")
  branch=$(state_get "branch")
  rfr=$(state_get "review_fix_round")
  qfr=$(state_get "qa_fix_round")
  efr=$(state_get "e2e_fix_round")
  head_sha=$(current_head)

  if [ "$json_mode" -eq 1 ]; then
    printf '{"active":true,"task_id":"%s","phase":"%s","branch":"%s","review_fix_round":%s,"qa_fix_round":%s,"e2e_fix_round":%s,"head":"%s"}\n' \
      "$task_id" "$phase" "$branch" "${rfr:-0}" "${qfr:-0}" "${efr:-0}" "$head_sha"
  else
    emit "TASK_ID" "$task_id"
    emit "PHASE" "$phase"
    emit "BRANCH" "$branch"
    emit "REVIEW_FIX_ROUND" "${rfr:-0}"
    emit "QA_FIX_ROUND" "${qfr:-0}"
    emit "E2E_FIX_ROUND" "${efr:-0}"
    emit "HEAD" "$head_sha"
  fi
}

# ── Main Dispatch ───────────────────────────────────────────

COMMAND="${1:-}"
shift 2>/dev/null || true

case "$COMMAND" in
  init)
    description="${1:-}"
    [ -z "$description" ] && { emit_error "Usage: auto-orchestrate.sh init \"<description>\""; exit 1; }
    cmd_init "$description"
    ;;
  resume)   cmd_resume ;;
  complete) cmd_complete "$@" ;;
  status)   cmd_status "$@" ;;
  *)        emit_error "Usage: auto-orchestrate.sh {init|resume|complete|status}"; exit 1 ;;
esac
