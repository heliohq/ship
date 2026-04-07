---
title: "Auto Verifier Stop Loop"
description: "Ralph-style stop gate for /ship:auto using an external verifier over the user task, diff, and artifacts."
number: "001"
status: partially-outdated
related: []
services: [scripts, hooks, skills]
last_verified: "2026-04-06"
---

# 001 - Auto Verifier Stop Loop

## Status

Partially outdated. The original Ralph-style stop loop design is implemented, but
the v0.7.0 refactor to a code-driven orchestrator (`scripts/auto-orchestrate.sh`)
significantly reduces the verifier's role. With deterministic phase transitions and
artifact validation in code, the orchestrator cannot "cheat" or optimistically skip
steps. The stop-gate now includes a fast-path that bypasses the expensive external
verifier when the pipeline has reached a terminal state (phase=learn or
phase=handoff with PR evidence). The full external verifier remains as a fallback
for ambiguous cases.

## Summary

We will Ralph-ify `/ship:auto` at the overall pipeline level, not at the
individual phase level. When an active auto session tries to stop, the stop
hook will launch a fresh verifier process that judges completion from the
original user task, the current `git diff`, and the artifacts produced under
`.ship/tasks/<task_id>/`.

The auto worker will no longer have final authority to end the run. It may try
to stop, but only the external verifier may allow the session to exit.

## Decision

`/ship:auto` will use a single Ralph-style outer loop with an external
completion verifier.

- The loop activates only when `.ship/ship-auto.local.md` exists.
- The loop is session-isolated. Only the owning session is gated.
- No per-phase verifier loops are added in this design.
- The verifier judges the task itself, not whether the orchestrator thinks it
  is done.

## Goals

- Prevent the `/ship:auto` worker from ending the overall task early.
- Keep the design simple enough to retrofit onto the existing auto pipeline.
- Reuse existing artifacts such as `spec.md`, `plan.md`, `review.md`, and
  `.ship/tasks/<task_id>/qa/` rather than inventing a large new state model.
- Preserve the current phase flow inside `skills/auto/SKILL.md` while letting
  Auto, not child phases, own state transitions.

## Non-Goals

- Add a separate Ralph loop for `design`, `dev`, `review`, `qa`, or `handoff`.
- Prove semantic correctness mechanically in shell alone.
- Replace the existing auto phase state machine with a brand-new planner.
- Introduce mutable PRD/task status files that agents can mark complete.

## Problem

Today, `/ship:auto` trusts the orchestrator and subagent returns too much. A
worker can decide it is done, summarize progress optimistically, and reach the
end of the run even when the actual task is incomplete.

The current stop gate blocks session exit while the auto state file is active,
but it does not independently decide whether the requested work is fully done.
This leaves the final stop decision too close to the worker that performed the
work.

## Chosen Design

### 1. One outer loop for `/ship:auto`

The Ralph-style loop wraps the whole auto run. The existing internal phase
flow remains, but Auto is the only writer of phase transitions in
`.ship/ship-auto.local.md`.

Why:

- A single outer loop matches the current auto architecture.
- It avoids designing different verifier contracts for every phase.
- It keeps the first version focused on the failure mode we care about: the
  overall task ending too early.

### 1b. Auto owns phase state inside the loop

Within `/ship:auto`, child phases produce code, artifacts, and verdicts. Auto
accepts or rejects those outcomes and is the only component that advances
`phase`, `review_fix_round`, `qa_fix_round`, or `session_id` in the state file.

Why:

- A child that does the work should not also decide that the workflow has
  advanced.
- Auto can keep the default behavior simple: stay in the same phase unless a
  clean acceptance or an explicit fix-loop branch is warranted.
- This creates a clean separation between:
  - child verdicts
  - auto phase acceptance
  - external final completion verification

### 2. `.ship/ship-auto.local.md` is the activation flag

The stop hook should only invoke the verifier when
`.ship/ship-auto.local.md` exists and belongs to the current session.

Required fields retained in the frontmatter:

- `active`
- `task_id`
- `session_id`
- `branch`
- `base_branch`
- `started_at`

The body of the file continues to store the original user request. The
verifier will use that request as the primary statement of what must be done.

### 3. Stop attempts become verification attempts

No explicit completion promise is required in this design. The worker does not
need to emit a special token. The exit attempt itself is the request for
verification.

Flow:

