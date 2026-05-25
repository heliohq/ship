#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR=$(mktemp -d /tmp/ship-auto-smoke-XXXXXX)
PASS=0
FAIL=0

cleanup() {
  rm -rf "$TEST_DIR"
}
trap cleanup EXIT

pass() {
  PASS=$((PASS + 1))
  printf "  PASS: %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  FAIL: %s\n" "$1"
}

assert_file() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then pass "$label"; else fail "$label ($path)"; fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -q "$needle"; then pass "$label"; else fail "$label"; fi
}

echo "=== Test: /ship:auto smoke ==="

retired_workflow_word="flo""w"

assert_file "auto skill exists" "$ROOT/skills/auto/SKILL.md"
assert_file "auto orchestrator exists" "$ROOT/scripts/auto-orchestrate.sh"
assert_file "auto state helper exists" "$ROOT/scripts/auto-state.sh"
assert_file "auto pre-compact hook exists" "$ROOT/scripts/auto-pre-compact.sh"

if [ -d "$ROOT/skills/auto/prompts" ] && [ ! -d "$ROOT/skills/$retired_workflow_word" ]; then
  pass "auto owns prompt templates"
else
  fail "auto owns prompt templates"
fi

cd "$TEST_DIR"
git init -q
git commit --allow-empty -m init -q
git update-ref refs/remotes/origin/HEAD "$(git rev-parse HEAD)"

OUT=$("$ROOT/scripts/auto-orchestrate.sh" init "auto smoke test" 2>/dev/null)

assert_contains "auto init dispatches design" "PHASE:design" "$OUT"
assert_file "auto init creates auto state file" ".ship/ship-auto.local.md"

TASK_ID=$("$ROOT/scripts/auto-state.sh" get task_id)
if [ -n "$TASK_ID" ] && [ -f ".ship/tasks/$TASK_ID/input/requirement.md" ]; then
  pass "auto state helper reads task id"
else
  fail "auto state helper reads task id"
fi

mkdir -p custom
cat > custom/override-state.md <<'EOF'
---
task_id: override-task
phase: design
---

custom auto state
EOF

if [ "$(SHIP_AUTO_STATE_FILE=custom/override-state.md "$ROOT/scripts/auto-state.sh" get task_id)" = "override-task" ]; then
  pass "SHIP_AUTO_STATE_FILE override works"
else
  fail "SHIP_AUTO_STATE_FILE override works"
fi

rm -f .ship/ship-auto.local.md
cat > .ship/ship-auto.local.md <<'EOF'
---
task_id: active-auto
phase: qa
branch: main
---

active auto state
EOF

OUT=$("$ROOT/scripts/auto-orchestrate.sh" status 2>/dev/null)
assert_contains "auto orchestrator reads active state" "TASK_ID:active-auto" "$OUT"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
