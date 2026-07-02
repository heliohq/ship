#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR=$(mktemp -d /tmp/ship-stage-test-XXXXXX)
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

assert_no_file() {
  local label="$1" path="$2"
  if [ ! -e "$path" ]; then pass "$label"; else fail "$label ($path)"; fi
}

assert_no_match() {
  local label="$1" pattern="$2"
  if rg -n --glob '!test-stage-workflow.sh' "$pattern" "$ROOT/README.md" "$ROOT/AGENTS.md" "$ROOT/docs" "$ROOT/skills" "$ROOT/scripts" "$ROOT/hooks" "$ROOT/tests" >/tmp/ship-stage-rg.txt 2>/dev/null; then
    fail "$label"
    cat /tmp/ship-stage-rg.txt
  else
    pass "$label"
  fi
}

echo "=== Test: agent-owned Ship routing surface ==="

retired_workflow_word="flo""w"
retired_workflow_upper="FLO""W"

for skill in \
  use-ship \
  auto; do
  assert_file "routing skill exists: $skill" "$ROOT/skills/$skill/SKILL.md"
done

assert_no_file "retired staged process skill is absent" "$ROOT/skills/$retired_workflow_word"
setup_word="set""up"
assert_no_file "retired bootstrap skill is absent" "$ROOT/skills/$setup_word"
workspace_word="work""space"
assert_no_file "retired artifact scaffold skill is absent" "$ROOT/skills/$workspace_word"
assert_no_file "retired artifact scaffold script is absent" "$ROOT/scripts/init-product-$workspace_word.sh"
assert_no_file "retired artifact templates are absent" "$ROOT/templates/product-$workspace_word"
assert_no_file "retired artifact scaffold test is absent" "$ROOT/tests/test-product-$workspace_word.sh"

for retired_stage_skill in \
  stage0-orchestration \
  stage-requirement \
  stage-architecture \
  stage-coding \
  stage-quality \
  stage-handoff; do
  assert_no_file "retired stage skill is absent: $retired_stage_skill" "$ROOT/skills/$retired_stage_skill/SKILL.md"
done

assert_file "auto orchestrator exists" "$ROOT/scripts/auto-orchestrate.sh"
assert_no_file "standalone auto state helper is absent" "$ROOT/scripts/auto-state.sh"
assert_no_file "standalone task id helper is absent" "$ROOT/scripts/task-id.sh"
assert_no_file "optional auto pre-compact hook is absent" "$ROOT/scripts/auto-pre-compact.sh"
assert_file "refactor prompt exists" "$ROOT/skills/auto/prompts/refactor.md.tmpl"
assert_no_file "retired staged process orchestrator is absent" "$ROOT/scripts/$retired_workflow_word-orchestrate.sh"
assert_no_file "retired staged process state helper is absent" "$ROOT/scripts/$retired_workflow_word-state.sh"
assert_no_file "retired staged process pre-compact hook is absent" "$ROOT/scripts/$retired_workflow_word-pre-compact.sh"
assert_no_file "legacy skill preflight is absent" "$ROOT/scripts/preflight.sh"
startup_script="session""-start"
assert_file "startup hint script exists" "$ROOT/scripts/$startup_script.sh"
assert_no_file "legacy startup hook wrapper is absent" "$ROOT/hooks/$startup_script"

learn_word="learn"
memory_word="${learn_word}ings"
simplify_word="simplify"

if [ ! -e "$ROOT/skills/$learn_word" ] && [ ! -e "$ROOT/skills/auto/prompts/$learn_word.md.tmpl" ] && [ ! -e "$ROOT/.$memory_word" ]; then
  pass "retired learning surfaces are absent"
else
  fail "retired learning surfaces are absent"
fi

if [ ! -e "$ROOT/skills/auto/prompts/$simplify_word.md.tmpl" ]; then
  pass "simplify prompt is absent"
else
  fail "simplify prompt is absent"
fi

capital_memory_word="L${memory_word#l}"
learning_phrase="${learn_word}ing lifecycle"
capital_simplify_word="S${simplify_word#s}"

