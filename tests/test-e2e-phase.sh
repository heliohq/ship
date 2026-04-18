#!/usr/bin/env bash
set -u

# ── Regression tests for the new e2e phase in auto-orchestrate.sh ──
# Covers the three behaviors introduced alongside skills/e2e/:
#   1. Forward pipeline reorder: dev→e2e→review, qa_pass→simplify,
#      simplify→handoff (e2e slots between dev and review).
#   2. e2e phase machinery: e2e/e2e_fix/e2e_recheck in cmd_complete,
#      e2e_fix_round state key, artifact validation accepting SKIP.
#   3. Regression gate after qa_fix: qa_fix:success routes through e2e
#      (not straight to qa-recheck), e2e:success with post_qa_fix=true
#      routes to qa-recheck, flag clears after handover.

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ORCH="${SCRIPT_DIR}/scripts/auto-orchestrate.sh"
TEST_DIR=$(mktemp -d /tmp/ship-e2e-test-XXXXXX)
PASS=0
FAIL=0
TOTAL=0

cd "$TEST_DIR"
git init -q
git commit --allow-empty -m "init" -q
# has_branch_changes compares HEAD to origin/HEAD — in this scratch repo we
# fake origin by pointing origin/HEAD at the original root commit, so any
# later commit registers as a branch change.
ROOT_SHA=$(git rev-parse HEAD)
git update-ref refs/remotes/origin/HEAD "$ROOT_SHA"
git update-ref refs/remotes/origin/main "$ROOT_SHA"

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# ── Helpers (copied from test-auto-orchestrate.sh for consistency) ──

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

get_state() {
  bash "${SCRIPT_DIR}/scripts/auto-state.sh" get "$1"
}

set_state() {
  bash "${SCRIPT_DIR}/scripts/auto-state.sh" set "$1" "$2" > /dev/null
}

reset_state() {
  rm -f .ship/ship-auto.local.md
  rm -rf .ship/tasks
  git checkout -q -B main 2>/dev/null || true
}

# Bring state to "just after design/dev completed" so tests can act on
# dev:success, qa:*, etc. Creates required artifacts and a commit so
# validate_artifacts is satisfied.
seed_through_dev() {
  local task_desc="$1"
  OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" init "$task_desc" 2>/dev/null)
  TASK_ID=$(get_state task_id)
  TASK_DIR=".ship/tasks/$TASK_ID"
  mkdir -p "$TASK_DIR/plan"
  printf '# Spec\n## Acceptance Criteria\n- Must work\n' > "$TASK_DIR/plan/spec.md"
  printf '# Plan\n## Story 1\n- Implement feature\n' > "$TASK_DIR/plan/plan.md"
  printf '# Peer Spec\n## Criteria\n- Must work\n' > "$TASK_DIR/plan/peer-spec.md"
  printf '# Diff Report\n## Resolved\n- Aligned\n' > "$TASK_DIR/plan/diff-report.md"
}

# Create a throwaway commit so dev's artifact validation (HEAD != pre_dev_sha)
# is satisfied. Call AFTER design:success so pre_dev_sha is already set.
make_dummy_commit() {
  local stamp
  stamp=$(date +%s%N)
  echo "stamp $stamp" > "dummy-$stamp.txt"
  git add "dummy-$stamp.txt" && git commit -q -m "dummy $stamp"
}

echo ""
echo "═══════════════════════════════════════════════════"
echo "  e2e phase regression tests"
echo "═══════════════════════════════════════════════════"
echo ""

# ── Test A: Pipeline reorder — dev:success → e2e ────────────
echo "▸ Test A: dev:success dispatches e2e (was review)"
reset_state
seed_through_dev "reorder: dev routes to e2e"

# Advance through design:success first, then make a commit so dev validation sees a diff
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="3 stories" >/dev/null 2>&1
make_dummy_commit

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete dev --verdict=success --summary="3/3 done" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is e2e (not review)" "e2e" "$PHASE"
assert_eq "state advanced to e2e" "e2e" "$(get_state phase)"
assert_contains "message references E2E" "E2E" "$MESSAGE"

echo ""

# ── Test B: Pipeline reorder — e2e:success → review ─────────
echo "▸ Test B: e2e:success (fresh) dispatches review"

# e2e artifacts not required unless e2e/ dir exists, so SKIP-style is fine
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=success --summary="suite green" 2>/dev/null)
parse_output "$OUT"

