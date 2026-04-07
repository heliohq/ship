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
  emit "ACTION" "done"
  emit "MESSAGE" "$1"
}

emit_escalate() {
  local reason="$1" phase="${2:-}"
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

detect_base_branch() {
  local ref
  ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)
  if [ -n "$ref" ]; then
    echo "$ref" | sed 's|refs/remotes/origin/||'
  elif git rev-parse --verify origin/main >/dev/null 2>&1; then
    echo main
  elif git rev-parse --verify origin/master >/dev/null 2>&1; then
    echo master
  else
    git branch --show-current 2>/dev/null || echo main
  fi
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
  local task_id branch base_branch head_sha description task_dir
  task_id=$(state_get "task_id")
  branch=$(state_get "branch")
  base_branch=$(state_get "base_branch")
  head_sha=$(current_head)
  description=$(read_description)
  task_dir=".ship/tasks/$task_id"

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
  SHIP_T_BASE_BRANCH="$base_branch" \
  SHIP_T_HEAD_SHA="$head_sha" \
  SHIP_T_TASK_DIR="$task_dir" \
  SHIP_T_DESCRIPTION="$description" \
  SHIP_T_FINDINGS="$findings" \
  SHIP_T_OUTCOME="$outcome" \
  SHIP_T_EXTRA="$extra_context" \
  awk '
  BEGIN {
    task_id      = ENVIRON["SHIP_T_TASK_ID"]
    branch       = ENVIRON["SHIP_T_BRANCH"]
    base_branch  = ENVIRON["SHIP_T_BASE_BRANCH"]
    head_sha     = ENVIRON["SHIP_T_HEAD_SHA"]
    task_dir     = ENVIRON["SHIP_T_TASK_DIR"]
    description  = ENVIRON["SHIP_T_DESCRIPTION"]
    findings     = ENVIRON["SHIP_T_FINDINGS"]
    outcome      = ENVIRON["SHIP_T_OUTCOME"]
    extra        = ENVIRON["SHIP_T_EXTRA"]
  }
  {
    gsub(/\{\{TASK_ID\}\}/, task_id)
    gsub(/\{\{BRANCH\}\}/, branch)
    gsub(/\{\{BASE_BRANCH\}\}/, base_branch)
    gsub(/\{\{HEAD_SHA\}\}/, head_sha)
    gsub(/\{\{TASK_DIR\}\}/, task_dir)
    gsub(/\{\{DESCRIPTION\}\}/, description)
    gsub(/\{\{FINDINGS\}\}/, findings)
    gsub(/\{\{OUTCOME\}\}/, outcome)
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
  local task_id base_branch task_dir
  task_id=$(state_get "task_id")
  base_branch=$(state_get "base_branch")
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
      local diff_count
      diff_count=$(git diff --name-only "$base_branch"...HEAD 2>/dev/null | wc -l | tr -d ' ')
      [ "$diff_count" -gt 0 ] || { echo "no code changes on branch"; return 1; }
      ;;
    review)
      file_exists_nonempty "$task_dir/review.md" || { echo "review.md missing or empty"; return 1; }
      ;;
    qa)
      [ -d "$task_dir/qa" ] && [ -n "$(find "$task_dir/qa" -maxdepth 1 \( -name '*.md' -o -name '*.txt' -o -name '*.log' -o -name '*.png' \) -type f 2>/dev/null | head -1)" ] \
        || { echo "no QA reports in $task_dir/qa/"; return 1; }
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
    review)           echo "review" ;;
    qa)               echo "qa" ;;
    qa_recheck)       echo "qa-recheck" ;;
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
    emit_error "Active task already exists. Use 'resume' instead."
    exit 1
  fi

  local task_id
  task_id=$(bash "$TASK_ID_SCRIPT" "$description" 2>/dev/null)
  if [ -z "$task_id" ]; then
    emit_error "Failed to generate task ID"
    exit 1
  fi

  mkdir -p ".ship/tasks/$task_id"

  local base_branch
  base_branch=$(detect_base_branch)

  local cur_branch branch
  cur_branch=$(current_branch)
  if [ -z "$cur_branch" ] || [ "$cur_branch" = "$base_branch" ]; then
    if ! git checkout -b "ship/$task_id" "$base_branch" >/dev/null 2>&1; then
      git checkout -b "ship/$task_id" >/dev/null 2>&1
    fi
    branch="ship/$task_id"
  elif [ "$cur_branch" = "ship/$task_id" ]; then
    branch="$cur_branch"
  else
    emit_error "Current branch '$cur_branch' is unrelated to this new task. Switch to '$base_branch' first."
    exit 1
  fi

  local session_id
  session_id=$(resolve_session_id)

  local started_at
  started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  mkdir -p .ship
  cat > "$STATE_FILE" <<EOF
---
active: true
task_id: $task_id
session_id: $session_id
branch: $branch
base_branch: $base_branch
phase: design
review_fix_round: 0
qa_fix_round: 0
started_at: "$started_at"
---

$description
EOF

  init_local_retries

  local prompt_file
  prompt_file=$(generate_prompt "design")

  emit_dispatch "design" "$prompt_file" "[Auto] Task \"$task_id\" created. Starting design phase..."
}

# ── RESUME Command ──────────────────────────────────────────

cmd_resume() {
  require_state_file

  local task_id phase branch base_branch
  task_id=$(state_get "task_id")
  phase=$(state_get "phase")
  branch=$(state_get "branch")
  base_branch=$(state_get "base_branch")

  if [ -z "$task_id" ] || [ -z "$phase" ] || [ -z "$base_branch" ]; then
    emit_error "State file corrupted: missing task_id, phase, or base_branch"
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

  local task_id base_branch task_dir
  task_id=$(state_get "task_id")
  base_branch=$(state_get "base_branch")
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
      state_set "phase" "review"
      local pf; pf=$(generate_prompt "review")
      emit_dispatch "review" "$pf" "[Auto] Dev complete. Starting review..."
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
      state_set "phase" "qa"
      local pf; pf=$(generate_prompt "qa-recheck")
      emit_dispatch "qa" "$pf" "[Auto] QA fixes applied. Re-testing..."
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

  local task_id phase branch base_branch rfr qfr head_sha
  task_id=$(state_get "task_id")
  phase=$(state_get "phase")
  branch=$(state_get "branch")
  base_branch=$(state_get "base_branch")
  rfr=$(state_get "review_fix_round")
  qfr=$(state_get "qa_fix_round")
  head_sha=$(current_head)

  if [ "$json_mode" -eq 1 ]; then
    printf '{"active":true,"task_id":"%s","phase":"%s","branch":"%s","base_branch":"%s","review_fix_round":%s,"qa_fix_round":%s,"head":"%s"}\n' \
      "$task_id" "$phase" "$branch" "$base_branch" "${rfr:-0}" "${qfr:-0}" "$head_sha"
  else
    emit "TASK_ID" "$task_id"
    emit "PHASE" "$phase"
    emit "BRANCH" "$branch"
    emit "BASE_BRANCH" "$base_branch"
    emit "REVIEW_FIX_ROUND" "${rfr:-0}"
    emit "QA_FIX_ROUND" "${qfr:-0}"
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
