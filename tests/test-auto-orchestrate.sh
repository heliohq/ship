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

# has_branch_changes() in the orchestrator compares HEAD to origin/HEAD.
# The scratch repo has no origin — fake one by pointing origin/HEAD at the
# initial commit so any later commit registers as a branch change. Without
# this, the dev-phase artifact validator permanently reports "no code
# changes" and every dev:success verdict gets flipped to fail.
ROOT_SHA=$(git rev-parse HEAD)
git update-ref refs/remotes/origin/HEAD "$ROOT_SHA"
git update-ref refs/remotes/origin/main "$ROOT_SHA"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# ── Helpers ──────────────────────────────────────────────────

parse_output() {
  local output="$1"
  ACTION="" PHASE="" PROMPT_FILE="" MESSAGE="" REASON=""
  eval "$(echo "$output" | awk -F: '
    /^ACTION:/      { print "ACTION=\"" substr($0, index($0,":")+1) "\"" }
    /^PHASE:/       { print "PHASE=\"" substr($0, index($0,":")+1) "\"" }
    /^PROMPT_FILE:/ { print "PROMPT_FILE=\"" substr($0, index($0,":")+1) "\"" }
    /^MESSAGE:/     { print "MESSAGE=\"" substr($0, index($0,":")+1) "\"" }
    /^REASON:/      { print "REASON=\"" substr($0, index($0,":")+1) "\"" }
  ')"
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
  sed -n '/^---$/,/^---$/{ /^---$/d; p; }' .ship/ship-auto.local.md \
    | grep "^${key}:" \
    | head -1 \
    | sed "s/^${key}: *//" \
    | sed 's/^"\(.*\)"$/\1/' \
    | tr -d '\r' || true
}

set_state() {
  local key="$1" value="$2" tmp_file
  tmp_file=$(mktemp)
  awk -v key="$key" -v value="$value" '
    BEGIN { in_frontmatter = 0; replaced = 0 }
    NR == 1 && $0 == "---" { in_frontmatter = 1; print; next }
    in_frontmatter && $0 == "---" {
      if (!replaced) print key ": " value
      in_frontmatter = 0
      print
      next
    }
    in_frontmatter && $0 ~ ("^" key ":") {
      print key ": " value
      replaced = 1
      next
    }
    { print }
  ' .ship/ship-auto.local.md > "$tmp_file"
  mv "$tmp_file" .ship/ship-auto.local.md
}

reset_state() {
  rm -f .ship/ship-auto.local.md
  rm -rf .ship/tasks
  git checkout -q -B main 2>/dev/null || true
}

