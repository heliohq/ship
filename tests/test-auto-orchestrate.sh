#!/usr/bin/env bash
set -u

# ── Test harness for auto-orchestrate.sh ────────────────────
# Simulates the full pipeline state machine with mock data.
# Validates: init, phase transitions, artifact validation overrides,
# retry/escalation, fix loops, resume, and terminal states.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ORCH="${SCRIPT_DIR}/scripts/auto-orchestrate.sh"
TEST_DIR=$(mktemp -d /tmp/ship-test-XXXXXX)
PASS=0
FAIL=0
TOTAL=0

cd "$TEST_DIR"
git init -q
git commit --allow-empty -m "init" -q

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# ── Helpers ──────────────────────────────────────────────────

parse_output() {
  local output="$1"
  ACTION=$(echo "$output" | grep "^ACTION:" | head -1 | cut -d: -f2-)
  PHASE=$(echo "$output" | grep "^PHASE:" | head -1 | cut -d: -f2-)
  PROMPT_FILE=$(echo "$output" | grep "^PROMPT_FILE:" | head -1 | cut -d: -f2-)
  MESSAGE=$(echo "$output" | grep "^MESSAGE:" | head -1 | cut -d: -f2-)
  REASON=$(echo "$output" | grep "^REASON:" | head -1 | cut -d: -f2-)
}

assert_eq() {
  TOTAL=$((TOTAL + 1))
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    printf "  ✓ %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ✗ %s: expected '%s', got '%s'\n" "$label" "$expected" "$actual"
  fi
}

assert_contains() {
  TOTAL=$((TOTAL + 1))
  local label="$1" needle="$2" haystack="$3"
  if echo "$haystack" | grep -q "$needle"; then
    PASS=$((PASS + 1))
    printf "  ✓ %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ✗ %s: '%s' not found in '%s'\n" "$label" "$needle" "$haystack"
  fi
}

assert_file_exists() {
  TOTAL=$((TOTAL + 1))
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    PASS=$((PASS + 1))
    printf "  ✓ %s\n" "$label"
  else
    FAIL=$((FAIL + 1))
    printf "  ✗ %s: file not found: %s\n" "$label" "$path"
  fi
}

get_state() {
  local key="$1"
  bash "${SCRIPT_DIR}/scripts/auto-state.sh" get "$key"
}

reset_state() {
  rm -f .ship/ship-auto.local.md
  rm -rf .ship/tasks
  git checkout -q -B main 2>/dev/null || true
}

# Create a mock task-id.sh that returns a predictable ID
mock_task_id() {
  mkdir -p "${SCRIPT_DIR}/scripts"
  # The real task-id.sh exists; we'll use env to override if needed
  :
}

# ── Test Suites ──────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "  /ship:auto orchestrator test suite"
echo "═══════════════════════════════════════════════════"
echo ""

# ── Test 1: Init creates state file and dispatches design ────
echo "▸ Test 1: Init command"
reset_state

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" init "add dark mode toggle" 2>/dev/null)
RC=$?

assert_eq "init exits 0" "0" "$RC"
parse_output "$OUT"
assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is design" "design" "$PHASE"
assert_file_exists "prompt file created" "$PROMPT_FILE"
assert_file_exists "state file created" ".ship/ship-auto.local.md"
assert_eq "state phase is design" "design" "$(get_state phase)"

TASK_ID=$(get_state task_id)
assert_contains "task ID not empty" "." "$TASK_ID"

# Check prompt contains template variables substituted
if [ -f "$PROMPT_FILE" ]; then
  PROMPT_CONTENT=$(cat "$PROMPT_FILE")
  assert_contains "prompt has task_id" "$TASK_ID" "$PROMPT_CONTENT"
  assert_contains "prompt has description" "dark mode" "$PROMPT_CONTENT"

  # Should NOT have raw template vars
  TOTAL=$((TOTAL + 1))
  if echo "$PROMPT_CONTENT" | grep -q '{{TASK_ID}}'; then
    FAIL=$((FAIL + 1))
    printf "  ✗ prompt still has {{TASK_ID}} template var\n"
  else
    PASS=$((PASS + 1))
    printf "  ✓ template vars substituted\n"
  fi
