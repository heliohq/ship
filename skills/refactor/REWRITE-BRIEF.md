# Refactor Skill Rewrite Brief

## What we learned (from 10 test scenarios, 4 iterations, 1 end-to-end execution)

### User expectations
1. SDE says "refactor" = "make this code better." They expect fewer lines, less duplication, clearer logic, better structure. Not just reorganization.
2. Nobody wants to read a 140-line spec before code changes. The spec is for the AI, not the human.
3. Users don't think in phases (diagnose → spec → plan → implement). They think: "fix this mess."

### What worked
- Classification (rescue / directive / feature-prep / not-structural) — correct 10/10 times
- Code smell detection — found god files, duplication, circular deps, dead code reliably
- Dependency graph tracing — accurately mapped cross-file relationships
- Preserved behavior enumeration with file:line — high quality

### What failed
- "Move only, don't change logic" philosophy — produced reorganization, not refactoring. 1310 lines → 1321 lines.
- Spec-first approach — 488-line skill producing 100+ line specs. Over-engineered for the actual execution.
- Rubric optimization loop — 4 iterations chasing C4 scores without ever running the code end-to-end.
- Missing Fowler categories — only covered "Moving Features" (1 of 6 categories). Missed Composing Methods, Simplifying Conditionals entirely.
- Simplify as afterthought — added as Story 4 at the end, not integrated into the core process.

### Industry findings
- Fowler's 6 categories: Composing Methods, Moving Features, Organizing Data, Simplifying Conditionals, Simplifying Method Calls, Generalization
- LLMs are BEST at localized, systematic refactorings (extract method, simplify conditional, inline) — exactly what we didn't do
- LLMs are WORST at multi-module architectural refactoring — exactly what we focused on
- ICSE 2025: "65% of developers report AI misses relevant context when refactoring"
- ICSE 2025: "prompts focus on 'how' to refactor without addressing the 'why'"

### Key numbers from end-to-end test
- Diagnosis: 30s (fast, accurate)
- Spec writing: 2-3 min (accurate but over-detailed)
- Execution Story 1 (move): 6 min, 1310→1310 lines (zero improvement)
- Execution Story 2 (consolidate): 3 min, eliminated 12 duplicates (real improvement)
- Execution Story 3 (cleanup): 3 min, deleted 85 lines dead code (real improvement)
- Story 4 (simplify): never ran
- Total: ~15 min for structural changes that a senior SDE could review in 2 min

### Anti-patterns to avoid in rewrite
1. Don't optimize for rubric scores — optimize for "did the code get better?"
2. Don't separate diagnosis from execution — the same agent should diagnose AND fix
3. Don't write 100-line specs — the spec is overhead, not value
4. Don't restrict to "move only" — real refactoring includes simplification
5. Don't repeat rules in 6 places — say it once in the schema, enforce via template
6. Don't test specs in isolation — test the code output end-to-end
7. Don't make the skill 500 lines — agent context window is precious

## Open questions for rewrite
1. Should diagnosis and execution be one skill or two?
2. What's the minimum viable spec? (Maybe just: Goal + Target Map + What to Eliminate)
3. Should small refactors (< 3 files) skip the spec entirely?
4. How to integrate Fowler's localized techniques (extract method, simplify conditional)?
5. How to measure success? Lines reduced? Duplication count? Cyclomatic complexity?
6. Should the skill call simplify inline or delegate to the existing simplify agent?
