#!/usr/bin/env bash
# Ship plugin — SessionStart hook
# Injects project context into conversation (4 layers, cleanly separated):
#   1. Ship routing policy — concise hard-coded guidance for /ship:* usage
#   2. .learnings/LEARNINGS.md — verified project learnings only
#   3. docs/DOCS_INDEX.md — docs index for project documentation
#   4. DESIGN.md — pointer only (title + section list); full content read on demand
# If no optional context files exist, only the Ship routing policy is injected.

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

# ── Layer 1: Ship routing policy (always injected) ────────────────────
# Keep session-start routing guidance short. The host already exposes the
# skill catalog; this policy surfaces it without defaulting to any one phase.
PARTS="<EXTREMELY_IMPORTANT>
Ship skills are available in this repo. Match the user's request:
- Named phase (\`/ship:dev\`, \`/ship:design\`, \`/ship:review\`, \`/ship:qa\`, \`/ship:e2e\`, \`/ship:refactor\`, \`/ship:handoff\`) → run just that phase.
- Explicit end-to-end request → \`/ship:auto\` (runs design -> dev -> e2e -> review -> qa -> refactor -> handoff).
Do not default to \`/ship:auto\`. If the user's intent is ambiguous, ask which phase they want rather than assume the full pipeline.
</EXTREMELY_IMPORTANT>"

# ── Layer 2: Learnings (verified rules only) ───────────────────────────
if [[ -f "$LEARNINGS_FILE" ]]; then
  VERIFIED_LEARNINGS=$(
    awk '
      BEGIN { RS="---[[:space:]]*\n"; ORS="" }
      {
        block = $0
        gsub(/^[[:space:]]+/, "", block)
        gsub(/[[:space:]]+$/, "", block)
        if (block != "" && block ~ /\*\*Status\*\*:[[:space:]]*verified/) {
          if (printed) {
            printf "\n\n---\n\n"
          }
          printf "%s", block
          printed = 1
        }
      }
    ' "$LEARNINGS_FILE"
  )

  if [[ -n "$VERIFIED_LEARNINGS" ]]; then
    PARTS="${PARTS}

---

Verified project learnings loaded. These entries are rules that MUST be followed — violations cause bugs, security issues, or architectural breakage.

${VERIFIED_LEARNINGS}"
  fi
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
