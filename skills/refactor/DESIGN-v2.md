# Refactor Skill v2 — Design Doc

## Problem Statement

Users say "refactor this" and expect the code to get better — shorter, clearer, less duplication, better structure. The current skill (v0.8, 514 lines) only does architectural restructuring (Moving Features in Fowler's taxonomy), which is the least common user need and LLMs' weakest capability. It produces 100+ line specs that move code between files without simplifying anything. End-to-end test: 1310 lines → 1321 lines after full execution.

## Research Findings

### User needs (ranked by frequency)
1. Break up long functions/files
2. Remove duplication
3. Simplify control flow (nested if/else → guard clauses)
4. Rename for clarity
5. Separate concerns / extract modules
6. Delete dead code
7. Move code between files
8. Prepare structure for new feature

### LLM capabilities (from ICSE 2025 + empirical studies)
- Best at: local, systematic, within-function refactoring (Extract Method, Decompose Conditional, Rename, Remove Dead Code)
- Worst at: cross-module architectural refactoring, Move Method (80% hallucination rate per ICSME 2025), large migrations
- StarCoder2: 28% pass@1 → 57% pass@5. Retrying helps, but single-pass is unreliable.
- Key failure mode: "silently changing behavior" — the refactored code looks right but does something different

### Competitor approaches
- **Copilot**: scoped, intention-led edits. No architecture. Snippet/file level.
- **Cursor**: Plan mode → Agent execute → diff review. Conservative. One concern at a time.
- **Aider**: Architect model plans, Editor model executes. Separation helps but one plan-edit cycle isn't enough for risky refactors.
- **Community skills**: surgical, tests-first, one smell at a time.

### What's proven to work (practitioner + academic consensus)
1. Classify first (local cleanup vs structural)
2. Freeze behavior (run tests or write them)
3. Scope hard (one refactoring type, one seam)
4. Small reversible steps with verification between each
5. Static feedback every batch (tests + typecheck + lint)

## Design Principles

### 1. Do what LLMs are best at first
Priority order: simplify > deduplicate > extract > move. Not the reverse.

### 2. Two lanes, one command
- **Lane 1 (Surgical)**: local smells — long function, complex conditional, duplication, dead code, bad names. Directly edit code. No spec file.
- **Lane 2 (Structural)**: architecture — god files, circular deps, feature-prep seams. Lightweight spec, then execute.

Classification is internal. User just says "refactor this."

### 3. Every step must leave code in a working state
No intermediate broken states. Extract → verify. Rename → verify. Move → verify.

### 4. Measure improvement
Before/after metrics reported to user: lines changed, duplication removed, functions extracted, dead code deleted.

### 5. Spec is minimal and for the AI, not the human
Structural lane spec: Goal + Smells Found + Target Structure + What to Eliminate. Max 40 lines. No "preserved behaviors" section (that's what tests are for).

## Architecture

```
User: "refactor this" (+ optional scope: file, directory, or codebase)
           |
    [1. Detect scope + scan for smells]
           |
    [2. Classify]
           |
    ┌──────┼──────────────┐
    │      │              │
[Redirect] [Surgical]  [Structural]
    │      │              │
 [not a   [micro-plan    [execution card
  refactor  in memory]     45-60 lines]
  → /fix]  │              │
           [fix smells    [move → verify
            one family     → consolidate
            at a time]     → verify
           │               → surgical cleanup
           [verify after   → verify]
            each batch]   │
           │              │
           └──────┬───────┘
                  |
           [Report: what changed, metrics]
```

### Three levels, not two lanes
- **Redirect**: not a refactor (perf, bug, feature) → suggest /fix or /auto
- **Surgical**: local smells within file(s) → fix directly, no spec file
- **Structural (single-seam)**: cross-file structural problem → lightweight execution card, then execute. Always ends with surgical cleanup on touched files. One seam per invocation — if multiple structural problems exist, address the highest-leverage one and note the rest.

## Lane 1: Surgical Refactor

### When
- User targets a file or function
- Smells are local: long method, complex conditional, duplication within a file, dead code, bad names
- No cross-file structural problem detected

### Smell → Technique mapping (Fowler)

| Smell | Technique | LLM fit |
|-------|-----------|---------|
| Long Method (>30 lines) | Extract Method | Best |
| Complex Conditional | Decompose Conditional / Guard Clauses | Best |
| Duplicated Code (same file) | Extract Method / Consolidate Fragments | Best |
| Magic Numbers | Replace with Named Constant | Best |
| Dead Code | Remove Dead Code | Best |
| Bad Names | Rename Variable/Method/Function | Best |
| Unnecessary Wrapper | Inline Function | Best |
| Complex Expression | Extract Variable | Best |
| Temp Variable Overuse | Inline Variable / Replace Temp with Query | Good |
| Long Parameter List | Introduce Parameter Object | Good |
| Mixed Concerns in Function | Split Phase | Good |
| Flag Arguments | Remove Flag Argument / Change Function Declaration | Good |

Note: Feature Envy / Move Method is NOT in surgical — it's structural (LLM weak point, needs cross-file reasoning).

### Execution
1. Read the target file(s)
2. Identify smells (list them)
3. Form micro-plan in memory (no file written):
   ```
   Scope: [file(s)]
   Smells: [ordered list, simplest first]
   Verify: [test command, or "typecheck", or "manual"]
   Abort if: [tests fail twice on same smell]
   ```
4. Apply techniques one smell family at a time, innermost/simplest first
5. After each batch: run verify command
6. If verify fails: revert that batch, skip to next smell
7. Report what was changed

### No spec file. But always a micro-plan.

## Lane 2: Structural Refactor

### When
- User targets a directory or codebase
- Cross-file structural problems: god files (>300 lines mixing concerns), circular dependencies, duplicated logic across files, dependency direction violations
- User explicitly asks for structural change ("split this file", "separate concerns")

### Execution Card (45-60 lines, stored in memory, written to disk if blast radius >5 files or user asks)

```
Goal: [one sentence]
Scope: [files in blast radius]
Evidence: [smells with file:line]
Invariants: [critical behaviors that must not change — max 5, with file:line]
Target: [table: Module | Owns | Changes When]
Eliminate: [duplication/dead code to remove]
Execution order: [move → consolidate → surgical → clean]
Verify: [test command]
Abort if: [tests fail twice after move, or blast radius exceeds scope]
```

### Execution (ordered stories)
1. **Verify**: run existing tests. If none, write smoke tests for the code being moved.
2. **Move**: relocate code per target structure. Update imports. Run tests.
3. **Consolidate**: merge duplicated logic. Run tests.
4. **Simplify**: apply Lane 1 surgical techniques to every touched file. Run tests.
5. **Clean**: delete dead code, stale imports. Run tests.

### Bail out
- If tests fail after move and can't be fixed in 2 attempts → revert, report what went wrong
- If no tests and blast radius >5 files → warn user, ask for confirmation

## What v2 does NOT do

- No 500-line skill file. Target: 150-200 lines (workflow in SKILL.md, smell catalog in reference file if needed).
- No 100-line spec. Target: <40 lines (structural) or 0 (surgical).
- No separate diagnosis-only mode. Diagnosis and execution are one flow.
- No full "preserved behaviors" enumeration. But structural lane captures ≤5 critical invariants in the execution card.
- No "Non-goals" section. Scope is defined by what smells were found.
- No hand-off to a separate auto pipeline. The skill executes.
- No architectural redesign. If the user needs a full architecture rethink, suggest breaking it into smaller refactors.

## Success Metrics

### Per-execution (reported to user)
- Functions extracted: N
- Duplicated blocks eliminated: N (was in M files, now in 1)
- Dead code deleted: N lines
- Files touched: N
- Lines before/after: N → M
- Tests: passed / failed / none

### Per-skill (evaluation)
- End-to-end test: input code → /refactor → output code → Codex reviews "is the code better?"
- Not: spec quality rubric scores

## Test Plan

### Eval repo: test-eval-repo/
Reuse existing repo. 10 source files, 1310 lines, known smells.

### Test cases

| ID | Input | Lane | Expected outcome |
|----|-------|------|-----------------|
| S1 | "refactor src/projects.ts" | Surgical → Structural (god file) | Extract report, simplify handlers, remove inline notification logic |
| S2 | "this function is too long" + point at projects.ts list handler | Surgical | Extract helper functions, guard clauses |
| S3 | "remove duplicated code" | Surgical+Structural | Access control 3→1, billing limits 2→1 |
| S4 | "clean up utils.ts" | Surgical | Delete 8 dead exports, simplify |
| S5 | "refactor auth.ts" | Structural | Split mixed concerns, fix notification dependency |
| S6 | "I need team workspaces but billing is per-user" | Structural | Feature-prep seam |
| S7 | "this search is slow" | Redirect | Not a refactor, suggest /fix |
| S8 | auth.ts ↔ notifications.ts circular dep | Structural | Break circular dependency, single seam |
| S9 | Structural refactor with no tests at all | Structural | Must write characterization tests before moving code |
| S10 | Move breaks tests twice | Structural | Forced bailout, revert, report to user |
| S11 | "delete unused code in utils" | Surgical | Verify no dynamic/framework usage before deleting |

### Eval method
1. Run the skill
2. Diff before/after
3. Codex reviews: "did the code get better? Any behavior change?"
4. If tests exist: do they still pass?

## Open Decisions

1. **Should Lane 2 spec be written to disk or kept in agent memory?**
   Pro disk: user can review. Pro memory: less overhead, no file bloat.
   Recommendation: memory by default, write to disk only if user asks or blast radius >5 files.

2. **How to handle "no tests" for structural refactor?**
   Option A: write characterization tests first (safe but slow)
   Option B: proceed with manual verification (fast but risky)
   Recommendation: A for >5 files, B for ≤5 files with user warning.

3. **Should surgical and structural lanes be in the same skill file?**
   Recommendation: yes, one file, <150 lines. The classification logic is 10 lines.

## Next Steps

1. Write the skill (target: <150 lines)
2. Run S1-S7 end-to-end
3. Codex review each output
4. Iterate based on code quality, not spec quality