fi

echo ""

# ── Test 2: Complete design:success → dev ────────────────────
echo "▸ Test 2: Design success → Dev dispatch"

# Create mock artifacts (all design artifacts required — no focused/broad split)
TASK_DIR=".ship/tasks/$TASK_ID"
mkdir -p "$TASK_DIR/plan"
printf '# Spec\n## Acceptance Criteria\n- Must work\n' > "$TASK_DIR/plan/spec.md"
printf '# Plan\n## Story 1\n- Implement feature\n' > "$TASK_DIR/plan/plan.md"
printf '# Peer Spec\n## Acceptance Criteria\n- Must work\n' > "$TASK_DIR/plan/peer-spec.md"
printf '# Diff Report\n## Resolved\n- All aligned\n' > "$TASK_DIR/plan/diff-report.md"

# Need a diff for dev validation later — create a dummy commit
echo "test" > dummy.txt
git add dummy.txt && git commit -q -m "dummy"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="3 stories" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is dev" "dev" "$PHASE"
assert_eq "state advanced to dev" "dev" "$(get_state phase)"
assert_file_exists "dev prompt created" "$PROMPT_FILE"

echo ""

# ── Test 3: Complete dev:success → review ────────────────────
echo "▸ Test 3: Dev success → Review dispatch"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete dev --verdict=success --summary="3/3 stories done" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is review" "review" "$PHASE"
assert_eq "state advanced to review" "review" "$(get_state phase)"

echo ""

# ── Test 4: Review with findings → review_fix ────────────────
echo "▸ Test 4: Review findings → Dev-Fix dispatch"

# Create review artifact
echo "# Review\nP1: null check missing" > "$TASK_DIR/review.md"

# Create findings file
FINDINGS_FILE=$(mktemp /tmp/ship-findings-XXXXXX.md)
echo "P1: null check missing in useTheme" > "$FINDINGS_FILE"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete review --verdict=findings --summary="1 P1 bug" --findings-file="$FINDINGS_FILE" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is review_fix" "review_fix" "$PHASE"
assert_eq "state is review_fix" "review_fix" "$(get_state phase)"
assert_eq "review_fix_round stays 0 (bumps on fix fail)" "0" "$(get_state review_fix_round)"

# Check fix prompt contains findings
if [ -f "$PROMPT_FILE" ]; then
  assert_contains "fix prompt has findings" "null check" "$(cat "$PROMPT_FILE")"
fi

rm -f "$FINDINGS_FILE"
echo ""

# ── Test 5: Review fix success → back to review ─────────────
echo "▸ Test 5: Review fix success → Re-review"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete review_fix --verdict=success --summary="bug fixed" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is review" "review" "$PHASE"
assert_eq "state back to review" "review" "$(get_state phase)"

echo ""

# ── Test 6: Clean review → QA ────────────────────────────────
echo "▸ Test 6: Clean review → QA dispatch"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete review --verdict=success --summary="clean" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is qa" "qa" "$PHASE"
assert_eq "state advanced to qa" "qa" "$(get_state phase)"

echo ""

# ── Test 7: QA pass → simplify ───────────────────────────────
echo "▸ Test 7: QA pass → Simplify dispatch"

# Create QA artifact
mkdir -p "$TASK_DIR/qa"
echo "# Browser Report\nAll pass" > "$TASK_DIR/qa/browser-report.md"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete qa --verdict=success --summary="all criteria pass" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is simplify" "simplify" "$PHASE"
assert_eq "state advanced to simplify" "simplify" "$(get_state phase)"

echo ""

# ── Test 8: Simplify success → handoff ───────────────────────
echo "▸ Test 8: Simplify success → Handoff dispatch"

