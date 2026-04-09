#!/usr/bin/env bash
set -u

# Ship preflight — sourced by each skill before execution.
# Sets up PATH and emits repo context.

# Ensure user-installed binaries (gh, node, etc.) are on PATH.
_BOOTSTRAP="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/path-bootstrap.sh"
[ -f "$_BOOTSTRAP" ] && source "$_BOOTSTRAP"

_SKILL_NAME="${SHIP_SKILL_NAME:-unknown}"

# --- Repo context ---
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "REPO: $_REPO"
echo "SKILL: $_SKILL_NAME"
