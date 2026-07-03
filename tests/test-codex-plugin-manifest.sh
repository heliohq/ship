#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/.codex-plugin/plugin.json"
CODEX_HOOKS="$ROOT/hooks/codex-hooks.json"
EXPECTED_VERSION="0.3.1"

PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf "  PASS: %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  FAIL: %s\n" "$1"
}

assert_jq() {
  local label="$1"
  local expr="$2"
  if jq -e "$expr" "$MANIFEST" >/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_path_exists() {
  local label="$1"
  local json_path="$2"
  local value
  value=$(jq -r "$json_path" "$MANIFEST")
  if [[ "$value" == ./* && -e "$ROOT/${value#./}" ]]; then
    pass "$label"
  else
    fail "$label ($value)"
  fi
}

echo "=== Test: Codex plugin manifest ==="

if jq . "$MANIFEST" >/dev/null; then
  pass "manifest is valid JSON"
else
  fail "manifest is valid JSON"
fi

assert_jq "name is ship" '.name == "ship"'
assert_jq "version is strict semver" '.version | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")'
assert_jq "Codex version is $EXPECTED_VERSION" ".version == \"$EXPECTED_VERSION\""
assert_jq "description is present" '.description | type == "string" and length > 0'
assert_jq "author name is present" '.author.name | type == "string" and length > 0'
assert_jq "author is Helio" '.author.name == "Helio" and .author.url == "https://www.helio.im/"'
assert_jq "homepage is Helio" '.homepage == "https://www.helio.im/"'
assert_jq "license is present" '.license | type == "string" and length > 0'
# Codex supports native plugin hooks (same schema as Claude's). The manifest
# MUST declare the pointer explicitly — without it, Codex falls back to the
# default hooks/hooks.json, whose CLAUDE_PLUGIN_ROOT paths break on Codex
# (verified upstream: superpowers d376057 runtime investigation).
assert_jq "manifest declares the Codex hook pointer" '.hooks == "./hooks/codex-hooks.json"'
assert_jq "skills path is relative" '.skills | startswith("./")'
assert_jq "mcpServers path is relative" '.mcpServers | startswith("./")'
assert_path_exists "skills directory exists" '.skills'
assert_path_exists "mcpServers file exists" '.mcpServers'

MCP_FILE="$ROOT/$(jq -r '.mcpServers' "$MANIFEST" | sed 's#^\./##')"
if jq -e '.mcpServers.codex.command == "codex" and (.mcpServers.codex.args | index("mcp-server"))' "$MCP_FILE" >/dev/null; then
  pass "mcp config registers codex mcp-server"
else
  fail "mcp config registers codex mcp-server"
fi

assert_jq "interface displayName is present" '.interface.displayName | type == "string" and length > 0'
assert_jq "interface developer is Helio" '.interface.developerName == "Helio" and .interface.websiteURL == "https://www.helio.im/"'
assert_jq "interface shortDescription is present" '.interface.shortDescription | type == "string" and length > 0'
assert_jq "interface longDescription is present" '.interface.longDescription | type == "string" and length > 0'
assert_jq "interface category is Coding" '.interface.category == "Coding"'
assert_jq "capabilities include Interactive" '.interface.capabilities | index("Interactive")'
assert_jq "capabilities include Read" '.interface.capabilities | index("Read")'
assert_jq "capabilities include Write" '.interface.capabilities | index("Write")'
assert_jq "default prompts fit Codex UI limits" '.interface.defaultPrompt | type == "array" and length <= 3 and all(.[]; type == "string" and length <= 128)'
composer_icon=$(jq -r '.interface.composerIcon // empty' "$MANIFEST")
if [[ -z "$composer_icon" ]] || { [[ "$composer_icon" == ./* && -e "$ROOT/${composer_icon#./}" ]]; }; then
  pass "composerIcon, when declared, is repo-relative and exists"
else
  fail "composerIcon, when declared, is repo-relative and exists ($composer_icon)"
fi
assert_jq "screenshots are an array" '.interface.screenshots | type == "array"'

claude_version=$(jq -r '.version' "$ROOT/.claude-plugin/plugin.json")
marketplace_version=$(jq -r '.plugins[] | select(.name == "ship") | .version' "$ROOT/.claude-plugin/marketplace.json")

if [[ "$claude_version" == "$EXPECTED_VERSION" && "$marketplace_version" == "$EXPECTED_VERSION" ]]; then
  pass "Claude and marketplace versions are $EXPECTED_VERSION"
else
  fail "Claude and marketplace versions are $EXPECTED_VERSION"
fi

if [[ ! -e "$ROOT/.cursor-plugin" ]]; then
  pass "Cursor plugin manifest is absent (support removed)"
else
  fail "Cursor plugin manifest is absent (support removed)"
fi

if [[ ! -e "$ROOT/.agents/plugins/marketplace.json" ]]; then
  pass "repo-local .agents marketplace is absent"
else
  fail "repo-local .agents marketplace is absent"
fi

echo ""
echo "=== Test: Codex hook manifest ==="

if jq . "$CODEX_HOOKS" >/dev/null; then
  pass "codex hook manifest is valid JSON"
else
  fail "codex hook manifest is valid JSON"
fi

# Same three hooks as the Claude manifest; commands resolve via
# ${PLUGIN_ROOT} — the variable Codex actually expands (superpowers'
# runtime-verified manifest uses it; CODEX_PLUGIN_ROOT appears nowhere
# upstream).
if jq -e '
  [.hooks[][]?.hooks[]?.command] |
  length == 3 and
  all(.[]; contains("${PLUGIN_ROOT}/scripts/"))
' "$CODEX_HOOKS" >/dev/null; then
  pass "codex hooks carry all three commands via PLUGIN_ROOT"
else
  fail "codex hooks carry all three commands via PLUGIN_ROOT"
fi

session_start_event="Session""Start"
if jq -e --arg event "$session_start_event" '
  (.hooks | has("PreToolUse")) and (.hooks | has("Stop")) and (.hooks | has($event))
' "$CODEX_HOOKS" >/dev/null; then
  pass "codex hooks include session hint, guardrail, and stop gate"
else
  fail "codex hooks include session hint, guardrail, and stop gate"
fi

# The session hint must not re-inject on resume (upstream hit this bug and
# fixed it with the same matcher: superpowers 879ae59).
if jq -e --arg event "$session_start_event" '
  .hooks[$event][0].matcher == "startup|clear|compact"
' "$CODEX_HOOKS" >/dev/null; then
  pass "codex session hint fires on startup|clear|compact only"
else
  fail "codex session hint fires on startup|clear|compact only"
fi

if [[ ! -e "$ROOT/.codex" ]]; then
  pass "legacy .codex install dir is absent"
else
  fail "legacy .codex install dir is absent"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