# simplify.md must exist for success
TASK_ID_T8=$(get_state task_id)
echo "# Simplify\nNo changes needed — code is clean." > ".ship/tasks/$TASK_ID_T8/simplify.md"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete simplify --verdict=success --summary="code already clean" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is handoff" "handoff" "$PHASE"
assert_eq "state advanced to handoff" "handoff" "$(get_state phase)"

echo ""

# ── Test 9: Handoff success → learn ──────────────────────────
echo "▸ Test 9: Handoff success → Learn dispatch"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete handoff --verdict=success --summary="PR #42 green" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is learn" "learn" "$PHASE"
assert_eq "state advanced to learn" "learn" "$(get_state phase)"

echo ""

# ── Test 10: Learn → done ────────────────────────────────────
echo "▸ Test 10: Learn complete → Done"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete learn --verdict=success --summary="2 learnings captured" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is done" "done" "$ACTION"
assert_contains "done message" "Pipeline complete" "$MESSAGE"

echo ""

# ── Test 11: Artifact validation override ────────────────────
echo "▸ Test 11: Artifact validation overrides LLM verdict"
reset_state
git checkout -q -B main 2>/dev/null

# Init a new task
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" init "test artifact validation" 2>/dev/null)
TASK_ID=$(get_state task_id)
TASK_DIR=".ship/tasks/$TASK_ID"

# DON'T create spec.md/plan.md — design artifacts missing
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="design done" 2>/dev/null)
parse_output "$OUT"

# Script should override to retry because artifacts are missing
assert_eq "action is dispatch (retry)" "dispatch" "$ACTION"
assert_eq "phase still design" "design" "$PHASE"
assert_contains "message mentions retry" "Retrying" "$MESSAGE"

echo ""

# ── Test 12: QA fail → qa_fix loop ──────────────────────────
echo "▸ Test 12: QA fail → QA fix loop"
reset_state
git checkout -q -B main 2>/dev/null

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" init "test qa fix loop" 2>/dev/null)
TASK_ID=$(get_state task_id)
TASK_DIR=".ship/tasks/$TASK_ID"

# Fast-forward to QA phase
mkdir -p "$TASK_DIR/plan" "$TASK_DIR/qa"
printf '# Spec\n## Acceptance Criteria\n- Must work\n' > "$TASK_DIR/plan/spec.md"
printf '# Plan\n## Story 1\n- Implement feature\n' > "$TASK_DIR/plan/plan.md"
printf '# Peer Spec\n## Criteria\n- Must work\n' > "$TASK_DIR/plan/peer-spec.md"
printf '# Diff Report\n## Resolved\n- Aligned\n' > "$TASK_DIR/plan/diff-report.md"
echo "test" > dummy2.txt && git add dummy2.txt && git commit -q -m "dummy2"

bash "${SCRIPT_DIR}/scripts/auto-state.sh" set phase qa > /dev/null

# Create QA report then report fail
echo "FAIL: localStorage not set" > "$TASK_DIR/qa/browser-report.md"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete qa --verdict=fail --summary="localStorage missing" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is qa_fix" "qa_fix" "$PHASE"
assert_eq "state is qa_fix" "qa_fix" "$(get_state phase)"
assert_eq "qa_fix_round stays 0 (bumps on fix fail)" "0" "$(get_state qa_fix_round)"

echo ""

# ── Test 13: QA fix success → qa recheck ────────────────────
echo "▸ Test 13: QA fix success → QA recheck"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete qa_fix --verdict=success --summary="fixed localStorage" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is qa" "qa" "$PHASE"
assert_eq "state back to qa" "qa" "$(get_state phase)"

# Check it uses the recheck template
if [ -f "$PROMPT_FILE" ]; then
  assert_contains "uses recheck prompt" "recheck" "$(cat "$PROMPT_FILE")"
fi

echo ""

# ── Test 14: Resume from mid-pipeline ────────────────────────
echo "▸ Test 14: Resume from qa phase"

# State is already at qa from test 13
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" resume 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_contains "phase is qa-related" "qa" "$PHASE"
assert_contains "message mentions resume" "Resuming" "$MESSAGE"

