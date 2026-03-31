#!/usr/bin/env bash
set -u

# Ship preflight — sourced by each skill before execution.
# Checks CLI install, auth, version updates, and repo context.

_SKILL_NAME="${SHIP_SKILL_NAME:-unknown}"

# --- Ship CLI check ---
if command -v ship >/dev/null 2>&1; then
  _CLI_VERSION=$(ship --version 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$_CLI_VERSION" ]; then
    echo "SHIP_CLI: broken"
    echo "ACTION_REQUIRED: Ship CLI is installed but broken. Reinstall: curl -fsSL https://www.ship.tech/install.sh | sh"
  else
    echo "SHIP_CLI: $_CLI_VERSION"

    # Check for updates
    _LATEST=$(curl -fsSL --max-time 3 https://www.ship.tech/version.txt 2>/dev/null || true)
    if [ -n "$_LATEST" ] && [ "$_LATEST" != "$_CLI_VERSION" ]; then
      echo "SHIP_UPDATE: $_LATEST available (current: $_CLI_VERSION). Run: curl -fsSL https://www.ship.tech/install.sh | sh"
    fi

    # Check auth status
    if ship auth status >/dev/null 2>&1; then
      echo "SHIP_AUTH: logged_in"
    else
      echo "SHIP_AUTH: not_logged_in"
      echo "ACTION_REQUIRED: Run 'ship auth login' before using /ship:$_SKILL_NAME."
    fi
  fi
else
  echo "SHIP_CLI: not_installed"
  echo "ACTION_REQUIRED: Ship CLI not found. Ask user to install: curl -fsSL https://www.ship.tech/install.sh | sh"
fi

# --- Repo context ---
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "REPO: $_REPO"
echo "SKILL: $_SKILL_NAME"
