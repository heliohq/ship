# Structural Execution Card Template

When the refactor is structural (cross-file), write this card before executing.
Keep it tight: 45-60 lines max. This is for the executing agent, not for humans to admire.

## Template

```markdown
# Refactor: [one-line goal]

## Scope
Files in blast radius: [list files]
Test command: [command or "none — write characterization tests first"]

## Evidence
[List findings from all four lenses, grouped by lens. Only smells you verified by reading code.]

### Structure
1. [smell] — file:line — [what's wrong]
2. ...

### Reuse / Quality / Efficiency
- [lens]: [smell] — file:line — [what's wrong]

## Invariants
[Max 5 critical behaviors that MUST NOT change. Each with file:line.]
1. [behavior] — file:line
2. ...

## Target Structure
| Module | Owns | Changes When |
|--------|------|--------------|
| [file] | [one responsibility] | [one trigger] |

## Eliminate
- [duplication]: N copies → 1 shared function in [target file]
- [dead code]: delete [what] from [where]

## Execution Order
1. Verify: run tests (or write characterization tests if none exist)
2. Structure: relocate, consolidate, simplify, clean per Target Structure — run tests after each
3. Reuse: replace new code with existing utilities — run tests
4. Quality: fix stringly-typed code, comments, naming, copy-paste — run tests
5. Efficiency: fix resource-per-call, projections, batching, concurrency — run tests

## Abort If
- Tests fail twice on the same step after attempted fix
- Blast radius grows beyond the Scope list
```

## Rules for filling the card

1. **Evidence must be first-hand.** Every smell must cite code you actually read. Comments about other files are not evidence.
2. **Invariants replace preserved behaviors.** Don't list every HTTP response shape. List the 3-5 behaviors where a silent change would be most dangerous.
3. **Target Structure uses Changes When.** If you can't write it as one trigger, the module is too broad.
4. **Eliminate must be actionable.** "3 copies → 1" not "reduce duplication." Name the target file.
5. **Execution Order is always the same.** Verify → Move → Consolidate → Simplify → Clean. Don't skip steps. Don't reorder.
6. **Write to disk** if blast radius >5 files. Otherwise keep in memory.