1. `/ship:auto` runs normally.
2. The worker attempts to stop.
3. `scripts/stop-gate.sh` detects an active auto state file.
4. `scripts/stop-gate.sh` launches a fresh verifier process.
5. The verifier returns one of three verdicts:
   - `TASK_COMPLETE`
   - `TASK_INCOMPLETE`
   - `TASK_BLOCKED`
6. The stop hook decides whether to allow exit or continue the loop.

### 4. The verifier judges task completion from evidence

The verifier must not ask whether the pipeline "seems done." It must answer:

"Given the original user task, the current repo diff, and the produced
artifacts, is the requested work fully complete?"

Primary verifier inputs:

- Original user request from `.ship/ship-auto.local.md`
- Current branch and `HEAD`
- `git status --short`
- `git diff <base_branch>...HEAD`
- `.ship/tasks/<task_id>/plan/spec.md` when present
- `.ship/tasks/<task_id>/plan/plan.md` when present
- `.ship/tasks/<task_id>/review.md` when present
- All files under `.ship/tasks/<task_id>/qa/` when present
- `.ship/tasks/<task_id>/simplify.md` when present
- Handoff outputs or PR evidence when present

The verifier must be a fresh process, for example `codex exec` or `claude -p`,
and must not reuse the active auto conversation context.

### 5. Verifier verdicts

The verifier may return only one top-level verdict:

- `TASK_COMPLETE`
- `TASK_INCOMPLETE`
- `TASK_BLOCKED`

Interpretation:

- `TASK_COMPLETE` means the requested work is complete enough to let the auto
  run end.
- `TASK_INCOMPLETE` means work is still missing. The verifier must enumerate
  the missing items.
- `TASK_BLOCKED` means the task cannot progress further without an external
  dependency or a human decision.

### 6. Stop-hook decisions

`scripts/stop-gate.sh` should map verifier verdicts to hook behavior as
follows:

- `TASK_COMPLETE`
  - allow exit
- `TASK_BLOCKED`
  - allow exit
  - show the blocker summary to the user
- `TASK_INCOMPLETE`
  - block exit
  - feed the verifier's missing-work summary back into the active auto loop

## Boundaries

These constraints are part of the design, not implementation suggestions.

- The verifier owns completion authority for `/ship:auto`.
- Auto owns phase-transition authority inside `/ship:auto`.
- The auto worker does not own completion authority, even if it believes the
  task is done.
- `.ship/ship-auto.local.md` is an activation and resume file, not the source
  of truth for whether the task is complete.
- The verifier must consider the original user request first. `spec.md` and
  `plan.md` are supporting context, not replacements for the user's ask.
- The first version must not add phase-specific verifier loops.
- The first version must not require a mutable PRD/task status file.

## File Changes

Expected implementation surface for the first version:

- `scripts/stop-gate.sh`
  - call the verifier only for active auto sessions owned by the current
    session
  - interpret verifier verdicts
  - block or allow stop accordingly
- `skills/auto/SKILL.md`
  - update the orchestrator contract so end-of-run behavior expects external
    verification
  - describe how incomplete verifier feedback is reintroduced into the loop
- `hooks/hooks.json`
  - keep the Stop hook wired to `scripts/stop-gate.sh`
- `README.md`
  - update the auto and stop-gate descriptions to reflect verifier-owned stop
    authority

Possible new files:

- `scripts/auto-verifier.sh`
  - wrapper for launching the fresh verifier process and normalizing its output

## Open Questions

- Should the first verifier runtime be `codex exec`, `claude -p`, or both with
  a fallback order?
- What exact prompt format should the verifier receive for stable verdicts?
- How should `TASK_INCOMPLETE` feedback be injected back into the loop: as the
  stop-hook reason, a system message, or both?
- Should `TASK_BLOCKED` leave `.ship/ship-auto.local.md` in place for resume,
  or remove it and force a new explicit restart?

## References

- [AGENTS.md](/Users/travisxie/Desktop/ship/AGENTS.md)
- [README.md](/Users/travisxie/Desktop/ship/README.md)
- [skills/auto/SKILL.md](/Users/travisxie/Desktop/ship/skills/auto/SKILL.md)
- [scripts/stop-gate.sh](/Users/travisxie/Desktop/ship/scripts/stop-gate.sh)
- [ralph-loop README](/Users/travisxie/.claude/plugins/cache/claude-plugins-official/ralph-loop/1.0.0/README.md)
- [ralph-loop stop-hook.sh](/Users/travisxie/.claude/plugins/cache/claude-plugins-official/ralph-loop/1.0.0/hooks/stop-hook.sh)