mock_ready_gh() {
  local bin_dir="$TEST_DIR/bin"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/gh" <<'GHEOF'
#!/usr/bin/env bash
set -u

if [ "$1" = "pr" ] && [ "${2:-}" = "view" ]; then
  printf '%s\n' '{"state":"OPEN","mergeStateStatus":"CLEAN","mergeable":"MERGEABLE"}'
elif [ "$1" = "pr" ] && [ "${2:-}" = "checks" ]; then
  printf '%s\n' '[{"name":"ci","state":"SUCCESS","bucket":"pass"}]'
else
  echo "unexpected gh args: $*" >&2
  exit 1
fi
GHEOF
  chmod +x "$bin_dir/gh"
  PATH="$bin_dir:$PATH"
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

OUT=$(bash "$ORCH" init "add dark mode toggle" 2>/dev/null)
RC=$?

assert_eq "init exits 0" "0" "$RC"
parse_output "$OUT"
assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is design" "design" "$PHASE"
assert_file_exists "prompt file created" "$PROMPT_FILE"
assert_file_exists "state file created" ".ship/ship-auto.local.md"
assert_file_exists "input requirement created" ".ship/tasks/$(get_state task_id)/input/requirement.md"
assert_file_exists "run state created" ".ship/tasks/$(get_state task_id)/control/run_state.yaml"
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

OUT=$(bash "$ORCH" complete design --verdict=success --summary="3 stories" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is dev" "dev" "$PHASE"
assert_eq "state advanced to dev" "dev" "$(get_state phase)"
assert_file_exists "dev prompt created" "$PROMPT_FILE"

echo ""

# ── Test 3: Dev ledger gate, then dev success → e2e ─────────
# Pipeline order is design → dev → e2e → review → qa → refactor → handoff.
# E2E runs before review so reviewers see green tests alongside the code.
echo "▸ Test 3: Dev ledger gate blocks partial completion"

# Plan has 1 story ("## Story 1") but the ledger records none complete —
# a dev that claims success without finishing must be retried.
printf 'Story 1: "mock" — in progress\n' > "$TASK_DIR/dev-ledger.md"
OUT=$(bash "$ORCH" complete dev --verdict=success --summary="claims done" 2>/dev/null)
parse_output "$OUT"

assert_eq "ledger gate: action is dispatch (retry)" "dispatch" "$ACTION"
assert_eq "ledger gate: phase still dev" "dev" "$PHASE"

echo "▸ Test 3 (cont): Dev success → E2E dispatch"

printf 'Story 1: "mock" — complete (commits abc1234..def5678, review clean)\n' > "$TASK_DIR/dev-ledger.md"
OUT=$(bash "$ORCH" complete dev --verdict=success --summary="3/3 stories done" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is e2e" "e2e" "$PHASE"
assert_eq "state advanced to e2e" "e2e" "$(get_state phase)"

echo ""

# ── Test 3b: E2E success → review ───────────────────────────
# Fresh e2e (no post_qa_fix flag) flows forward to review.
echo "▸ Test 3b: E2E success → Review dispatch"

mkdir -p "$TASK_DIR/e2e"
echo "# E2E Report" > "$TASK_DIR/e2e/report.md"

OUT=$(bash "$ORCH" complete e2e --verdict=success --summary="5 tests green" 2>/dev/null)
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

OUT=$(bash "$ORCH" complete review --verdict=findings --summary="1 P1 bug" --findings-file="$FINDINGS_FILE" 2>/dev/null)
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

OUT=$(bash "$ORCH" complete review_fix --verdict=success --summary="bug fixed" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is review" "review" "$PHASE"
assert_eq "state back to review" "review" "$(get_state phase)"

echo ""

# ── Test 6: Clean review → QA ────────────────────────────────
echo "▸ Test 6: Clean review → QA dispatch"

OUT=$(bash "$ORCH" complete review --verdict=success --summary="clean" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is qa" "qa" "$PHASE"
assert_eq "state advanced to qa" "qa" "$(get_state phase)"

echo ""

# ── Test 7: QA pass → refactor ───────────────────────────────
echo "▸ Test 7: QA pass → Refactor dispatch"

# Create QA artifact
mkdir -p "$TASK_DIR/qa"
echo "# Browser Report\nAll pass" > "$TASK_DIR/qa/browser-report.md"

OUT=$(bash "$ORCH" complete qa --verdict=success --summary="all criteria pass" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is refactor" "refactor" "$PHASE"
assert_eq "state advanced to refactor" "refactor" "$(get_state phase)"

echo ""

# ── Test 8: Refactor success → handoff ───────────────────────
echo "▸ Test 8: Refactor success → Handoff dispatch"

# refactor.md must exist for success
TASK_ID_T8=$(get_state task_id)
echo "# Refactor\nNo changes needed — code is clean." > ".ship/tasks/$TASK_ID_T8/refactor.md"

OUT=$(bash "$ORCH" complete refactor --verdict=success --summary="code already clean" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is handoff" "handoff" "$PHASE"
assert_eq "state advanced to handoff" "handoff" "$(get_state phase)"

echo ""

# ── Test 9: Handoff success → done ───────────────────────────
echo "▸ Test 9: Handoff success → Done"

mock_ready_gh
OUT=$(bash "$ORCH" complete handoff --verdict=success --summary="PR #42 green" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is done" "done" "$ACTION"
assert_contains "done message" "Workflow complete" "$MESSAGE"

echo ""

# ── Test 11: Artifact validation override ────────────────────
echo "▸ Test 11: Artifact validation overrides LLM verdict"
reset_state
git checkout -q -B main 2>/dev/null

# Init a new task
OUT=$(bash "$ORCH" init "test artifact validation" 2>/dev/null)
TASK_ID=$(get_state task_id)
TASK_DIR=".ship/tasks/$TASK_ID"

# DON'T create spec.md/plan.md — design artifacts missing
OUT=$(bash "$ORCH" complete design --verdict=success --summary="design done" 2>/dev/null)
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

OUT=$(bash "$ORCH" init "test qa fix loop" 2>/dev/null)
TASK_ID=$(get_state task_id)
TASK_DIR=".ship/tasks/$TASK_ID"

# Fast-forward to QA phase
mkdir -p "$TASK_DIR/plan" "$TASK_DIR/qa"
printf '# Spec\n## Acceptance Criteria\n- Must work\n' > "$TASK_DIR/plan/spec.md"
printf '# Plan\n## Story 1\n- Implement feature\n' > "$TASK_DIR/plan/plan.md"
printf '# Peer Spec\n## Criteria\n- Must work\n' > "$TASK_DIR/plan/peer-spec.md"
printf '# Diff Report\n## Resolved\n- Aligned\n' > "$TASK_DIR/plan/diff-report.md"
echo "test" > dummy2.txt && git add dummy2.txt && git commit -q -m "dummy2"

set_state phase qa

# Create QA report then report fail
echo "FAIL: localStorage not set" > "$TASK_DIR/qa/browser-report.md"

OUT=$(bash "$ORCH" complete qa --verdict=fail --summary="localStorage missing" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is qa_fix" "qa_fix" "$PHASE"
assert_eq "state is qa_fix" "qa_fix" "$(get_state phase)"
assert_eq "qa_fix_round stays 0 (bumps on fix fail)" "0" "$(get_state qa_fix_round)"

echo ""

# ── Test 13: QA fix success → e2e regression gate ──────────
# A qa_fix is a code change. Before the manual qa-recheck, we run the
# committed e2e suite as a regression gate to catch the case where the
# fix accidentally broke a previously-passing test. The post_qa_fix
# flag tells the e2e:success handler to route to qa-recheck (not
# review, which already passed earlier in the pipeline).
echo "▸ Test 13: QA fix success → E2E regression gate"

OUT=$(bash "$ORCH" complete qa_fix --verdict=success --summary="fixed localStorage" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is e2e (regression gate)" "e2e" "$PHASE"
assert_eq "state is e2e" "e2e" "$(get_state phase)"
assert_eq "post_qa_fix flag set" "true" "$(get_state post_qa_fix)"

# Regression gate uses the e2e-recheck template (not a fresh e2e)
if [ -f "$PROMPT_FILE" ]; then
  assert_contains "uses e2e-recheck prompt" "recheck" "$(cat "$PROMPT_FILE")"
fi

echo ""

# ── Test 14: Resume from mid-pipeline ────────────────────────
# Test 13 left state at e2e (regression gate). Reset to qa so we
# specifically cover the "resume from qa" code path, since the
# e2e-resume path is covered in test-e2e-phase.sh.
echo "▸ Test 14: Resume from qa phase"

set_state phase qa
set_state post_qa_fix false

OUT=$(bash "$ORCH" resume 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_contains "phase is qa-related" "qa" "$PHASE"
assert_contains "message mentions resume" "Resuming" "$MESSAGE"

echo ""

# ── Test 15: Refactor fail → retry (not skip) ────────────────
echo "▸ Test 15: Refactor fail retries (refactor.md required)"
reset_state
git checkout -q -B main 2>/dev/null

OUT=$(bash "$ORCH" init "test refactor fail" 2>/dev/null)
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
set_state phase refactor

OUT=$(bash "$ORCH" complete refactor --verdict=fail --summary="refactor crashed" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch (retry)" "dispatch" "$ACTION"
assert_eq "phase is refactor (retry)" "refactor" "$PHASE"
assert_contains "message mentions retry" "Retrying" "$MESSAGE"

echo ""

# ── Test 16: Status command ──────────────────────────────────
echo "▸ Test 16: Status command"

OUT=$(bash "$ORCH" status 2>/dev/null)
assert_contains "status has TASK_ID" "TASK_ID" "$OUT"
assert_contains "status has PHASE" "PHASE:refactor" "$OUT"

echo ""

# ── Test 17: Escalation after 3 retries ──────────────────────
echo "▸ Test 17: Escalation after 3× review fix rounds"
reset_state
git checkout -q -B main 2>/dev/null

OUT=$(bash "$ORCH" init "test escalation" 2>/dev/null)
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
set_state phase review
set_state review_fix_round 3

OUT=$(bash "$ORCH" complete review --verdict=findings --summary="still buggy" 2>/dev/null)
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