assert_eq "action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is review (post-e2e)" "review" "$PHASE"
assert_eq "state advanced to review" "review" "$(get_state phase)"
assert_eq "post_qa_fix still false" "false" "$(get_state post_qa_fix)"

echo ""

# ── Test C: Pipeline reorder — qa:success → simplify ────────
echo "▸ Test C: qa:success dispatches simplify (was e2e)"
reset_state
seed_through_dev "reorder: qa routes to simplify"
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="ok" >/dev/null 2>&1
make_dummy_commit
# Fast-forward to qa; set up review + qa report for validation
set_state phase qa
echo "# Review" > "$TASK_DIR/review.md"
mkdir -p "$TASK_DIR/qa"
echo "PASS" > "$TASK_DIR/qa/browser-report.md"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete qa --verdict=success --summary="all pass" 2>/dev/null)
parse_output "$OUT"

assert_eq "qa:success action is dispatch" "dispatch" "$ACTION"
assert_eq "qa:success phase is simplify" "simplify" "$PHASE"
assert_eq "state advanced to simplify" "simplify" "$(get_state phase)"

echo ""

# ── Test D: e2e artifact validation allows SKIP ─────────────
echo "▸ Test D: e2e:skip (no e2e/ dir) validates OK"
reset_state
seed_through_dev "e2e skip honored"
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="ok" >/dev/null 2>&1
make_dummy_commit
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete dev --verdict=success --summary="ok" >/dev/null 2>&1
# No e2e/ directory created — skip case
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=skip --summary="docs-only" 2>/dev/null)
parse_output "$OUT"

assert_eq "e2e:skip action is dispatch" "dispatch" "$ACTION"
assert_eq "e2e:skip advances to review" "review" "$PHASE"

echo ""

# ── Test E: e2e artifact validation requires report when dir exists ─
echo "▸ Test E: e2e:success with empty e2e/ dir → validation fails → e2e_fix"
reset_state
seed_through_dev "e2e report required"
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="ok" >/dev/null 2>&1
make_dummy_commit
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete dev --verdict=success --summary="ok" >/dev/null 2>&1
# e2e/ dir exists but no report.md → validation converts success→fail,
# which enters the e2e_fix loop (by design: a claimed-pass with missing
# artifact is treated as a real failure, not a simple retry).
mkdir -p "$TASK_DIR/e2e"
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=success --summary="claimed pass" 2>/dev/null)
parse_output "$OUT"

assert_eq "validation failure → dispatch" "dispatch" "$ACTION"
assert_eq "phase routes to e2e_fix" "e2e_fix" "$PHASE"
assert_eq "state is e2e_fix" "e2e_fix" "$(get_state phase)"

# Writing the report makes a fresh success stick — move back to e2e first
set_state phase e2e
echo "# E2E report" > "$TASK_DIR/e2e/report.md"
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=success --summary="now with report" 2>/dev/null)
parse_output "$OUT"
assert_eq "with report: advances to review" "review" "$PHASE"

echo ""

# ── Test F: e2e:fail enters e2e_fix loop, bumps e2e_fix_round ─
echo "▸ Test F: e2e:fail → e2e_fix; e2e_fix:fail bumps round"
reset_state
seed_through_dev "e2e fix loop"
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="ok" >/dev/null 2>&1
make_dummy_commit
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete dev --verdict=success --summary="ok" >/dev/null 2>&1

mkdir -p "$TASK_DIR/e2e"
echo "# E2E FAIL: selector drift" > "$TASK_DIR/e2e/report.md"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=fail --summary="login.spec failing" 2>/dev/null)
parse_output "$OUT"
assert_eq "e2e:fail action is dispatch" "dispatch" "$ACTION"
assert_eq "e2e:fail phase is e2e_fix" "e2e_fix" "$PHASE"
assert_eq "state is e2e_fix" "e2e_fix" "$(get_state phase)"
assert_eq "e2e_fix_round stays 0 (bumps on fix fail)" "0" "$(get_state e2e_fix_round)"

# Fix fails → round bumps
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e_fix --verdict=fail --summary="still broken" 2>/dev/null)
parse_output "$OUT"
assert_eq "e2e_fix:fail action is dispatch" "dispatch" "$ACTION"
assert_eq "e2e_fix_round bumped to 1" "1" "$(get_state e2e_fix_round)"