assert_no_match "no retired learning references" "ship:${learn_word}|/ship:${learn_word}|\\.${memory_word}|${memory_word}|${capital_memory_word}|${learning_phrase}|${learn_word} phase|skills/${learn_word}|${learn_word}\\.md"
assert_no_match "no retired cleanup references" "${simplify_word}\\.md|${simplify_word} phase|${capital_simplify_word} phase|qa_pass→${simplify_word}|qa routes to ${simplify_word}|after ${simplify_word}"
assert_no_match "no legacy skill preflight references" "scripts/preflight\\.sh|SHIP_SKILL_NAME=.*preflight|Ship preflight"
assert_no_match "no retired bootstrap skill references" "ship:${setup_word}|/ship:${setup_word}|skills/${setup_word}"
assert_no_match "no retired artifact scaffold references" "ship:${workspace_word}|/ship:${workspace_word}|skills/${workspace_word}|scripts/init-product-${workspace_word}\\.sh|templates/product-${workspace_word}|test-product-${workspace_word}\\.sh"
ship_root_var="SHIP_PLUGIN""_ROOT"
root_script_name="ship-plugin""-root"
generic_root_var="\\b_PLUGIN""_ROOT\\b"
root_placeholder="<plugin""-root>"
assert_no_match "no Ship-specific plugin root shim" "${ship_root_var}|${root_script_name}|${generic_root_var}|${root_placeholder}"
compat_alias_phrase="compatibility ali""as"
compat_auto_phrase="compatibility /ship:a""uto"
duplicated_auto_phrase="/ship:a""uto or /ship:a""uto"
assert_no_match "no retired staged process command or files" "ship:${retired_workflow_word}|/ship:${retired_workflow_word}|ship-${retired_workflow_word}|${retired_workflow_word}-orchestrate\\.sh|${retired_workflow_word}-state\\.sh|${retired_workflow_word}-pre-compact\\.sh|skills/${retired_workflow_word}|SHIP_${retired_workflow_upper}_STATE_FILE|${compat_alias_phrase}|${compat_auto_phrase}|${duplicated_auto_phrase}"
session_start_event="Session""Start"
if jq -e --arg event "$session_start_event" '.hooks | has($event)' "$ROOT/hooks/hooks.json" >/dev/null; then
  pass "hook manifest includes startup hint"
else
  fail "hook manifest includes startup hint"
fi

# Exactly two hook manifests with the same three events: hooks.json
# (Claude Code, ${CLAUDE_PLUGIN_ROOT}) and codex-hooks.json (Codex,
# ${PLUGIN_ROOT}). Cursor support is removed.
if [ -e "$ROOT/hooks/codex-hooks.json" ] && [ ! -e "$ROOT/hooks/hooks-cursor.json" ] \
  && [ "$(find "$ROOT/hooks" -type f | wc -l | tr -d ' ')" = "2" ]; then
  pass "hooks/ holds exactly the Claude and Codex manifests"
else
  fail "hooks/ holds exactly the Claude and Codex manifests"
fi

if jq -e '.hooks | has("PreCompact") | not' "$ROOT/hooks/hooks.json" >/dev/null; then
  pass "optional pre-compact hook is not registered"
else
  fail "optional pre-compact hook is not registered"
fi

STARTUP_OUT=$(printf '{"cwd":"%s"}\n' "$ROOT" | bash "$ROOT/scripts/$startup_script.sh")
if printf '%s' "$STARTUP_OUT" | grep -q '/ship:use-ship' \
  && ! printf '%s' "$STARTUP_OUT" | grep -Eq 'DOCS_INDEX|DESIGN\\.md|Documentation index|docs/ship'; then
  pass "startup hint is minimal"
else
  fail "startup hint is minimal"
fi

cd "$TEST_DIR"
git init -q
git commit --allow-empty -m init -q
git update-ref refs/remotes/origin/HEAD "$(git rev-parse HEAD)"

OUT=$("$ROOT/scripts/auto-orchestrate.sh" init "add staged workflow smoke test" 2>/dev/null)
TASK_ID=$("$ROOT/scripts/auto-orchestrate.sh" status --json | jq -r '.task_id')
TASK_DIR=".ship/tasks/$TASK_ID"

case "$OUT" in
  *"PHASE:design"*) pass "auto init dispatches design" ;;
  *) fail "auto init dispatches design" ;;
esac

assert_file "raw requirement captured" "$TASK_DIR/input/requirement.md"
assert_file "source metadata written" "$TASK_DIR/input/source.yaml"
assert_file "run state written" "$TASK_DIR/control/run_state.yaml"
assert_no_file "framework execution plan is not generated" "$TASK_DIR/control/execution_plan.yaml"
assert_no_file "framework stage report is not generated" "$TASK_DIR/stage0_orchestration/stage_report.yaml"

if grep -q "current_phase: design" "$TASK_DIR/control/run_state.yaml" \
  && ! grep -q "current_stage:" "$TASK_DIR/control/run_state.yaml"; then
  pass "run state is minimal and phase-based"
else
  fail "run state is minimal and phase-based"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
