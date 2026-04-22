#!/usr/bin/env bash
set -u

# Shared GitHub PR readiness checks for handoff completion.
# Callers pass an explicit repo dir so hook scripts can run from any cwd.

ship_pr_checks_green() {
  local repo_dir="$1" branch="$2" checks_json bad_checks

  command -v gh >/dev/null 2>&1 || { echo "gh CLI not found"; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq not found"; return 1; }

  checks_json=$(cd "$repo_dir" && gh pr checks "$branch" --json name,state,bucket 2>/dev/null) \
    || { echo "unable to read PR checks"; return 1; }

  bad_checks=$(printf '%s' "$checks_json" | jq -r '
    map(select(
      ((.bucket // "" | ascii_downcase) != "pass") and
      ((.bucket // "" | ascii_downcase) != "skipping") and
      ((.state // "" | ascii_upcase) != "SUCCESS") and
      ((.state // "" | ascii_upcase) != "NEUTRAL") and
      ((.state // "" | ascii_upcase) != "SKIPPED")
    ))
    | .[]
    | "\(.name // "unknown")=\(.state // .bucket // "unknown")"
  ' 2>/dev/null) || { echo "unable to parse PR checks"; return 1; }

  if [ -n "$bad_checks" ]; then
    echo "PR checks not green: $bad_checks"
    return 1
  fi

  return 0
}

ship_pr_handoff_ready() {
  local repo_dir="$1" branch="$2" pr_json pr_state merge_state mergeable

  command -v gh >/dev/null 2>&1 || { echo "gh CLI not found"; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "jq not found"; return 1; }

  if [ -n "$(git -C "$repo_dir" diff --name-only --diff-filter=U 2>/dev/null)" ]; then
    echo "local merge conflicts remain unresolved"
    return 1
  fi

  pr_json=$(cd "$repo_dir" && gh pr view "$branch" --json state,mergeStateStatus,mergeable 2>/dev/null) \
    || { echo "PR not found for branch $branch"; return 1; }
  pr_state=$(printf '%s' "$pr_json" | jq -r '.state // ""')
  merge_state=$(printf '%s' "$pr_json" | jq -r '.mergeStateStatus // ""')
  mergeable=$(printf '%s' "$pr_json" | jq -r '.mergeable // ""')

  if [ "$pr_state" != "OPEN" ] && [ "$pr_state" != "MERGED" ]; then
    echo "PR is $pr_state, not OPEN or MERGED"
    return 1
  fi

  if [ "$mergeable" = "CONFLICTING" ]; then
    echo "PR mergeable is CONFLICTING"
    return 1
  fi

  case "$merge_state" in
    CLEAN|HAS_HOOKS|UNSTABLE) ;;
    *)
      echo "PR mergeStateStatus is $merge_state, not merge-ready"
      return 1
      ;;
  esac

  ship_pr_checks_green "$repo_dir" "$branch"
}
