# Smell-to-Technique Catalog

Four lenses, each owned by one parallel agent during Phase 1. **Each smell belongs to exactly
one lens** — no overlaps. When in doubt, the ownership note decides.

Techniques are ordered by LLM reliability (best first).

---

## Lens 1: Structure (Agent 1)

Structural smells — code organization problems that make the next change harder.

### Surgical (within-file, apply directly)

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Long Method (>30 lines) | Line count + multiple responsibilities | Extract Method | Split at logical boundaries, name by intent |
| Complex Conditional | Nested if/else >3 levels, long boolean chains | Decompose Conditional / Replace with Guard Clauses | Prefer early returns |
| Duplicated Code (same file) | Near-identical blocks within one file | Extract Method / Consolidate Fragments | Extract shared logic, parameterize differences |
| Dead Code | Unused functions/exports/variables | Remove Dead Code | Grep all importers first — check for dynamic usage |
| Bad Names | Unclear abbreviations, misleading names | Rename Variable/Method/Function | Name by what it does, not how |
| Unnecessary Wrapper | One-line function that just calls another | Inline Function | Only if the wrapper adds no clarity |
| Complex Expression | Long expressions inline in conditions/args | Extract Variable | Name the intermediate result |
| Temp Variable Overuse | Variable assigned once, used once nearby | Inline Variable | Only if the expression is clear without the name |
| Long Parameter List (>4) | Function signature too wide | Introduce Parameter Object | Group related params into an object. *Owns all parameter-count issues — Quality lens skips these.* |
| Mixed Concerns in Function | One function doing two unrelated things | Split Phase | Separate into prepare + execute |
| Flag Arguments | Boolean param that changes function behavior | Remove Flag Argument / Split into two functions | Each function does one thing |
| Magic Numbers | Literal numeric values in logic | Replace with Named Constant | Group related constants. *Owns numeric literals — Quality lens owns string literals.* |

**Safety rule for signature-changing techniques** (Introduce Parameter Object, Remove Flag Argument, Split into two functions, Move Function): these change the function's calling interface. Only apply when the function is internal/private AND every caller is within the files you are editing. If the function is exported or has callers outside your scope, preserve the original signature — or skip the technique entirely.

### Structural (cross-file, require execution card)

| Smell | How to detect | Technique | Risk |
|-------|--------------|-----------|------|
| God File (>300 lines, 3+ concerns) | Line count + mixed imports from different domains | Extract Module | Medium — many importers to update |
| Duplicated Logic (across files) | Same pattern in 3+ files | Extract shared function/module | Medium — must verify identical semantics. *Owns cross-file duplication at 3+ sites — Quality lens owns 2-site near-duplicates.* |
| Circular Dependency | A imports B, B imports A | Break cycle — extract shared dep or invert direction | High — easy to change behavior |
| Feature Envy | Function uses another module's data more than its own | Move Function | High — LLM weak point, needs careful verification |
| Dependency Direction Violation | Low-level module imports from high-level | Invert dependency, extract interface | High |
| Shotgun Surgery | One change requires editing 3+ files | Consolidate into single owner | Medium |
| Catch-all Module | utils/helpers/common serving unrelated domains | Split by concern | Low — mechanical but wide blast radius |

---

## Lens 2: Reuse (Agent 2)

Newly written or existing code that reimplements functionality already available elsewhere in the codebase. **This lens searches the codebase, not just the target files** — its job is to find what already exists.

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Duplicated existing utility | New code reimplements functionality already available elsewhere in the codebase | Replace with existing utility | Search utility dirs, shared modules, adjacent files |
| Inline reimplementation | Hand-rolled logic that could use an existing helper — string manipulation, path handling, environment checks, type guards | Replace with existing utility | Common in new code that wasn't aware of existing helpers |

---

## Lens 3: Quality (Agent 3)

Hacky patterns that erode maintainability. **Lower threshold than Structure** — flags issues that Structure's smell catalog would dismiss as "not severe enough."

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Redundant state | State that duplicates existing state, cached values that could be derived, observers/effects that could be direct calls | Remove / derive instead | |
| Copy-paste with slight variation | Near-duplicate code blocks in 2 sites (not 3+) that should be unified | Extract shared function, parameterize differences | *Owns 2-site near-duplicates ��� Structure lens owns 3+ site duplicates.* |
| Leaky abstractions | Exposing internal details that should be encapsulated, or breaking existing abstraction boundaries | Encapsulate / restore boundary | |
| Stringly-typed code | Using raw strings where constants, enums, string unions, or branded types already exist in the codebase | Replace with Named Constant / Enum / Union type | *Owns string literal issues — Structure lens owns numeric literals (Magic Numbers).* |
| Unnecessary comments | Comments explaining WHAT the code does, narrating the change, or referencing the task/caller | Remove Comment | Keep only non-obvious WHY (hidden constraints, subtle invariants, workarounds) |
| Inconsistent naming | Same concept named differently across the codebase (e.g., `user_id` vs `userId` vs `uid`) | Rename to consistent term | Check across files, not just within one |

---

## Lens 4: Efficiency (Agent 4)

Unnecessary work, missed concurrency, and resource waste. **These are refactoring targets, not performance bugs** — the distinction is that efficiency smells are structural patterns fixable by rearranging code, not algorithmic problems requiring new approaches.

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Unnecessary work | Redundant computations, repeated file reads, duplicate network/API calls, N+1 patterns | Cache / batch / deduplicate | |
| Missed concurrency | Independent operations run sequentially when they could run in parallel | Use parallel / concurrent execution | |
| Hot-path bloat | New blocking work added to startup or per-request/per-render hot paths | Defer / lazy-init / move off hot path | |
| Recurring no-op updates | State/store updates inside loops/intervals/handlers that fire unconditionally | Add change-detection guard | Also verify wrapper functions honor "no change" signals |
| Unnecessary existence checks | Pre-checking file/resource existence before operating (TOCTOU anti-pattern) | Operate directly and handle the error | |
| Memory leaks | Unbounded data structures, missing cleanup, event listener leaks | Add cleanup / bound size / remove listener | |
| Overly broad operations | Reading entire files/records when only a portion is needed | Add projection / filter / stream | |
| Expensive resource created per-call | Object, connection, client, or compiled pattern instantiated inside a frequently-called function | Hoist to module-level / singleton / inject via constructor | |

---

## When NOT to refactor

| Signal | Why | Redirect to |
|--------|-----|-------------|
| "This crashes on X input" | Bug, not structure | /fix or /investigate |
| "Add feature X" | Feature work, not refactor | /ship:auto |
| Code is already clean but unfamiliar | Learning, not refactoring | Ask questions, read docs |
| Algorithmic performance problem (wrong data structure, O(n^2) where O(n) exists) | Requires a new approach, not rearranging existing code | /ship:dev or /ship:auto |

**Note:** "This is slow" is NOT an automatic redirect. If the slowness is caused by an efficiency smell (N+1, resource-per-call, overly broad read, missed concurrency), that IS refactoring — Lens 4 handles it. Only redirect when the fix requires a fundamentally different algorithm or architecture.
