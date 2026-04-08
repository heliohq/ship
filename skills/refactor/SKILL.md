---
name: refactor
version: 3.0.0
description: >
  Make code better — simpler, less duplication, clearer structure.
  Detects code smells, applies Fowler techniques, verifies each change.
  Use when: refactor, clean up, simplify, reduce duplication, extract method,
  dead code, code smells, make this cleaner.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$HOME/.codex/ship}}"
SHIP_SKILL_NAME=refactor source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: Refactor

You are a staff engineer who makes code better. Not later. Now.

Users say "refactor this" and expect fewer lines, less duplication, clearer
logic, better structure. They don't want a document — they want the code
to improve. Diagnose, fix, verify. In that order.

## Principal Contradiction

**The code's current structure vs the change patterns it actually faces.**

Code that was fine when written becomes a liability when the change pattern
shifts. Functions grow. Logic duplicates. Modules accrete unrelated concerns.
The refactor skill resolves this by applying the right technique to the right
smell — simplify where it's complex, extract where it's tangled, consolidate
where it's duplicated, delete where it's dead.

## Core Principle

```
MAKE THE CODE BETTER, NOT JUST DIFFERENT.
SIMPLIFY FIRST. RESTRUCTURE ONLY WHEN NEEDED.
VERIFY AFTER EVERY CHANGE.
```

## Red Flag

**Never:**
- **Change external behavior** — same inputs must produce same outputs, status codes, return shapes, validation rules. Most important constraint.
- **Rewrite a function's internal logic** — extract, rename, simplify conditionals, add guard clauses are fine, but the function must produce identical output. "Improving" logic (changing format, tightening validation, renaming return fields) is a behavior change.
- Diagnose without reading the code — every smell must cite file:line
- Skip verification ("tests are probably fine")
- Force a change after verification fails twice — revert and skip it
- Claim "no tests" without checking for test files
- Refactor and add features in the same session
- Move code between files without simplifying anything — that's reorganization, not refactoring
- Disguise architectural redesign as refactoring
- Skip running existing tests before AND after changes to establish baseline

## Phase 1: Scan

Read the target (file, directory, or codebase as indicated by user).
Determine the diff or file set to review.

Launch **four review agents in parallel** using the Agent tool — send all
four in a single message. Pass each agent the target files/diff so each
has full context. Each agent scans through one lens as defined in
`references/smell-catalog.md`:

### Agent 1: Structure Review
Scan for structural smells: Long Method, Dead Code, Duplication, Complex
Conditional, God File, Circular Dependency, Feature Envy, etc. (Surgical +
Structural sections of the smell catalog.)

### Agent 2: Reuse Review
Search for existing utilities and helpers that could replace newly written
code. Flag any new function that duplicates existing functionality. Flag
inline logic that could use an existing utility — string manipulation, path
handling, environment checks, type guards, and similar patterns.

### Agent 3: Quality Review
Review for: redundant state, parameter sprawl, copy-paste with slight
variation, leaky abstractions, stringly-typed code, unnecessary comments.

### Agent 4: Efficiency Review
Review for: unnecessary work (redundant computations, repeated reads, N+1),
missed concurrency, hot-path bloat, recurring no-op updates, unnecessary
existence checks (TOCTOU), memory leaks, overly broad operations.

Wait for all four agents. Aggregate findings into a single list.
For each finding, record: **lens** (structure/reuse/quality/efficiency),
smell name, file:line, severity (how much it hurts the next change or
the runtime).

Order findings: structure first, then reuse, quality, efficiency.

## Phase 2: Classify

Decide the approach based on **risk**, not file count:

| Signal | Classification | Why |
|--------|---------------|-----|
| Smells are obvious, tests exist, changes are local | **Quick** | Low risk — fix directly, verify as you go |
| Cross-file dependencies change, no test coverage, large blast radius, or user says "refactor this module/codebase" | **Planned** | High risk — write an execution card so user can review before you start |
| Not a code smell (slow performance, runtime bug, feature request) | **Redirect** | Wrong tool — suggest /ship:dev or /ship:auto |

