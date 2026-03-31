#!/usr/bin/env bash
set -u

# Ship preflight — sourced by each skill before execution.
# Checks CLI install, auth, version updates, and repo context.
# Usage: source "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"

_SKILL_NAME="${SHIP_SKILL_NAME:-unknown}"

# --- Ship CLI check ---
if command -v ship >/dev/null 2>&1; then
  _CLI_VERSION=$(ship --version 2>/dev/null || echo "unknown")
  echo "SHIP_CLI: $_CLI_VERSION"

  # Check for updates
  _LATEST=$(curl -fsSL --max-time 3 https://ship.tech/version.txt 2>/dev/null || true)
  if [ -n "$_LATEST" ] && [ "$_LATEST" != "$_CLI_VERSION" ]; then
    echo "SHIP_UPDATE_AVAILABLE: $_LATEST (current: $_CLI_VERSION)"
    echo "UPDATE_HINT: Run 'curl -fsSL https://ship.tech/install.sh | sh' to update."
  fi

  # Check auth status
  if ship auth status >/dev/null 2>&1; then
    echo "SHIP_AUTH: logged_in"
  else
    echo "SHIP_AUTH: not_logged_in"
    echo "ACTION_REQUIRED: User must run 'ship auth login' before using /ship:$_SKILL_NAME."
  fi
else
  echo "SHIP_CLI: not_installed"
  echo "ACTION_REQUIRED: Ship CLI not found. Ask user if they want to install via: curl -fsSL https://ship.tech/install.sh | sh"
fi

# --- Repo context ---
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "REPO: $_REPO"
echo "SKILL: $_SKILL_NAME"
