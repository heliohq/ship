#!/usr/bin/env bash
# Ship plugin — SessionStart hook
# Injects project context into conversation (4 layers, cleanly separated):
#   1. Skill routing — when to use each /ship:* skill (always injected)
#   2. .learnings/LEARNINGS.md — project learnings (verified rules + pending observations)
#   3. docs/DOCS_INDEX.md — docs index for project documentation
#   4. DESIGN.md — pointer only (title + section list); full content read on demand
# If no context files exist, only the skill routing layer is injected.

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

LEARNINGS_FILE="$REPO_ROOT/.learnings/LEARNINGS.md"
DOCS_INDEX_FILE="$REPO_ROOT/docs/DOCS_INDEX.md"

PARTS=""

# ── Layer 1: Skill routing (always injected) ──────────────────────────
# Tells the agent WHEN to invoke each /ship:* skill.
# Descriptions focus on trigger conditions, not workflow internals.
PARTS="Ship skill routing — use the Skill tool to invoke these when the trigger condition matches:

| Trigger condition | Invoke |
|---|---|
| User wants to plan/scope/investigate before coding (\"plan this\", \"how should we implement\", \"what's the best approach\", \"scope the work\") | /ship:design |
| User wants the full pipeline end-to-end — plan, code, review, test, ship (\"ship this\", \"build end to end\", \"implement and ship\", \"full pipeline\") | /ship:auto |
| A plan/stories already exist and need implementation (\"implement this plan\", \"execute the stories\", \"code this up from the plan\") | /ship:dev |
| Code changes need correctness review — static analysis, not runtime (\"review the code\", \"check for bugs\", \"is this correct\", \"code review\") | /ship:review |
| Code needs runtime testing — start the app and verify behavior (\"test this\", \"QA the changes\", \"does it actually work\", \"run QA\") | /ship:qa |
| Code is done, needs PR creation and CI (\"ship it\", \"create a PR\", \"open a pull request\", \"push and merge\") | /ship:handoff |
| Refactoring or cleanup — no new features (\"refactor\", \"clean up\", \"simplify\", \"reduce duplication\", \"dead code\") | /ship:refactor |
| System architecture design thinking (\"design this system\", \"what's the architecture\", \"trade-offs for X\", \"how should we architect\", \"system design for\") | /ship:arch-design |
| Creating/editing documentation under docs/ (\"write a doc\", \"document this\", \"create a guide\", \"write a design doc\", \"create an ADR\", \"update the docs\") | /ship:write-docs |
| Creating/editing DESIGN.md visual design systems (\"design tokens\", \"color palette\", \"typography\", \"visual design system\") | /ship:visual-design |
| Bootstrapping repo infrastructure (\"setup\", \"init\", \"bootstrap\", \"configure CI\") | /ship:setup |
| Capturing session learnings (\"what did we learn\", \"capture learning\", \"avoid this mistake\") | /ship:learn |

If you think a /ship:* skill applies, invoke it. When unsure between /ship:auto and individual skills: use /ship:auto for end-to-end feature work, use individual skills when the user asks for a specific phase only."

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
