---
name: use-ship
version: 0.1.0
description: >
  Route ambiguous software-delivery requests to the smallest useful Ship workflow:
  one skill, a phase bundle, or /ship:auto. Use at session start, when the user
  asks how to use Ship, or when they say build/check/ship without a phase.
allowed-tools:
  - Read
  - Bash
  - Agent
  - TodoWrite
---

# Ship: Use Ship

Use this skill as Ship's routing brain.

Your job is to choose the smallest useful Ship workflow for the request. Do not
force the full pipeline unless the user explicitly wants production delivery or
the risk justifies it.

## Routing Rule

1. Read the user's request and enough repo context to understand the work.
2. Decide whether the task needs one standalone skill, a phase bundle, or the
   full `/ship:auto` workflow.
3. State the chosen route briefly, then invoke the matching skill(s).

## Modern Model Contract

Assume the host model is capable and literal:

- Give it the smallest useful route, not a forced ceremony.
- Trust the agent to choose task-local notes and artifact shape.
- Keep hard gates explicit: evidence, tests, reports, PR readiness.
- Prefer provider-neutral roles: host, peer, subagent, reviewer.
- Do not optimize instructions for a named model version; optimize for
  autonomy, tool use, and strict artifact boundaries.

## Phase Bundles

| Need | Route |
|------|-------|
| Understand scope, write a plan, de-risk approach | `/ship:design` |
| Architecture/API/data model decision | `/ship:arch-design`, then `/ship:design` if implementation planning is needed |
| Implement a well-scoped change | `/ship:design` → `/ship:dev` |
| Implement from an existing approved plan | `/ship:dev` |
| Add durable browser/API/CLI coverage | `/ship:e2e` |
| Check code correctness | `/ship:review` |
| Verify runtime behavior | `/ship:qa` |
| Harden a completed change | `/ship:e2e` → `/ship:review` → `/ship:qa` → `/ship:refactor` |
| Prepare delivery after work is complete | `/ship:handoff` |
| End-to-end production delivery | `/ship:auto` |

## YAML Boundary

Ship's auto runner does not prescribe per-stage YAML schemas.

- The durable input is `.ship/tasks/<task_id>/input/requirement.md` when a full
  flow is running.
- The orchestrator-owned state is minimal and exists for resume/hooks.
- Agents may create lightweight YAML under `.ship/tasks/<task_id>/control/` if
  it helps the current task, but the agent chooses the shape.
- Markdown artifacts and repository code are the real deliverables.

## Production Artifact Organization

When a task needs durable product, design, engineering, quality, delivery, or
archive artifacts, use the repository's existing convention first. If there is
no convention, create the smallest useful folder under:

```text
docs/ship/<task-id-or-req-id>/
  input/       # raw requirement and source notes
  product/     # clarified requirements and acceptance criteria
  design/      # UI/product design artifacts when needed
  engineering/ # architecture and implementation plans
  quality/     # test plans, QA reports, quality evidence
  delivery/    # handoff, release notes, rollout notes
  archive/     # final summary and decisions
```

Only create the folders that the task needs. Prefer Markdown. Use YAML or JSON
only when a later agent, script, or check will consume the structure. Keep code
in the real repository tree; this folder is for durable production artifacts.

## Standalone Boundary

Atomic skills must remain usable without `/ship:auto` or any task directory. If
the user names a phase directly, run that phase directly.

## Default Choice

When intent is ambiguous, route to a bounded bundle instead of asking for the
full pipeline by default. Examples:

- "Plan this" → `/ship:design`
- "Build this" → `/ship:design` → `/ship:dev`
- "Check this change" → `/ship:review` and/or `/ship:qa`
- "Make this production-ready" → quality bundle
- "Ship this all the way" → `/ship:auto`
- "Organize the production docs for this requirement" → create or update the
  appropriate `docs/ship/<task-id-or-req-id>/` artifacts, using focused skills
  such as `/ship:write-docs`, `/ship:arch-design`, or `/ship:visual-design`
