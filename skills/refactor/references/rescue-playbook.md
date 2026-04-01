# Rescue Playbook — Full Codebase Structural Refactor

Use this playbook when the user targets a whole codebase or directory (not a single file),
and multiple cross-file structural smells are found. This is the "heavy" path — it scans
everything, ranks by leverage, traces dependencies, and produces a comprehensive execution card.

The main SKILL.md says "one structural seam per invocation." This playbook overrides that
for codebase-wide rescue: address the PRIMARY contradiction plus all signals that fall within
its blast radius. Signals outside the blast radius are deferred.

## Step 1: Scan for structural signals

Read every source file in the target directory. Look for:

1. **God files** — files over ~300 lines with mixed concerns
2. **Duplication clusters** — repeated code blocks across files
3. **Import fan-in / fan-out** — files everything depends on, or that depend on everything
4. **Mixed responsibilities** — one file owning unrelated reasons to change
5. **Circular or lateral dependencies** — A imports B, B imports A
6. **Dead code** — exports never imported, functions never called

## Step 2: Read the top candidates

For each serious signal:
1. Read the file(s), not just filenames and sizes.
2. Name the mixed responsibilities or dependency knots you actually see.
3. Trace enough neighboring imports/callers to understand why the boundary is wrong.

## Step 3: Rank by leverage

Choose the signal that makes the most future change cheaper if resolved. Ask:

1. Which signal causes the widest blast radius for ordinary changes?
2. Which signal forces unrelated concerns to move together?
3. Which signal, if fixed, would reduce files touched for the next likely change?
4. If multiple signals exist, does fixing one make the others easier? If yes, that is the **primary contradiction**.

## Step 4: Trace the dependency graph

**Do not skip this.** Before proposing any modules, map how the affected code connects:

1. **Trace imports and calls.** For each file in the blast radius, list what it imports, what imports it, and what functions cross file boundaries.
2. **Map data flow.** Where does data enter? How does it transform? Where does it exit?
3. **Identify layers.** Presentation (HTTP/CLI/UI) vs business logic vs data access vs infrastructure.
4. **Check dependency direction.** High-level → low-level, never the reverse.
5. **Verify every claim with code you read.** Comments about other files are not evidence.

## Step 5: Propose target structure

For each proposed module, apply the Boundary Test inline:

1. **Changes When** — exactly one trigger. If two unrelated changes both modify it, split it.
2. **Understandable from outside** — can someone know what it owns without reading internals?
3. **Correct dependency direction** — no low-level module imports from high-level.
4. **Cheaper next change** — does this boundary reduce files touched?

**Automatic-fail shapes** — split or justify:
- Route handlers + persistence in one module
- Transport/infrastructure + content/templates in one module
- CRUD + access policy + reporting in one module
- Queries/helpers for multiple unrelated domains

## Step 6: Write the execution card

Use the template from `structural-card.md`, but expanded for rescue scope:

```markdown
# Refactor: [primary contradiction in one line]

## Scope
Files in blast radius: [list all affected files]
Test command: [command]

## Evidence
[Every signal with file:line. Ranked by leverage.]
1. [primary contradiction] — file:line — [what's wrong]
2. [secondary signal in blast radius] — file:line
3. ...

## Invariants
[Max 5 critical behaviors that must not change]

## Target Structure
| Module | Owns | Changes When |
|--------|------|--------------|
| ... | ... | ... |

## Required Structural Reductions
Every signal MUST be classified:

| Signal | Action | Detail |
|--------|--------|--------|
| [signal] | **Eliminate** / **Defer** / **Out of scope** | [end state or reason] |

- **Eliminate**: resolved in this refactor. Must include consolidation or deletion, not just code movement.
- **Defer**: not addressed, with concrete reason (e.g., "no test coverage, too risky").
- **Out of scope**: not structural (e.g., performance).

If all signals are Defer/Out of scope, reconsider whether this refactor is worth doing.

## Execution Order
1. Verify: run tests to establish baseline
2. Move: relocate code per Target Structure, update imports, run tests
3. Consolidate: merge duplicates per Eliminate list, run tests
4. Simplify: apply surgical techniques to every touched file, run tests
5. Clean: delete dead code and stale imports, run tests

## Abort If
- Tests fail twice on the same step
- Blast radius grows beyond scope
```

## Step 7: Execute

Follow the execution order in the card. Each step must leave code in a working state.

For large codebases (>10 files in blast radius): consider splitting into 2-3 PRs:
- PR 1: Move (safe, mechanical)
- PR 2: Consolidate + Simplify (behavior-preserving but higher risk)
- PR 3: Clean (safe, deletion only)

## Step 8: Report

Report all metrics plus deferred signals:

```
[Refactor] Complete (rescue).
  Primary contradiction: [what it was]
  Smells fixed: N
  Smells deferred: N (listed below)
  Functions extracted: N
  Duplicated blocks eliminated: N
  Dead code deleted: N lines
  Lines before/after: N → M
  Files touched/created/deleted: N
  Tests: passed/failed/none

  Deferred for next invocation:
  - [signal 1]: [reason]
  - [signal 2]: [reason]
```
