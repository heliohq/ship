# Ship: AI-Powered Software Development Harness

Ship is a harness for Claude Code and Codex that orchestrates end-to-end software development — from planning through implementation, review, QA, and PR creation — with quality gates at every transition.

## How It Works

Ship is a harness, not a copilot. It doesn't help AI write code — it constrains AI to produce reliable results through mechanically enforced quality gates.

**The problem Ship solves:** AI coding agents are capable but unreliable. They skip tests, hallucinate about code they haven't read, review their own work and call it good, and declare victory without evidence. Ship makes these failure modes structurally impossible.

**Quality gates at every transition.** The `stop-gate.sh` hook prevents the orchestrator from exiting while the pipeline is active (tracked via `.ship/ship-auto.local.md`). Each phase produces artifacts that the next phase consumes — no shortcuts, no skipped steps.

**Every phase is an isolated subagent.** The reviewer has never seen the implementation context. The QA evaluator is contractually forbidden from reading the review — it can only look at the spec, the git diff, and the running application. Fresh context per phase means no accumulated bias, no rubber-stamping.

**State lives on disk, not in memory.** The current phase is tracked in `.ship/ship-auto.local.md`. The stop-gate hook reads this file and blocks session exit while the pipeline is active. On resume, auto reads the phase field and picks up where it left off.

**Plans are adversarially tested.** The planner reads your codebase (tracing call chains, mapping integration surfaces, grepping for existing defenses), writes a spec and plan, then hands it to an independent peer challenger. The challenger produces falsification cards — code-grounded objections with file paths and snippets. The planner must respond with code evidence, not hand-waving. Two rounds of this before you see anything.

**Evidence is hierarchical.** L1 (saw it yourself — screenshot, curl response body, console log) is the only acceptable evidence for MUST criteria. L2 (HTTP 200 alone, "tests passed") is insufficient. L3 ("should work based on the code") is an automatic FAIL. The QA evaluator enforces this mechanically.

**The finish line is PR checks green, not PR created.** After creating the PR, Ship enters a fix loop: wait for GitHub checks, read failure logs, dispatch fixes, address review comments, resolve merge conflicts — up to 3 rounds before escalating. PR creation is the midpoint, not the end.

You describe what you want to build. Ship handles the constraints that make AI output trustworthy.

## Core Philosophy

- **Orchestrator pattern** — a thin orchestrator delegates every phase to fresh subagents, may read code for investigation, but never writes code itself
- **Adversarial planning** — plans are stress-tested through independent peer challenger rounds before any code is written
- **Evidence over claims** — every phase produces artifacts on disk; quality gates verify artifacts exist and pass before advancing
- **Test-driven development** — implementation follows a RED-GREEN-REFACTOR cycle with per-story code review

## The Basic Workflow

**setup** — Bootstrap repo infrastructure (detect languages, install tools, configure CI/CD, pre-commit hooks) and discover semantic constraints from code and git history. Generates AGENTS.md, verified learnings (injected at session start), and hookify safety rules. Audits existing harness for staleness.

**design** — Reads the codebase yourself (no delegation), traces call chains and integration surfaces, writes spec + plan with file:line references. Hands it to an independent peer challenger for 2 rounds of adversarial review. All tasks run the full peer investigation and execution drill — no shortcuts.

**auto** — The full pipeline. Code-driven orchestrator where `scripts/auto-orchestrate.sh` owns all state management, artifact validation, and phase transitions. The SKILL.md is a thin relay that dispatches Agent() calls and reports verdicts back to the script. State tracked in `.ship/ship-auto.local.md` — stop-gate hook blocks exit while active.

**dev** — Executes implementation stories from a plan via parallel waves. Dependency analysis groups independent stories into waves; within each wave stories run in parallel via git worktrees, each reviewed independently, then merged before the next wave.

**review** — Find every bug in the diff — spec violations, runtime errors, race conditions, missing error handling. Add a short diagnosis only when multiple findings share one structural root cause. No style or formatting nits.

