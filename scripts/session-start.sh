#!/usr/bin/env bash
# Ship plugin — SessionStart hook
# Injects project context into conversation (4 layers, cleanly separated):
#   1. using-ship meta-skill — establishes how to route work through /ship:* skills
#      (always injected, content read from skills/using-ship/SKILL.md)
#   2. .learnings/LEARNINGS.md — project learnings (verified rules + pending observations)
#   3. docs/DOCS_INDEX.md — docs index for project documentation
#   4. DESIGN.md — pointer only (title + section list); full content read on demand
# If no optional context files exist, only the using-ship layer is injected.

set -u

# Ensure user-installed binaries are on PATH.
_BOOTSTRAP="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/path-bootstrap.sh"
[ -f "$_BOOTSTRAP" ] && source "$_BOOTSTRAP"

INPUT=$(cat)

CWD=""
SESSION_ID=""
if command -v jq &>/dev/null && [[ -n "$INPUT" ]]; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || printf '')
  SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || printf '')
fi

if [[ -n "$CWD" ]]; then
  REPO_ROOT="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$CWD")"
else
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

if [[ -n "$SESSION_ID" ]]; then
  mkdir -p "$REPO_ROOT/.ship"
  printf '%s\n' "$SESSION_ID" > "$REPO_ROOT/.ship/session-id.local"
fi

# Resolve plugin root so we can find the using-ship skill regardless of cwd.
# In Claude Code / Cursor plugin installs, this script lives at <plugin>/scripts/session-start.sh.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

LEARNINGS_FILE="$REPO_ROOT/.learnings/LEARNINGS.md"
DOCS_INDEX_FILE="$REPO_ROOT/docs/DOCS_INDEX.md"
USING_SHIP_SKILL="$PLUGIN_ROOT/skills/using-ship/SKILL.md"

# ── Layer 1: using-ship meta-skill (always injected) ──────────────────
# Full contents of skills/using-ship/SKILL.md, wrapped in a forcing function.
# This is the agent's guide to when each /ship:* skill applies.
if [[ -f "$USING_SHIP_SKILL" ]]; then
  USING_SHIP_CONTENT=$(cat "$USING_SHIP_SKILL")
else
  USING_SHIP_CONTENT="Error: using-ship skill not found at $USING_SHIP_SKILL"
fi

PARTS="<EXTREMELY_IMPORTANT>
You have the Ship pipeline available.

**Below is the full content of the 'ship:using-ship' skill — your introduction to routing work through /ship:* skills. For all other skills, use the 'Skill' tool:**

${USING_SHIP_CONTENT}
</EXTREMELY_IMPORTANT>"

# ── Layer 2: Learnings (verified rules + pending observations) ────────
if [[ -f "$LEARNINGS_FILE" ]]; then
  PARTS="${PARTS}

---

Project learnings loaded. Verified entries are rules that MUST be followed — violations cause bugs, security issues, or architectural breakage. Pending entries are recent observations — check them before making decisions in the affected areas.

$(cat "$LEARNINGS_FILE")"
fi

# ── Layer 3: Documentation index ──────────────────────────────────────
if [[ -f "$DOCS_INDEX_FILE" ]]; then
  PARTS="${PARTS}

---

Documentation index loaded. Before making changes to documented areas, check if a doc covers the affected area. Read the relevant doc to understand boundaries and trade-offs before proceeding. To create or edit docs, use /ship:write-docs.

$(cat "$DOCS_INDEX_FILE")"
fi

# ── Layer 4: Visual design system (pointer only, read on demand) ──────
DESIGN_MD_FILE="$REPO_ROOT/DESIGN.md"
if [[ -f "$DESIGN_MD_FILE" ]]; then
  PARTS="${PARTS}

---

DESIGN.md (visual design system) exists at project root. When writing frontend code, read it first."
fi

# Nothing to inject
if [[ -z "$PARTS" ]]; then
  exit 0
fi

# Use jq for proper JSON escaping, fall back to python if jq unavailable
if command -v jq &>/dev/null; then
  CONTEXT=$(printf '%s' "$PARTS" | jq -Rs .)
elif command -v python3 &>/dev/null; then
  CONTEXT=$(printf '%s' "$PARTS" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
else
  exit 0
fi

if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  printf '{\n  "additional_context": %s\n}\n' "$CONTEXT"
else
  printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "SessionStart",\n    "additionalContext": %s\n  }\n}\n' "$CONTEXT"
fi

exit 0
