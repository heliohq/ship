# AGENTS.md

## Commands

| Action | Command |
|--------|---------|
| Validate JSON | `jq . <file>` |
| Lint shell | `shellcheck scripts/*.sh` (if installed) |
| Test hooks | `echo '<json>' \| bash scripts/<hook>.sh` |
| Reload plugin | `/reload-plugins` in Claude Code |

## Repository Map

| Directory | Contents | Purpose |
|-----------|----------|---------|
| `scripts/` | Shell scripts | Startup hint, workflow hooks, auto orchestrator, PR readiness, docs index generation, PATH bootstrap, and dev-phase file handoffs (`story-brief.sh`, `review-package.sh`) |
| `hooks/` | `hooks.json`, `codex-hooks.json` | Same three hooks per platform (session hint, phase guardrail, stop gate); they differ only in the root variable each platform expands |
| `.codex-plugin/` | `plugin.json` | Native Codex plugin metadata for skills, MCP, and Codex UI |
| `skills/` | Skill dirs plus `.shared/` helpers | Slash commands (`/ship:*`) and hidden shared references |
| `skills/use-ship/` | Routing skill | Agent-facing guide for grouping Ship phases based on task need |
| `skills/auto/prompts/` | `.md.tmpl` files | Prompt templates for the full workflow runner |
| `.claude-plugin/` | `plugin.json` | Plugin metadata for ShipAI |
| `.mcp.json` | MCP config | Codex MCP server registration |

## Architecture

Ship has one opt-in workflow layer. It fires only during user-triggered Ship
workflows, especially `/ship:auto`:

- `session-start.sh` injects only a small `/ship:use-ship` routing hint; no docs index or artifact content.
- `/ship:use-ship` chooses the smallest useful standalone skill, phase bundle, or full workflow.
- Full workflow runs write raw input to `.ship/tasks/<task_id>/input/requirement.md`.
- The runner owns exactly one state surface: the frontmatter of `.ship/ship-auto.local.md`. There is no side-state; agents may create task-specific notes under the task dir if useful.
- Markdown artifacts and repository code are the output plane.
- Bulk artifacts move between agents as file paths, never pasted prompt text: story briefs, implementer reports, and review packages live in the self-ignoring `.ship/scratch/`.
- Durable production artifacts may be organized under `docs/ship/<task-id-or-req-id>/` when the repo lacks an existing convention.
- `stop-gate.sh` — blocks session exit while `.ship/ship-auto.local.md` is active (with fast-path for terminal phases)
- `auto-orchestrate.sh` — code-driven state machine for staged workflows (init, resume, complete, status commands)
- `phase-guardrail.sh` — PreToolUse hook enforcing artifact access rules per phase (QA independence, review read-only, state file protection)
- Claude Code loads hooks through plugin `hooks/hooks.json` (`${CLAUDE_PLUGIN_ROOT}`). Codex loads `hooks/codex-hooks.json` (`${PLUGIN_ROOT}`) via the explicit `"hooks"` pointer in `.codex-plugin/plugin.json` — the pointer is REQUIRED: without it Codex falls back to `hooks/hooks.json`, whose variable does not expand there. Both SessionStart hooks match `startup|clear|compact` so the hint does not re-inject on resume

## Code Style

- Shell: `set -u` at top of every script, `local` for function variables
- JSON parsing: `jq` only (no yq, no Python yaml)
- Hook input: always `INPUT=$(cat)` then extract fields with `jq -r`
- Hook output: `jq -n` to produce response JSON
- Use Conventional Commits: `feat(harness):`, `fix(harness):`, `feat(plugin):`

## Boundaries

### Always Do
- Use `set -u` in every new shell script
- Exit 0 silently when config files don't exist (graceful degradation)
- Use Conventional Commits
- Test hooks by piping JSON stdin: `echo '{"cwd":"/path","tool_name":"Edit",...}' | bash scripts/hook.sh`

### Never Do
- Use `eval` on config values (use `bash -c` instead)
- Use `\s` in `grep -E` (not POSIX on macOS; use `[[:space:]]`)
- Depend on `yq` or PyYAML (JSON-only, parsed with `jq`)

## Gotchas

- macOS `/tmp` resolves to `/private/tmp` via symlink. `git rev-parse --show-toplevel` returns the resolved path. All path matching must handle both forms.
- Plugin-level hooks fire for ALL sessions. Project-level hooks (in `.claude/settings.json`) fire only for that project.
- Hook handlers run in parallel when multiple match the same event. Hooks must not depend on execution order.
- `stop-gate.sh` reads `.ship/ship-auto.local.md` state file. Blocks only the session that started the workflow (session isolation). Subagents are never blocked.
