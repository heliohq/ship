#!/bin/bash
# Ship secret scanning — PreToolUse hook handler for Write|Edit tools.
# Scans content for secret patterns BEFORE the write happens so it can
# DENY the operation. Applies to ALL callers including subagents.
#
# Returns PreToolUse hook JSON with deny/ask decision, or exits 0 to allow.

set -u

# ── READ HOOK INPUT ──────────────────────────────────────────
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')

[ -z "$CWD" ] && exit 0

# ── LOAD POLICY ──────────────────────────────────────────────
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/lib/policy.sh"

if ! load_policy; then
  exit 0
fi

# ── CHECK secrets.enabled ────────────────────────────────────
SECRETS_ENABLED=$(jq -r '.secrets.enabled // false' <<<"$POLICY" 2>/dev/null)
if [ "$SECRETS_ENABLED" != "true" ]; then
  exit 0
fi

# ── EXTRACT CONTENT TO SCAN ─────────────────────────────────
CONTENT=""
case "$TOOL_NAME" in
  Write)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""')
    ;;
  Edit)
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""')
    ;;
  *)
    # Read, Grep, Glob, etc. — nothing to scan
    exit 0
    ;;
esac

[ -z "$CONTENT" ] && exit 0

# ── BUILT-IN SECRET PATTERNS ────────────────────────────────
declare -a PATTERN_NAMES=(
  "AWS Access Key"
  "GitHub PAT"
  "OpenAI Key"
  "Private Key"
)
declare -a PATTERN_REGEXES=(
  'AKIA[0-9A-Z]{16}'
  'ghp_[a-zA-Z0-9]{36}'
  'sk-[a-zA-Z0-9]{20,}'
  '-----BEGIN.*PRIVATE KEY-----'
)

# ── CUSTOM PATTERNS from secrets.custom_patterns[] ──────────
while IFS= read -r custom_rule; do
  [ -z "$custom_rule" ] && continue
  custom_name=$(jq -r '.name // empty' <<<"$custom_rule")
  custom_pattern=$(jq -r '.pattern // empty' <<<"$custom_rule")
  [ -z "$custom_name" ] || [ -z "$custom_pattern" ] && continue
  PATTERN_NAMES+=("$custom_name")
  PATTERN_REGEXES+=("$custom_pattern")
done < <(jq -c '.secrets.custom_patterns // [] | .[]?' <<<"$POLICY" 2>/dev/null)

# ── SCAN CONTENT ────────────────────────────────────────────
SECRETS_ACTION=$(jq -r '.secrets.action // "block"' <<<"$POLICY" 2>/dev/null)

for i in "${!PATTERN_NAMES[@]}"; do
  pattern_name="${PATTERN_NAMES[$i]}"
  pattern_regex="${PATTERN_REGEXES[$i]}"

  if echo "$CONTENT" | grep -qE "$pattern_regex"; then
    # ── AUDIT LOG ───────────────────────────────────────────
    log_audit "policy_violation" "$(jq -cn \
      --arg type "secret_detected" \
      --arg pattern "$pattern_name" \
      --arg regex "$pattern_regex" \
      --arg tool "$TOOL_NAME" \
      --arg action "$SECRETS_ACTION" \
      '{type: $type, pattern: $pattern, regex: $regex, tool: $tool, action: $action}')"

    # ── DECISION ────────────────────────────────────────────
    REASON="[Ship Policy] Secret detected: ${pattern_name} in file. Remove the secret before writing."

    if [ "$SECRETS_ACTION" = "warn" ]; then
      jq -n --arg reason "$REASON" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "ask",
          permissionDecisionReason: $reason
        }
      }'
    else
      jq -n --arg reason "$REASON" '{
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: $reason
        }
      }'
    fi
    exit 0
  fi
done

# ── NO MATCH — ALLOW ────────────────────────────────────────
exit 0
