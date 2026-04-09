---
name: refactor
version: 4.0.0
description: >
  Make code better — simpler, less duplication, clearer structure.
  Four-lens parallel scan (structure, reuse, quality, efficiency) detects
  smells across all dimensions. Applies Fowler techniques, verifies each change.
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
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-$(ship-plugin-root 2>/dev/null || echo "$HOME/.codex/ship")}"
SHIP_SKILL_NAME=refactor source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```


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
- Move code between files without improving anything — reorganization alone is not refactoring. (Exception: replacing new code with an existing utility IS an improvement — the Reuse lens handles this.)
- Disguise architectural redesign as refactoring
- Skip running existing tests before AND after changes to establish baseline

## Phase 1: Scan

Read the target (file, directory, or codebase as indicated by user).
Determine the diff or file set to review.

**Small target shortcut:** If the target is a single file under ~200 lines,
scan through all four lenses yourself in one pass instead of dispatching
four agents. The parallel dispatch is valuable for large scopes; for a
small file, sequential scan is faster because it avoids agent round-trip
overhead. Use the same smell catalog — just apply all four lenses in order.
Note: the Reuse lens still requires searching the broader codebase for
existing utilities, even for a small target. "Small target" means scan
inline (no agents), not limit search scope.

**Standard scan (multiple files, directories, or codebase):**

Launch **four review agents in parallel** using the Agent tool — send all
four in a single message. Pass each agent the target files/diff so each
has full context. Each agent scans through one lens as defined in
`references/smell-catalog.md`:

### Agent 1: Structure Review
Scan for structural smells: Long Method, Dead Code, Duplication (3+ sites),
Complex Conditional, God File, Circular Dependency, Feature Envy, Magic
Numbers, etc. (Surgical + Structural sections of the smell catalog.)

### Agent 2: Reuse Review
Search the codebase for existing utilities and helpers that could replace
newly written code. Flag any new function that duplicates existing
functionality. Flag inline logic that could use an existing utility.

### Agent 3: Quality Review
Review for: redundant state, copy-paste with slight variation (2 sites),
leaky abstractions, stringly-typed code, unnecessary comments, inconsistent
naming.

### Agent 4: Efficiency Review
Review for: unnecessary work (redundant computations, repeated reads, N+1),
missed concurrency, hot-path bloat, recurring no-op updates, unnecessary
existence checks (TOCTOU), memory leaks, overly broad operations, expensive
resource created per-call.

### Deduplication

Wait for all four agents. Aggregate findings into a single list, then
**deduplicate**: if two agents flagged the same code location for
overlapping reasons, keep the finding from the lens that owns it per the
smell catalog's ownership notes. Drop the duplicate.

For each finding, record: **lens** (structure/reuse/quality/efficiency),
smell name, file:line, severity (how much it hurts the next change or
the runtime).

## Phase 2: Classify

Decide the approach based on **risk**, not file count or lens:

| Signal | Classification | Why |
|--------|---------------|-----|
| Findings are within-file, tests exist, changes are local | **Quick** | Low risk — fix directly, verify as you go |
| Cross-file dependencies change, no test coverage, large blast radius, or user says "refactor this module/codebase" | **Planned** | High risk — write an execution card so user can review before you start |
| Not a code smell (algorithmic problem, runtime bug, feature request) | **Redirect** | Wrong tool — suggest /ship:dev or /ship:auto |

**Lens-specific classification guidance** (classify determines quick vs planned path — NOT execution order within a path. Execution order is always structure → reuse → quality → efficiency regardless of classification):
- **Structure**: surgical smells → quick; structural smells → planned (as before)
- **Reuse**: replacing code with existing utility → quick (it's a deletion, low risk even if cross-file)
- **Quality**: almost always quick — these are local, low-risk fixes
- **Efficiency**: quick if the fix is local (add projection, hoist a resource); planned if it changes call patterns across files (batching N+1 across a call chain)

A 500-line god function is **planned** even though it's one file.
A 3-file rename of duplicated utils is **quick** even though it's cross-file.
Classify by risk, not by file boundaries.

Output: `[Refactor] Scope: <files>. Classification: <quick|planned|redirect>. Findings: <N> (structure: <n>, reuse: <n>, quality: <n>, efficiency: <n>).`

## Phase 3: Execute

### Execution order across lenses

Fix in this order — each category leaves the code in a better state for the next:

1. **Structure** — fix structural smells first (extract, consolidate, simplify). These change the shape of the code, so doing them first avoids rework.
2. **Reuse** — replace with existing utilities. Now that structure is clean, it's clear what's genuinely duplicated vs what was tangled.
3. **Quality** — fix quality smells (stringly-typed, comments, naming). Polish after structure and reuse are settled.
4. **Efficiency** — fix efficiency smells last. Structural changes may have already eliminated some (e.g., extracting a method may naturally hoist a resource).

Within each category, order smells simplest first.

### Quick path

Low-risk findings with existing test coverage. No spec file. Direct edits.

1. Form micro-plan (in memory):
   - Findings grouped by lens, ordered per execution order above
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
   - Include findings from ALL lenses in the Evidence section, grouped by lens.
   - In /ship:auto mode: save to `.ship/tasks/<task_id>/refactor/spec.md` and proceed.
   - In standalone mode: save to `.ship/refactor-card.md` (no task_id needed) and show the card to the user via AskUserQuestion before executing.

2. If no test coverage for the code being changed: write characterization tests first.

3. Execute in order: **Structure** → **Reuse** → **Quality** → **Efficiency**.
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
| Summary | <N> smells fixed across <L> lenses, <M> lines saved |

### Metrics
| Metric | Value |
|--------|-------|
| Structure fixes | <N> (extracted: <n>, consolidated: <n>, dead code: <n> lines) |
| Reuse fixes | <N> (replaced with existing utility) |
| Quality fixes | <N> (strings→constants: <n>, comments removed: <n>, naming: <n>, other: <n>) |
| Efficiency fixes | <N> (batched: <n>, hoisted: <n>, projected: <n>, other: <n>) |
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

