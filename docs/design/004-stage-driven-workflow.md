---
title: "Agent-Owned Ship Routing"
description: "Production workflow model where agents choose phase bundles while Ship preserves input, minimal state, and Markdown/code outputs."
category: "design"
number: "004"
status: current
services: ["skills", "scripts", "docs"]
related: ["design/002", "design/003"]
last_modified: "2026-05-25"
---

# 004 — Agent-Owned Ship Routing

## Status

Current. Implemented by `/ship:use-ship`, `/ship:auto`, standalone atomic
skills, and the shared `scripts/auto-orchestrate.sh` runner.

## Summary

Ship's production workflow is agent-routed. The framework preserves raw input
and minimal run state, while the agent decides whether the request needs one
skill, a phase bundle, or the full flow. Markdown artifacts and repository code
remain the deliverables.

## Decision

Use three separated artifact planes:

| Plane | Path | Contents |
|-------|------|----------|
| Input | `.ship/tasks/<task_id>/input/` | Raw requirement, source metadata, attachments |
| Control | `.ship/tasks/<task_id>/control/` | Minimal run state plus optional agent-owned notes |
| Output | `.ship/tasks/<task_id>/...` and repo files | Markdown reports, docs, tests, code, PR evidence |

YAML is never the final deliverable. Ship does not prescribe per-stage YAML
schemas. Agents may write lightweight YAML when useful, but they choose the
shape for the task.

## Routing Model

| Need | Route |
|------|-------|
| Choose process | `/ship:use-ship` |
| Plan | `/ship:design` |
| Architecture decision | `/ship:arch-design`, optionally `/ship:design` |
| Build | `/ship:design` → `/ship:dev` or `/ship:dev` from an approved plan |
| Quality | `/ship:e2e` → `/ship:review` → `/ship:qa` → `/ship:refactor` |
| Delivery | `/ship:handoff` |
| Full production delivery | `/ship:auto` |

The current deterministic phase order is:

```text
design -> dev -> e2e -> review -> qa -> refactor -> handoff
```

`/ship:auto` still provides the deterministic full sequence. `/ship:use-ship`
is the normal entrypoint for tasks where the agent should group phases based on
need.

## Boundaries

- Do not reintroduce a separate memory store.
- Do not put PRDs, architecture prose, QA findings, or implementation details in YAML.
- Do not generate framework-mandated `execution_plan.yaml` or `stage_report.yaml` files.
- Do not reintroduce wrapper-only orchestration skills; `/ship:use-ship` coordinates and atomic skills execute.
- Do not make atomic skills depend on `/ship:auto`; they must remain standalone.
- Do not remove `.ship/ship-auto.local.md` until hooks and resume behavior are migrated to control YAML.

## Trade-offs

Keeping the existing runner while trimming task-level YAML avoids a risky
rewrite of hooks, retry loops, and CI readiness checks. The trade-off is that
the internal state file still has a local compatibility role until a later
migration. That is acceptable because generated YAML no longer dictates the
agent's stage reasoning.

Replacing the `simplify` phase with `refactor` makes the cleanup gate align
with the existing `/ship:refactor` skill. Removing the memory-capture lifecycle
keeps session context smaller and moves durable project knowledge to
`AGENTS.md`, docs, and deterministic hook rules.

## References

- `skills/auto/SKILL.md`
- `skills/use-ship/SKILL.md`
- `scripts/auto-orchestrate.sh`
- `docs/design/002-session-context-injection.md`
- `docs/design/003-codex-plugin-packaging.md`
