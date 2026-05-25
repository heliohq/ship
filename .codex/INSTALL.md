# Installing Ship for Codex

Ship is a native Codex plugin. The Codex manifest lives at `.codex-plugin/plugin.json`, and Codex hook definitions live at `hooks/codex-hooks.json`.

## Prerequisites

- OpenAI Codex CLI or Codex App

## Installation

### 1. Install the Ship plugin

In Codex CLI, open the plugin picker:

```text
/plugins
```

Search for `Ship` and install it from the plugin marketplace.

In Codex App, open **Plugins** in the sidebar, find `Ship`, and install it.

For local development from this checkout:

```bash
codex plugin marketplace add /path/to/ship
```

Then install `Ship` from the plugin picker.

### 2. Enable required Codex features

Add or confirm this in `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
codex_hooks = true
```

- `multi_agent` enables subagent dispatch used by Ship workflows.
- `codex_hooks` enables Codex's hook runtime for Ship's quality gates.

### 3. Restart Codex

Quit and relaunch Codex CLI or Codex App so plugin and hook changes are loaded.

## Verify

Open a fresh Codex session and check that Ship skills are available from the plugin picker or by asking for `/ship:use-ship`, `/ship:auto`, or a single phase such as `/ship:design`.

For a local checkout, these files should validate:

```bash
jq . .codex-plugin/plugin.json
jq . hooks/codex-hooks.json
jq . .mcp.json
```

## Updating

For local development, pull the checkout and refresh the marketplace:

```bash
git pull
codex plugin marketplace upgrade heliohq
```

## Uninstalling

```bash
codex plugin marketplace remove heliohq
```
