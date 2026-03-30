#!/bin/bash
# Ship policy boundary enforcement — PreToolUse hook for Write|Edit|Read|Grep|Glob.
# Checks file paths against boundaries defined in .ship/ship.policy.json:
#   - no_access: always deny (all tools)
#   - read_only: deny write/edit (Write|Edit only)
#   - allowed_paths: deny if outside (Write|Edit only)
#   - Policy self-protection: warn on .ship/ship.policy*.json edits
#
# IMPORTANT: No subagent bypass. No agent_id check. This fires for ALL callers.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Read hook input from stdin ────────────────────────────────
INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""')

[ -z "$CWD" ] && exit 0

# ── Extract file_path based on tool type ─────────────────────
case "$TOOL_NAME" in
  Write|Edit|Read)
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
    ;;
  Grep|Glob)
    FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.path // ""')
    ;;
  *)
    exit 0
    ;;
esac

# Grep/Glob path may be empty (defaults to CWD) — nothing to enforce
[ -z "$FILE_PATH" ] && exit 0

# ── Load policy ──────────────────────────────────────────────
source "${SCRIPT_DIR}/lib/policy.sh"
CWD="$CWD" load_policy || exit 0

# If base policy exists, merge
if [ -n "${BASE_POLICY_FILE:-}" ] && [ -f "$BASE_POLICY_FILE" ]; then
  POLICY=$(merge_policies)
fi

# ── Helper: emit deny decision ───────────────────────────────
deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# ── Helper: emit ask decision (warn mode) ────────────────────
ask() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "ask",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# ── Helper: check if file is within an allowed path ──────────
is_within_allowed_paths() {
  local file="$1"
  local repo_root
  local relative_path
  local allowed_path
  local count

  repo_root=$(_policy_repo_root)
  count=$(jq -r '.boundaries.allowed_paths | length' <<<"$POLICY" 2>/dev/null)
  [ "${count:-0}" -eq 0 ] && return 0

  # Normalize to repo-relative path for comparison
  relative_path="$file"
  if [[ "$file" == "$repo_root/"* ]]; then
    relative_path="${file#$repo_root/}"
  fi

  while IFS= read -r allowed_path; do
    [ -z "$allowed_path" ] && continue
    # Check if file starts with the allowed path prefix
    if [[ "$relative_path" == "$allowed_path"* ]] || [[ "$relative_path" == "$allowed_path" ]]; then
      return 0
    fi
    # Also check with glob matching via extglob
    if [[ "$relative_path" == $allowed_path ]]; then
      return 0
    fi
  done < <(jq -r '.boundaries.allowed_paths[]? // empty' <<<"$POLICY" 2>/dev/null)

  return 1
}

# ── Policy self-protection ───────────────────────────────────
check_policy_self_protection() {
  local file="$1"
  local repo_root
  local relative_path

  repo_root=$(_policy_repo_root)
  relative_path="$file"
  if [[ "$file" == "$repo_root/"* ]]; then
    relative_path="${file#$repo_root/}"
  else
    # Handle symlink mismatch (e.g. /tmp vs /private/tmp on macOS)
    local alt_root="${repo_root#/private}"
    if [[ "$file" == "$alt_root/"* ]]; then
      relative_path="${file#$alt_root/}"
    fi
  fi

  if [[ "$relative_path" == ".ship/ship.policy.json" ]] || \
     [[ "$relative_path" == ".ship/ship.policy.base.json" ]]; then
    return 0
  fi

  return 1
}

