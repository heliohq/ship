#!/usr/bin/env bash
set -u

# Ship preflight — sourced by each skill before execution.
# Checks CLI install, auth, version updates, and repo context.

# Ensure user-installed binaries (ship, gh, node) are on PATH.
_BOOTSTRAP="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/path-bootstrap.sh"
[ -f "$_BOOTSTRAP" ] && source "$_BOOTSTRAP"

_SKILL_NAME="${SHIP_SKILL_NAME:-unknown}"

# --- User preferences ---
# Settings file (first match wins):
#   .ship/ship.local.md
#   .claude/ship.local.md
#   .codex/ship.local.md
# Supported settings:
#   auto_login: true|false  — skip confirmation prompt on login
_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
_SETTINGS_FILE=""
for _CANDIDATE in \
  "${_REPO_ROOT}/.ship/ship.local.md" \
  "${_REPO_ROOT}/.claude/ship.local.md" \
  "${_REPO_ROOT}/.codex/ship.local.md"; do
  if [ -f "$_CANDIDATE" ]; then
    _SETTINGS_FILE="$_CANDIDATE"
    break
  fi
done
_AUTO_LOGIN="false"
_CLI_PROMPT="true"
if [ -n "$_SETTINGS_FILE" ] && [ -f "$_SETTINGS_FILE" ]; then
  _FM=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$_SETTINGS_FILE")
  _AUTO_LOGIN=$(echo "$_FM" | grep '^auto_login:' | sed 's/auto_login:[[:space:]]*//' || echo "false")
  _CLI_PROMPT_VAL=$(echo "$_FM" | grep '^cli_prompt:' | sed 's/cli_prompt:[[:space:]]*//' || echo "")
  [ "$_CLI_PROMPT_VAL" = "never" ] && _CLI_PROMPT="false"
fi
echo "SHIP_AUTO_LOGIN: $_AUTO_LOGIN"

# --- Ship CLI check (optional — skills work without it) ---
_SHIP_BIN=""
command -v ship >/dev/null 2>&1 && _SHIP_BIN="ship"

if [ -n "$_SHIP_BIN" ]; then
  _CLI_VERSION=$("$_SHIP_BIN" --version 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$_CLI_VERSION" ]; then
    echo "SHIP_CLI: broken"
  else
    echo "SHIP_CLI: $_CLI_VERSION"

    # Check for updates
    _LATEST=$(curl -fsSL --max-time 3 https://www.ship.tech/version.txt 2>/dev/null || true)
    if [ -n "$_LATEST" ] && [ "$_LATEST" != "$_CLI_VERSION" ]; then
      echo "SHIP_UPDATE: $_LATEST available (current: $_CLI_VERSION). Run: curl -fsSL https://www.ship.tech/install.sh | sh"
    fi

    # Check auth status (use --json for structured output; exit code is unreliable)
    _AUTH_JSON=$("$_SHIP_BIN" auth status --json 2>/dev/null || echo '{}')
    _LOGGED_IN=$(printf '%s' "$_AUTH_JSON" | jq -r '.logged_in // false')

    if [ "$_LOGGED_IN" = "true" ]; then
      echo "SHIP_AUTH: logged_in"
      _EMAIL=$(printf '%s' "$_AUTH_JSON" | jq -r '.email // empty')
      _DAYS=$(printf '%s' "$_AUTH_JSON" | jq -r '.days_remaining // empty')
      [ -n "$_EMAIL" ] && echo "SHIP_USER: $_EMAIL"
      if [ -n "$_DAYS" ] && [ "$_DAYS" -le 3 ]; then
        echo "SHIP_TOKEN_EXPIRY: ${_DAYS} days — consider re-authenticating"
      fi
    else
      echo "SHIP_AUTH: not_logged_in"
    fi
  fi
else
  echo "SHIP_CLI: not_installed"
  echo "SHIP_CLI_PROMPT: $_CLI_PROMPT"
fi

# --- Repo context ---
_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
_REPO=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
echo "BRANCH: $_BRANCH"
echo "REPO: $_REPO"
echo "SKILL: $_SKILL_NAME"
