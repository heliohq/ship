# Smell-to-Technique Catalog

When the refactor skill detects a code smell, apply the corresponding technique.
Techniques are ordered by LLM reliability (best first).

## Surgical Smells (within-file, apply directly)

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Long Method (>30 lines) | Line count + multiple responsibilities | Extract Method | Split at logical boundaries, name by intent |
| Complex Conditional | Nested if/else >3 levels, long boolean chains | Decompose Conditional / Replace with Guard Clauses | Prefer early returns |
| Duplicated Code (same file) | Near-identical blocks | Extract Method / Consolidate Fragments | Extract shared logic, parameterize differences |
| Magic Numbers/Strings | Literal values in logic | Replace with Named Constant | Group related constants |
| Dead Code | Unused functions/exports/variables | Remove Dead Code | Grep all importers first — check for dynamic usage |
| Bad Names | Unclear abbreviations, misleading names | Rename Variable/Method/Function | Name by what it does, not how |
| Unnecessary Wrapper | One-line function that just calls another | Inline Function | Only if the wrapper adds no clarity |
| Complex Expression | Long expressions inline in conditions/args | Extract Variable | Name the intermediate result |
| Temp Variable Overuse | Variable assigned once, used once nearby | Inline Variable | Only if the expression is clear without the name |
| Long Parameter List (>4) | Function signature too wide | Introduce Parameter Object | Group related params into an object |
| Mixed Concerns in Function | One function doing two unrelated things | Split Phase | Separate into prepare + execute |
| Flag Arguments | Boolean param that changes function behavior | Remove Flag Argument / Split into two functions | Each function does one thing |

**Safety rule for signature-changing techniques** (Introduce Parameter Object, Remove Flag Argument, Split into two functions, Move Function): these change the function's calling interface. Only apply when the function is internal/private AND every caller is within the files you are editing. If the function is exported or has callers outside your scope, preserve the original signature — or skip the technique entirely.

## Structural Smells (cross-file, require execution card)

| Smell | How to detect | Technique | Risk |
|-------|--------------|-----------|------|
| God File (>300 lines, 3+ concerns) | Line count + mixed imports from different domains | Extract Module | Medium — many importers to update |
| Duplicated Logic (across files) | Same pattern in 2+ files | Extract shared function/module | Medium — must verify identical semantics |
| Circular Dependency | A imports B, B imports A | Break cycle — extract shared dep or invert direction | High — easy to change behavior |
| Feature Envy | Function uses another module's data more than its own | Move Function | High — LLM weak point, needs careful verification |
| Dependency Direction Violation | Low-level module imports from high-level | Invert dependency, extract interface | High |
| Shotgun Surgery | One change requires editing 3+ files | Consolidate into single owner | Medium |
| Catch-all Module | utils/helpers/common serving unrelated domains | Split by concern | Low — mechanical but wide blast radius |

## Reuse Smells (search for existing code that makes new code redundant)

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Duplicated existing utility | New code reimplements functionality already available in the codebase | Replace with existing utility | Search utility dirs, shared modules, adjacent files |
| Inline reimplementation | Hand-rolled logic that could use an existing helper — string manipulation, path handling, environment checks, type guards | Replace with existing utility | Common in new code that wasn't aware of existing helpers |

## Quality Smells (hacky patterns that erode maintainability)

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Redundant state | State that duplicates existing state, cached values that could be derived, observers/effects that could be direct calls | Remove / derive instead | |
| Parameter sprawl | Adding new parameters to a function instead of generalizing or restructuring existing ones | Introduce Parameter Object / restructure | |
| Copy-paste with slight variation | Near-duplicate code blocks that should be unified with a shared abstraction | Extract shared function, parameterize differences | Lower threshold than structural duplication — flag at 2 sites, not just 3+ |
| Leaky abstractions | Exposing internal details that should be encapsulated, or breaking existing abstraction boundaries | Encapsulate / restore boundary | |
| Stringly-typed code | Using raw strings where constants, enums, string unions, or branded types already exist in the codebase | Replace with Named Constant / Enum / Union type | |
| Unnecessary comments | Comments explaining WHAT the code does (well-named identifiers already do that), narrating the change, or referencing the task/caller | Remove Comment | Keep only non-obvious WHY (hidden constraints, subtle invariants, workarounds) |

## Efficiency Smells (unnecessary work, missed concurrency, resource waste)

| Smell | How to detect | Technique | Notes |
|-------|--------------|-----------|-------|
| Unnecessary work | Redundant computations, repeated file reads, duplicate network/API calls, N+1 patterns | Cache / batch / deduplicate | |
| Missed concurrency | Independent operations run sequentially when they could run in parallel | Use parallel / concurrent execution | |
| Hot-path bloat | New blocking work added to startup or per-request/per-render hot paths | Defer / lazy-init / move off hot path | |
| Recurring no-op updates | State/store updates inside polling loops, intervals, or event handlers that fire unconditionally | Add change-detection guard | Also verify wrapper functions honor "no change" signals |
| Unnecessary existence checks | Pre-checking file/resource existence before operating (TOCTOU anti-pattern) | Operate directly and handle the error | |
| Memory leaks | Unbounded data structures, missing cleanup, event listener leaks | Add cleanup / bound size / remove listener | |
| Overly broad operations | Reading entire files when only a portion is needed, loading all items when filtering for one | Add projection / filter / stream | |

## When NOT to refactor

| Signal | Why | Redirect to |
|--------|-----|-------------|
| "This is slow" | Performance, not structure | /fix or /ship:auto |
| "This crashes on X input" | Bug, not structure | /fix or /investigate |
| "Add feature X" | Feature work, not refactor | /ship:auto |
| Code is already clean but unfamiliar | Learning, not refactoring | Ask questions, read docs |