# ── Enforcement for Write|Edit ───────────────────────────────
enforce_write_edit() {
  local file="$1"
  local action

  # Policy self-protection: warn (ask) on policy file edits
  if check_policy_self_protection "$file"; then
    log_audit "policy_violation" "$(jq -cn \
      --arg tool "$TOOL_NAME" \
      --arg file "$file" \
      --arg rule "policy_self_protection" \
      --arg action "ask" \
      '{tool: $tool, file: $file, rule: $rule, action_taken: $action}')"
    ask "[Ship Policy] This file is a policy configuration file. Modifying it changes enforcement rules for this repository. Do you want to proceed?"
  fi

  # Check no_access — always deny
  if match_glob "$file" '.boundaries.no_access'; then
    action=$(get_action '.boundaries' "$MATCHED_ACTION")
    log_audit "policy_violation" "$(jq -cn \
      --arg tool "$TOOL_NAME" \
      --arg file "$file" \
      --arg pattern "$MATCHED_PATTERN" \
      --arg reason "${MATCHED_REASON:-no_access boundary}" \
      --arg action "deny" \
      '{tool: $tool, file: $file, rule: "no_access", pattern: $pattern, reason: $reason, action_taken: $action}')"
    deny "[Ship Policy] Access denied: '$file' matches no_access pattern '$MATCHED_PATTERN'. ${MATCHED_REASON:+Reason: $MATCHED_REASON}"
  fi

  # Check read_only — deny or ask based on action
  if match_glob "$file" '.boundaries.read_only'; then
    action=$(get_action '.boundaries' "$MATCHED_ACTION")
    log_audit "policy_violation" "$(jq -cn \
      --arg tool "$TOOL_NAME" \
      --arg file "$file" \
      --arg pattern "$MATCHED_PATTERN" \
      --arg reason "${MATCHED_REASON:-read_only boundary}" \
      --arg action "$action" \
      '{tool: $tool, file: $file, rule: "read_only", pattern: $pattern, reason: $reason, action_taken: $action}')"
    if [ "$action" = "warn" ]; then
      ask "[Ship Policy] File '$file' is read-only (pattern: '$MATCHED_PATTERN'). ${MATCHED_REASON:+Reason: $MATCHED_REASON. }Do you want to allow this edit?"
    else
      deny "[Ship Policy] Write denied: '$file' matches read_only pattern '$MATCHED_PATTERN'. ${MATCHED_REASON:+Reason: $MATCHED_REASON}"
    fi
  fi

  # Check allowed_paths — deny if file is outside all allowed paths
  local has_allowed_paths
  has_allowed_paths=$(jq -r '.boundaries.allowed_paths // empty | length' <<<"$POLICY" 2>/dev/null)
  if [ "${has_allowed_paths:-0}" -gt 0 ]; then
    if ! is_within_allowed_paths "$file"; then
      log_audit "policy_violation" "$(jq -cn \
        --arg tool "$TOOL_NAME" \
        --arg file "$file" \
        --arg rule "allowed_paths" \
        --arg action "deny" \
        '{tool: $tool, file: $file, rule: $rule, action_taken: $action}')"
      deny "[Ship Policy] Write denied: '$file' is outside the allowed paths defined in policy."
    fi
  fi
}

# ── Enforcement for Read|Grep|Glob ───────────────────────────
enforce_read() {
  local file="$1"

  # Check no_access only — deny
  if match_glob "$file" '.boundaries.no_access'; then
    log_audit "policy_violation" "$(jq -cn \
      --arg tool "$TOOL_NAME" \
      --arg file "$file" \
      --arg pattern "$MATCHED_PATTERN" \
      --arg reason "${MATCHED_REASON:-no_access boundary}" \
      --arg action "deny" \
      '{tool: $tool, file: $file, rule: "no_access", pattern: $pattern, reason: $reason, action_taken: $action}')"
    deny "[Ship Policy] Access denied: '$file' matches no_access pattern '$MATCHED_PATTERN'. ${MATCHED_REASON:+Reason: $MATCHED_REASON}"
  fi
}

# ── Main dispatch ────────────────────────────────────────────
case "$TOOL_NAME" in
  Write|Edit)
    enforce_write_edit "$FILE_PATH"
    ;;
  Read|Grep|Glob)
    enforce_read "$FILE_PATH"
    ;;
esac

# No policy match — allow
exit 0
