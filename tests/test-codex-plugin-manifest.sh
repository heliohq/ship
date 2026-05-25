#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$ROOT/.codex-plugin/plugin.json"
CODEX_HOOKS="$ROOT/hooks/codex-hooks.json"

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
assert_jq "description is present" '.description | type == "string" and length > 0'
assert_jq "author name is present" '.author.name | type == "string" and length > 0'
assert_jq "author is Helio" '.author.name == "Helio" and .author.url == "https://www.helio.im/"'
assert_jq "homepage is Helio" '.homepage == "https://www.helio.im/"'
assert_jq "license is present" '.license | type == "string" and length > 0'
assert_jq "hooks are not declared in manifest" 'has("hooks") | not'
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
assert_path_exists "composer icon exists" '.interface.composerIcon'
assert_path_exists "logo exists" '.interface.logo'
assert_jq "screenshots are an array" '.interface.screenshots | type == "array"'

if [[ ! -e "$ROOT/.agents/plugins/marketplace.json" ]]; then
  pass "repo-local .agents marketplace is absent"
else
  fail "repo-local .agents marketplace is absent"
fi

echo ""
echo "=== Test: Codex hook manifests ==="

if jq . "$CODEX_HOOKS" >/dev/null; then
  pass "codex hook manifest is valid JSON"
else
  fail "codex hook manifest is valid JSON"
fi

if jq -e '
  [.hooks[][]?.hooks[]?.command] |
  length == 3 and
  all(.[]; contains("${CODEX_PLUGIN_ROOT}/scripts/")) and
  all(.[]; contains("$HOME/.codex/ship") | not)
' "$CODEX_HOOKS" >/dev/null; then
  pass "codex hooks use CODEX_PLUGIN_ROOT"
else
  fail "codex hooks use CODEX_PLUGIN_ROOT"
fi

session_start_event="Session""Start"
session_start_script="session""-start"
if jq -e --arg event "$session_start_event" --arg script "$session_start_script" '
  (.hooks | has($event)) and
  ([.hooks[$event][]?.hooks[]?.command] | length == 1 and all(.[]; contains($script)))
' "$CODEX_HOOKS" >/dev/null; then
  pass "codex hooks include minimal session hint"
else
  fail "codex hooks include minimal session hint"
fi

if [[ ! -e "$ROOT/.codex/hooks.json" && ! -e "$ROOT/.codex/config.toml" ]]; then
  pass "legacy codex install artifacts are absent"
else
  fail "legacy codex install artifacts are absent"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
