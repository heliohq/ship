# Write Plan — Executable Task Decomposition

How to translate a validated spec into an executable plan. Used by the
host agent in Phase 5 of `/ship:design`.

## Overview

Write comprehensive implementation plans assuming the engineer has zero
context for the codebase. Document everything they need: which files to
touch, code, testing commands, how to verify. Give them the whole plan
as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume the implementer is a skilled developer but knows almost nothing
about this project's toolset or problem domain.

## Scope Check

If the spec covers multiple independent subsystems, suggest breaking
into separate plans — one per subsystem. Each plan should produce
working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified
and what each one is responsible for. This is where decomposition
decisions get locked in.

- Design units with clear boundaries and well-defined interfaces.
  Each file should have one clear responsibility.
- Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by
  responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase
  uses large files, don't restructure — but if a file has grown
  unwieldy, including a split in the plan is reasonable.

## plan.md structure

```markdown
# <Task Title> Implementation Plan

> **For agentic workers:** Use /ship:dev to implement this plan
> task-by-task. Steps use checkbox syntax for tracking.

**Goal:** [One sentence — what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---

### Task 1: [Component Name]

**Files:**
- Create: `exact/path/to/file.ext`
- Modify: `exact/path/to/existing.ext:123-145`
- Test: `tests/exact/path/to/test.ext`

- [ ] **Step 1: Write the failing test**

```<lang>
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `<exact test command>`
Expected: FAIL with "<specific error>"

- [ ] **Step 3: Write minimal implementation**

```<lang>
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `<exact test command>`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add <files you changed>
git commit -m "feat: <description>"
```

### Task 2: ...
```

## Bite-sized step granularity

Each step is one action:
- "Write the failing test" — one step
- "Run it to make sure it fails" — one step
- "Implement the minimal code to make it pass" — one step
- "Run the tests" — one step
- "Commit" — one step

## No placeholders

Every step must contain the actual content the implementer needs.
These are plan failures — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the content — the implementer may read
  tasks out of order)
- Steps that describe what to do without showing how

If a step changes code, show the code. Test steps always show complete
test code — the test IS the specification. Implementation steps show
complete code for small focused changes; for larger steps, show the
interface, signature, key logic, and file:line integration points so
the implementer knows exactly what to build and where.

## Remember

- Exact file paths always
- If a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-review

After writing the complete plan, check against spec.md:

1. **Spec coverage:** Every acceptance criterion in spec.md has a task
   that implements it. List any gaps.
2. **Placeholder scan:** Search for any of the patterns from the
   "No placeholders" section above. Fix them.
3. **Type consistency:** Do types, function names, and signatures match
   across tasks? A function called `clearLayers()` in Task 2 but
   `clearFullLayers()` in Task 5 is a bug.
4. **Anti-shortcut check:** Would an implementer know not to solve this
   by overfitting fixtures, editing the harness, or optimizing for tests
   while violating the task intent?

Fix issues inline. No need to re-review — just fix and move on.
