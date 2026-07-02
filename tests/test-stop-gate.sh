#!/usr/bin/env bash
set -u

# Tests for the mechanical stop gate: the state machine is the source of
# truth — an active non-terminal state blocks exit, everything else allows.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$ROOT/scripts/stop-gate.sh"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf "  PASS: %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  FAIL: %s\n" "$1"
}

WORK="$(mktemp -d "${TMPDIR:-/tmp}/ship-stop-gate-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

write_state() {
  local phase="$1" session="${2:-sess-1}"
  mkdir -p "$WORK/.ship"
  cat > "$WORK/.ship/ship-auto.local.md" <<EOF
---
active: true
task_id: test-task
session_id: $session
branch: main
phase: $phase
---

test description
EOF
}

gate() {
  # args: session_id [agent_id]
  printf '{"cwd":"%s","session_id":"%s","agent_id":"%s"}\n' "$WORK" "$1" "${2:-}" \
    | bash "$GATE"
}

echo "=== Test: stop gate (mechanical) ==="

# No state file → allow exit silently
rm -rf "$WORK/.ship"
OUT=$(gate "sess-1")
if [ -z "$OUT" ]; then
  pass "no active state allows exit"
else
  fail "no active state allows exit"
fi

# Active non-terminal phase, owning session → block with resume guidance
write_state "dev"
OUT=$(gate "sess-1")
if printf '%s' "$OUT" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && printf '%s' "$OUT" | grep -q "phase: dev" \
  && printf '%s' "$OUT" | grep -q "Do not restart from scratch"; then
  pass "active dev phase blocks exit with resume guidance"
else
  fail "active dev phase blocks exit with resume guidance"
fi

# The block reason must include the abandon escape hatch
if printf '%s' "$OUT" | grep -q "ship-auto.local.md"; then
  pass "block reason names the abandon escape hatch"
else
  fail "block reason names the abandon escape hatch"
fi

# Subagents are never blocked
OUT=$(gate "sess-1" "agent-42")
if [ -z "$OUT" ]; then
  pass "subagent is never blocked"
else
  fail "subagent is never blocked"
fi

# A different session is not gated
OUT=$(gate "sess-other")
if [ -z "$OUT" ]; then
  pass "different session allows exit"
else
  fail "different session allows exit"
fi

# Bypass env var allows exit
OUT=$(printf '{"cwd":"%s","session_id":"sess-1"}\n' "$WORK" | SHIP_STOP_GATE_BYPASS=1 bash "$GATE")
if [ -z "$OUT" ]; then
  pass "bypass env allows exit"
else
  fail "bypass env allows exit"
fi

# Handoff phase without PR evidence → block asking to continue handoff
write_state "handoff"
OUT=$(gate "sess-1")
if printf '%s' "$OUT" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && printf '%s' "$OUT" | grep -qi "no PR evidence"; then
  pass "handoff without PR evidence blocks exit"
else
  fail "handoff without PR evidence blocks exit"
fi

# Corrupted state (missing phase) → self-heals and allows exit
mkdir -p "$WORK/.ship"
cat > "$WORK/.ship/ship-auto.local.md" <<'EOF'
---
active: true
task_id: test-task
---

corrupt
EOF
OUT=$(gate "sess-1" 2>/dev/null)
if [ -z "$OUT" ] && [ ! -f "$WORK/.ship/ship-auto.local.md" ]; then
  pass "corrupted state is removed and exit allowed"
else
  fail "corrupted state is removed and exit allowed"
fi

# No LLM verifier machinery remains
if ! grep -q "SHIP_AUTO_VERIFIER_CMD\|claude -p\|codex exec" "$GATE"; then
  pass "gate is mechanical — no LLM verifier subprocess"
else
  fail "gate is mechanical — no LLM verifier subprocess"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
