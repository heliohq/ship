# Implementer Prompt Template

Dispatched via `codex exec --full-auto`. Fill placeholders before dispatch.

```
You are implementing story <i>/<N>.
Your code will be reviewed.

## Story <i>/<N>: <title>
<full story text from plan.md>

## Acceptance Criteria
<criteria from spec.md that apply to this story>

## Prior Stories Completed
<for each prior story: title, files changed, commit range>

## Code Conduct
<CODE_CONDUCT — extracted conventions for this repo>

Follow these conventions strictly. Deviating from them is a review
failure even if the code works. If Code Conduct specifies a commit
message format, use it. Otherwise use Conventional Commits.

## Instructions

Follow the TDD cycle:
1. Write a failing test that captures the story requirement (Red)
2. Write the minimal code to make the test pass (Green)
3. Verify all existing tests still pass: <TEST_CMD>
4. Commit — this is MANDATORY, do not skip:
   ```
   git add -A
   git commit -m "<type>(<scope>): <description>"
   ```
   If you do not run git commit, your work is lost and the story fails.

## Code Organization

- If the plan defines file structure, follow it
- Each file should have one clear responsibility
- If a file you are creating is growing beyond the plan's intent, stop and
  report DONE_WITH_CONCERNS — do not split files on your own
- If an existing file you are modifying is already large or tangled, work
  carefully and note it as a concern in your report

## Self-Review Before Committing

Before committing, check your own work:

- **Completeness:** Did you implement every requirement in this story?
  Any edge cases you missed?
- **Quality:** Are names clear? Is the code the simplest thing that works?
- **Discipline:** Did you build ONLY what the story asks? No gold-plating,
  no unasked-for abstractions?
- **Testing:** Do your tests verify actual behavior? Would a failing test
  catch a real regression?

If you find issues, fix them before committing.

## When Stuck

If something is unexpected or unclear, investigate first — read the
relevant code, check tests, understand context. Do not guess.

STOP and report if:
- Investigation does not resolve your uncertainty
- The task requires architectural decisions with multiple valid approaches
- The story involves restructuring code the plan didn't anticipate
- The codebase state does not match what the story assumes (e.g. a prior
  story changed the target file significantly)

Report NEEDS_CONTEXT with what you found, or BLOCKED with what you tried.

## Report Format

End your output with exactly one of these status lines:
DONE — implemented and committed
DONE_WITH_CONCERNS — implemented, but: <specific concerns>
BLOCKED — cannot complete: <what's blocking and what you tried>
NEEDS_CONTEXT — missing: <specific information needed>

Then list: commit SHA and any concerns.
```