# Fix success → re-e2e with recheck template
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e_fix --verdict=success --summary="fixed" 2>/dev/null)
parse_output "$OUT"
assert_eq "e2e_fix:success → back to e2e" "e2e" "$PHASE"
if [ -f "$PROMPT_FILE" ]; then
  assert_contains "uses e2e recheck template" "recheck" "$(cat "$PROMPT_FILE")"
fi

echo ""

# ── Test G: qa_fix:success routes through e2e regression gate ─
echo "▸ Test G: qa_fix:success → e2e (not qa-recheck) with post_qa_fix=true"
reset_state
seed_through_dev "qa fix regression gate"
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="ok" >/dev/null 2>&1
make_dummy_commit
# Jump to qa_fix
set_state phase qa_fix
echo "# Review" > "$TASK_DIR/review.md"
mkdir -p "$TASK_DIR/qa"
echo "FAIL: item" > "$TASK_DIR/qa/report.md"

OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete qa_fix --verdict=success --summary="fix applied" 2>/dev/null)
parse_output "$OUT"
assert_eq "qa_fix:success action is dispatch" "dispatch" "$ACTION"
assert_eq "qa_fix:success phase is e2e (regression gate)" "e2e" "$PHASE"
assert_eq "state set to e2e" "e2e" "$(get_state phase)"
assert_eq "post_qa_fix flag set" "true" "$(get_state post_qa_fix)"
if [ -f "$PROMPT_FILE" ]; then
  assert_contains "uses e2e recheck template" "recheck" "$(cat "$PROMPT_FILE")"
fi
assert_contains "message says regression gate" "regression" "$MESSAGE"

echo ""

# ── Test H: e2e:success with post_qa_fix=true → qa-recheck ─
echo "▸ Test H: e2e:success after qa_fix routes to qa-recheck and clears flag"

# Still at state phase=e2e, post_qa_fix=true from Test G
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=success --summary="regression green" 2>/dev/null)
parse_output "$OUT"
assert_eq "e2e:success action is dispatch" "dispatch" "$ACTION"
assert_eq "phase is qa (not review)" "qa" "$PHASE"
assert_eq "state back to qa" "qa" "$(get_state phase)"
assert_eq "post_qa_fix flag cleared" "false" "$(get_state post_qa_fix)"
if [ -f "$PROMPT_FILE" ]; then
  assert_contains "uses qa-recheck template" "recheck" "$(cat "$PROMPT_FILE")"
fi

echo ""

# ── Test I: regression-gate e2e failure still respects flag on recovery ─
echo "▸ Test I: post_qa_fix survives e2e_fix loop back to e2e:success → qa-recheck"
reset_state
seed_through_dev "regression gate with e2e fix"
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete design --verdict=success --summary="ok" >/dev/null 2>&1
make_dummy_commit
set_state phase qa_fix
echo "# Review" > "$TASK_DIR/review.md"
mkdir -p "$TASK_DIR/qa"
echo "FAIL" > "$TASK_DIR/qa/report.md"

# qa_fix:success sets post_qa_fix=true and routes to e2e
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete qa_fix --verdict=success --summary="fix" >/dev/null 2>&1
assert_eq "flag set after qa_fix" "true" "$(get_state post_qa_fix)"

# Regression gate e2e fails → e2e_fix
mkdir -p "$TASK_DIR/e2e"
echo "# FAIL" > "$TASK_DIR/e2e/report.md"
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=fail --summary="regression found" >/dev/null 2>&1
assert_eq "phase is e2e_fix" "e2e_fix" "$(get_state phase)"
assert_eq "flag preserved during e2e_fix" "true" "$(get_state post_qa_fix)"

# e2e_fix:success → back to e2e (recheck)
SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e_fix --verdict=success --summary="e2e fixed" >/dev/null 2>&1
assert_eq "phase back to e2e for recheck" "e2e" "$(get_state phase)"
assert_eq "flag still preserved" "true" "$(get_state post_qa_fix)"

# e2e:success → because flag is true, route to qa-recheck, clear flag
OUT=$(SHIP_PLUGIN_ROOT="$SCRIPT_DIR" bash "$ORCH" complete e2e --verdict=success --summary="green" 2>/dev/null)
parse_output "$OUT"
assert_eq "eventual e2e:success → qa" "qa" "$PHASE"
assert_eq "flag cleared at end" "false" "$(get_state post_qa_fix)"

echo ""

# ── Summary ─────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════"
printf "  Results: %d/%d passed" "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf "  (%d FAILED)" "$FAIL"
fi
echo ""
echo "═══════════════════════════════════════════════════"
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
