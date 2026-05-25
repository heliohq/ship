---
title: "Codex Plugin Packaging"
description: "Native Codex plugin manifest for Ship skills, MCP, and hook definitions."
category: "design"
number: "003"
status: current
services: [".codex-plugin", ".codex", "hooks", "skills"]
related: ["design/002"]
last_modified: "2026-05-25"
---

# 003 - Codex Plugin Packaging

## Status

Current. Verified against `.codex-plugin/plugin.json`, `.mcp.json`, `hooks/codex-hooks.json`, and the `skills/` directory on 2026-05-25.

## Summary

Ship is packaged as a native Codex plugin through `.codex-plugin/plugin.json`. The manifest exposes Ship skills and the existing Codex MCP bridge, while Codex hook definitions live in `hooks/codex-hooks.json` and use `${CODEX_PLUGIN_ROOT}` so they run from the installed plugin bundle.

## Decision

The Codex plugin manifest is the source of truth for Codex plugin identity and user-facing metadata. It points to:

- `skills: "./skills/"` so Codex can discover `/ship:*` skills through plugin discovery.
- `mcpServers: "./.mcp.json"` so peer-dispatch plumbing remains available from the plugin bundle.
- `interface` metadata so Codex App and CLI plugin surfaces can render Ship as a first-class Coding plugin.

The manifest intentionally does not include a `hooks` field because Codex's current manifest validation rejects it. Ship instead follows the Codex plugin convention used by hook-bearing plugins: keep Codex hook definitions in `hooks/codex-hooks.json`.

Shared skill references live under `skills/.shared/`. Codex plugin validation treats every visible child directory under `skills/` as a skill, so helper-only references must stay hidden.

## Boundaries

- `.codex-plugin/plugin.json` must not register hooks while Codex manifest validation rejects the `hooks` field.
- Do not add a repo-local `.agents/plugins/marketplace.json`; Ship follows the Superpowers-style root plugin layout with `.claude-plugin`, `.codex-plugin`, `.cursor-plugin`, `hooks`, and `skills`.
- `hooks/codex-hooks.json` is the canonical Codex hook manifest.
- `.codex/` must not contain install-time config or hook manifests; Codex plugin packaging owns those surfaces.
- `.mcp.json` should only be referenced from the Codex manifest while it exists and remains valid JSON.
- Helper references under `skills/.shared/` must not be moved back to a visible `skills/shared/` directory.
- Paths inside `.codex-plugin/plugin.json` must be relative to the repository root and begin with `./`.
- User install docs must distinguish native plugin installation from enabling Codex's hook runtime for active workflow quality gates.

## Trade-offs

Native plugin packaging makes Ship align with the Codex plugin ecosystem and lets Codex discover skills without the old `~/.agents/skills` symlink workaround or a `~/.codex/ship` clone. Keeping hooks outside `plugin.json` preserves manifest validation while still packaging hook definitions with the plugin.

## Verification

`tests/test-codex-plugin-manifest.sh` validates the manifest schema expectations that matter for Ship:

- Required fields are present.
- `skills` and `mcpServers` point to existing files or directories.
- The manifest does not contain `hooks`.
- Codex hook commands use `${CODEX_PLUGIN_ROOT}`.
- Interface icon paths resolve to real files.
- Starter prompts fit Codex's UI limits.

## References

- `.codex-plugin/plugin.json`
- `hooks/codex-hooks.json`
- `.mcp.json`
- `.codex/INSTALL.md`
- `docs/design/002-session-context-injection.md`