**qa** — Starts the application and tests the code changes against the spec by interacting with the running product. Discovers the stack, matches testing to what changed (browser, API, CLI), and reports findings with evidence. Browser testing uses [agent-browser](https://github.com/vercel-labs/agent-browser). Independence contract: cannot read review.md or plan.md.

**handoff** — Creates a PR with a concise verification summary, then enters the post-PR loop: monitor GitHub checks, fix failures, address review comments, resolve merge conflicts. Doesn't stop until the PR checks are green or retries are exhausted.

**refactor** — Diagnose code smells, classify by risk: quick (low risk, fix directly with verification) or planned (high risk, write execution card for alignment before executing). Applies Fowler techniques, verifies after every change.

**learn** — Captures mistakes and discoveries from sessions into `.learnings/LEARNINGS.md`. Fully autonomous — no user interaction. Verified entries are rules; pending entries auto-verify when validated or auto-prune when stale.

**write-design-docs** — Creates high-level design documents that prevent AI drift. Structured frontmatter enables AI indexing; status lifecycle tracks trust; the Boundaries section is the core anti-drift mechanism.

Skills trigger automatically based on what you're doing. The harness enforces the workflow — you don't need to remember the process.

## Skills

| Skill | Description |
|-------|-------------|
| `/ship:auto` | Full pipeline orchestrator: design → dev → review → QA → simplify → handoff |
| `/ship:design` | Parallel investigation by host + peer agents, adversarial spec diff with debate, executable TDD plan validated by drill |
| `/ship:dev` | Execute implementation stories from a plan — peer implements, fresh reviewer checks |
| `/ship:review` | Find every bug in the diff, then diagnose the structural deficiency that breeds them |
| `/ship:qa` | Independent QA: tests code changes against the spec via the running application |
| `/ship:handoff` | PR creation with verification summary, GitHub check loop, and review comment resolution |
| `/ship:refactor` | Diagnose code smells, classify by risk (quick/planned), apply Fowler techniques with verification |
| `/ship:setup` | Bootstrap infra + discover semantic constraints, generate AGENTS.md + verified learnings + hookify safety rules |
| `/ship:learn` | Capture session learnings, route to permanent stores, auto-promote and auto-prune |
| `/ship:write-design-docs` | Create and maintain design docs with structured frontmatter for AI indexing |

## Installation

### Claude Code (via ShipAI)

Register the plugin source first:

```
/plugin marketplace add heliohq/ship
```

Then install the plugin:

```
/plugin install heliohq@ship
```

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/heliohq/ship/refs/heads/main/.codex/INSTALL.md
```

Codex hook support is not plugin-based. Follow [`.codex/INSTALL.md`](./.codex/INSTALL.md) to symlink or append Ship's shipped `.codex/hooks.json` into your global `~/.codex/hooks.json`.

### Cursor

Ship now includes native Cursor plugin packaging via [`.cursor-plugin/plugin.json`](./.cursor-plugin/plugin.json) and a Cursor `sessionStart` hook manifest at [`hooks/hooks-cursor.json`](./hooks/hooks-cursor.json).

To install from the Cursor plugin marketplace once published:

```text
/add-plugin ship
```

Or search for `Ship` in the Cursor plugin marketplace.

This reuses Ship's shared `skills/` directory and the same `scripts/session-start.sh` hook logic used by the other runtimes, with Cursor's `additional_context` hook output shape.

Current Cursor support includes skills plus `sessionStart` context injection. Cursor stop-gate support is not wired in this pass.

### Local Development

Clone the repo and point Claude Code at it:

```bash
git clone https://github.com/heliohq/ship.git
claude --plugin-dir ./ship
```

### Verify Installation

Open a fresh session and give it a task that would trigger a skill — for example, "plan out a user authentication system" or "debug why the API returns 500 on empty input". Ship should kick in automatically and run the corresponding workflow.

### Updating

```
/plugin update ship
```

## References

Ship is built on ideas from:

- [agent-browser](https://github.com/vercel-labs/agent-browser) — Vercel's headless browser CLI for AI agents
- [Superpowers](https://github.com/obra/superpowers) — Jesse Vincent's skill library for Claude Code
- [gstack](https://github.com/garrytan/gstack) — Garry Tan's full-stack AI development harness

## Links

- Website: https://www.ship.tech
- Repository: https://github.com/heliohq/ship
