#!/usr/bin/env bash
set -u

# Ship session init — runs at conversation start
# Checks CLI installation and auth status, reports session context.

_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"

# --- Ship CLI check ---
if command -v ship >/dev/null 2>&1; then
  _CLI_INSTALLED="yes"
  _CLI_VERSION=$(ship --version 2>/dev/null || echo "unknown")
  echo "SHIP_CLI: $_CLI_VERSION"

  # Check auth status
  if ship auth status >/dev/null 2>&1; then
    _AUTH="yes"
    echo "SHIP_AUTH: logged_in"
  else
    _AUTH="no"
    echo "SHIP_AUTH: not_logged_in"
    echo "ACTION_REQUIRED: User must run 'ship auth login' before proceeding."
  fi
else
  _CLI_INSTALLED="no"
  _AUTH="no"
  echo "SHIP_CLI: not_installed"
  echo "ACTION_REQUIRED: Ship CLI not found. Ask user if they want to install via: curl -fsSL https://ship.tech/install.sh | sh"
fi

# --- Session tracking ---
mkdir -p ~/.ship/sessions
touch ~/.ship/sessions/"$PPID"
_SESSIONS=$(find ~/.ship/sessions -mmin -120 -type f 2>/dev/null | wc -l | tr -d ' ')
find ~/.ship/sessions -mmin +120 -type f -exec rm {} + 2>/dev/null || true
echo "ACTIVE_SESSIONS: $_SESSIONS"

# --- Repo context ---
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
echo "REPO: $_REPO"

# --- Conventions check ---
if [ -f .ship/rules/semantic/CONVENTIONS.md ]; then
  _CONV_COUNT=$(grep -c '^## ' .ship/rules/semantic/CONVENTIONS.md 2>/dev/null || echo "0")
  echo "CONVENTIONS: $_CONV_COUNT rules"
else
  echo "CONVENTIONS: none"
fi

# --- AGENTS.md check ---
if [ -f AGENTS.md ]; then
  echo "AGENTS_MD: present"
else
  echo "AGENTS_MD: missing"
fi