echo ""

# ── Test 15: Simplify fail → retry (not skip) ────────────────
echo "▸ Test 15: Simplify fail retries (simplify.md required)"
reset_state
git checkout -q -B main 2>/dev/null

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" init "test simplify fail" 2>/dev/null)
TASK_ID=$(get_state task_id)
TASK_DIR=".ship/tasks/$TASK_ID"

mkdir -p "$TASK_DIR/plan" "$TASK_DIR/qa"
printf '# Spec\n## Acceptance Criteria\n- Must work\n' > "$TASK_DIR/plan/spec.md"
printf '# Plan\n## Story 1\n- Implement feature\n' > "$TASK_DIR/plan/plan.md"
printf '# Peer Spec\n## Criteria\n- Must work\n' > "$TASK_DIR/plan/peer-spec.md"
printf '# Diff Report\n## Resolved\n- Aligned\n' > "$TASK_DIR/plan/diff-report.md"
echo "report" > "$TASK_DIR/qa/report.md"
echo "test" > dummy3.txt && git add dummy3.txt && git commit -q -m "dummy3"
echo "review" > "$TASK_DIR/review.md"
bash "${SCRIPT_DIR}/scripts/auto-state.sh" set phase simplify > /dev/null

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete simplify --verdict=fail --summary="simplify crashed" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch (retry)" "dispatch" "$ACTION"
assert_eq "phase is simplify (retry)" "simplify" "$PHASE"
assert_contains "message mentions retry" "Retrying" "$MESSAGE"

echo ""

# ── Test 16: Status command ──────────────────────────────────
echo "▸ Test 16: Status command"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" status 2>/dev/null)
assert_contains "status has TASK_ID" "TASK_ID" "$OUT"
assert_contains "status has PHASE" "PHASE:simplify" "$OUT"

echo ""

# ── Test 17: Escalation after 3 retries ──────────────────────
echo "▸ Test 17: Escalation after 3× review fix rounds"
reset_state
git checkout -q -B main 2>/dev/null

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" init "test escalation" 2>/dev/null)
TASK_ID=$(get_state task_id)
TASK_DIR=".ship/tasks/$TASK_ID"
mkdir -p "$TASK_DIR/plan"
printf '# Spec\n## Acceptance Criteria\n- Must work\n' > "$TASK_DIR/plan/spec.md"
printf '# Plan\n## Story 1\n- Implement feature\n' > "$TASK_DIR/plan/plan.md"
printf '# Peer Spec\n## Criteria\n- Must work\n' > "$TASK_DIR/plan/peer-spec.md"
printf '# Diff Report\n## Resolved\n- Aligned\n' > "$TASK_DIR/plan/diff-report.md"
echo "test" > dummy4.txt && git add dummy4.txt && git commit -q -m "dummy4"
echo "P1: bug" > "$TASK_DIR/review.md"

# Set phase to review with review_fix_round=3 (3 fix failures already happened).
# The next review:findings should trigger escalation (round >= MAX_RETRIES).
bash "${SCRIPT_DIR}/scripts/auto-state.sh" set phase review > /dev/null
bash "${SCRIPT_DIR}/scripts/auto-state.sh" set review_fix_round 3 > /dev/null

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete review --verdict=findings --summary="still buggy" 2>/dev/null)
parse_output "$OUT"

# dispatch_learn_then_escalate now dispatches learn first (not escalate directly)
assert_eq "action is dispatch (learn before escalate)" "dispatch" "$ACTION"
assert_eq "phase is learn" "learn" "$PHASE"

# Complete learn → should now emit escalate with original phase
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete learn --verdict=success --summary="learnings captured" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is escalate" "escalate" "$ACTION"
assert_contains "reason mentions exhausted" "exhausted" "$REASON"

echo ""

# ── Summary ──────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════"
printf "  Results: %d/%d passed" "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf "  (%d FAILED)" "$FAIL"
fi
echo ""
echo "═══════════════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