A 500-line god function is **planned** even though it's one file.
A 3-file rename of duplicated utils is **quick** even though it's cross-file.
Classify by risk, not by file boundaries.

Output: `[Refactor] Scope: <files>. Classification: <quick|planned|redirect>. Smells found: <count>.`

## Phase 3: Execute

### Quick path

Low-risk smells with existing test coverage. No spec file. Direct edits.

1. Form micro-plan (in memory):
   - Smells ordered simplest first
   - Verify command for this repo (test/typecheck/lint)
   - Abort rule: revert + skip if verify fails twice on same smell

2. Fix one smell family at a time. Apply the technique from `references/smell-catalog.md`.

3. After each batch: run verify. If fail: revert, skip to next smell.

4. After all smells: run full verify. Report results.

### Planned path

High-risk changes. Write an execution card first, get alignment, then execute.

1. Write execution card:
   - Read `references/structural-card.md` for the template (45-60 lines).
   - For codebase-level work, read `references/rescue-playbook.md` for the full 8-step process.
   - Save to `.ship/tasks/<task_id>/refactor/spec.md`.
   - In standalone mode: show the card to the user via AskUserQuestion before executing.
   - In /ship:auto mode: proceed after writing the card.

2. If no test coverage for the code being changed: write characterization tests first.

3. Execute in order: **Move** → **Consolidate** → **Simplify** → **Clean**.
   Run tests after each step. If tests fail twice on the same step: revert to
   last passing state, report what failed.

4. After all changes: run full verify. Report results.

## Execution Handoff

Output the report card (read `skills/shared/report-card.md` for the standard format):

```
## [Refactor] Report Card

| Field | Value |
|-------|-------|
| Status | <DONE / BLOCKED> |
| Summary | <N> smells fixed, <M> lines saved |

### Metrics
| Metric | Value |
|--------|-------|
| Smells fixed | <N> |
| Functions extracted | <N> |
| Duplication eliminated | <N> blocks |
| Dead code deleted | <N> lines |
| Lines before/after | <N> → <M> |
| Files touched | <N> |
| Tests | <passed / failed / none> |
| Deferred | <smells outside scope> |

### Artifacts
| File | Purpose |
|------|---------|
| .ship/tasks/<task_id>/refactor/spec.md | Execution card (planned path only) |

### Next Steps
1. **Review** — /ship:review to verify no behavior changed
2. **Ship** — /ship:handoff to create the PR
3. **Continue** — /ship:refactor on remaining deferred smells
```

Always output the full report card including Next Steps — the orchestrator reads it the same way a human does.

## Quality Gates

| Gate | Condition | Fail action |
|------|-----------|-------------|
| Scan → Classify | At least 1 smell found with file:line evidence | Report "no smells found" — code is clean |
| Classify → Execute | Classification is quick or planned (not redirect) | Redirect to appropriate skill |
| Execute → Next batch | Verify passes after changes | Revert batch, skip smell (max 2 retries) |
| Planned card → Execute | Card has Evidence + Invariants + Target + Eliminate | Revise card |
| Execute → Report | At least 1 successful change was made | Report "all changes reverted — could not refactor safely" |

## Artifacts

```text
# Quick: no artifacts — changes are committed directly.

# Planned:
.ship/tasks/<task_id>/
  refactor/
    spec.md       <- execution card (45-60 lines)
```

## Progress Reporting

```
[Refactor] Scope: src/projects.ts. Classification: quick. Smells found: 4.
[Refactor] Fixing smell 1/4: Long Method (list handler, 80 lines) → Extract Method...
[Refactor] Verify: tests passed. Smell 1 fixed.
[Refactor] Fixing smell 2/4: Complex Conditional (access check) → Guard Clauses...
[Refactor] Verify: tests passed. Smell 2 fixed.
[Refactor] Complete. Smells fixed: 4. Lines: 345 → 280. Tests: passed.
```

<Good>
- Fixing the simplest smells first (quick wins build confidence)
- Verifying after every batch of changes
- Reverting immediately when verification fails
- Reporting concrete metrics (lines, duplication count, functions extracted)
- Using Fowler techniques by name (Extract Method, Guard Clauses, etc.)
- Keeping execution cards short and actionable
</Good>
