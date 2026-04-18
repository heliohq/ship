# Implementer Prompt

Two audiences use this prompt:

1. **The host (you)** — read it as your own implementation checklist when
   you implement single-story waves and fix-mode dispatches directly.
   No Agent dispatch; just follow the instructions below on the current
   branch.

2. **Dispatched Claude Agent subagents** — used ONLY for multi-story
   parallel waves (where the host cannot fork itself) and for multi-story
   fix rounds (where the original implementer was a sub-agent). All
   dispatches work on the current branch — no worktrees. The wave's
   dependency analysis guarantees the subagent's file scope does not
   overlap other parallel subagents' scopes.

## Dispatch (multi-story waves and their fix rounds)

```
Agent({
  subagent_type: "general-purpose",
  description: "Implement story <i>/<N>",
  prompt: <prompt below, with all placeholders filled>
})
```

The subagent runs in the current repo directory (whatever cwd the host
is running in). The prompt MUST state:
- Which files/modules the subagent is allowed to modify (from dependency
  analysis). The subagent must not touch files outside that scope.
- That the subagent commits its own changes using Conventional Commits.
- That the subagent reports back with the list of files changed and
  commit SHAs it produced.

For single-story waves and fix mode, the host implements directly — no
Agent dispatch is needed. The peer reviewer (Codex) validates the host's
diff in Phase 2 Step B.

## Prompt

```text
You are implementing story <i>/<N>. Your code will be reviewed.

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
   git add <files you changed> && git commit -m "<type>(<scope>): <description>"
   Stage ONLY the files you created or modified. Do not use `git add -A` or `git add .`.
   If you do not commit, your work is lost and the story fails.

Passing tests is necessary, not sufficient. Preserve the task's intended
behavior, not just the current harness behavior.

## Pressure / Anti-Shortcut Rules

- Do not hardcode known fixture values, sample outputs, or branches that only exist to satisfy the current tests
- Do not weaken tests, edit the harness, or hide failures to manufacture a pass
- Do not exploit benchmark quirks or loopholes when they violate the story's stated intent
- If the requirements seem impossible, inconsistent, or only satisfiable by a test-specific hack, stop and report BLOCKED or NEEDS_CONTEXT
- Prefer an honest limitation with evidence over a clever workaround that only makes the tests green

## Code Organization

- If the plan defines file structure, follow it
- Each file should have one clear responsibility
- If a file grows beyond the plan's intent, stop and report DONE_WITH_CONCERNS
- If an existing file is large or tangled, work carefully and note as concern

## Self-Review Before Committing

Before committing, check:
- Completeness: every requirement in this story implemented?
- Quality: names clear, simplest thing that works?
- Discipline: ONLY what the story asks, no gold-plating?
- Testing: tests verify actual behavior, catch real regressions?
- Integrity: would this still work on plausible unseen inputs, not just the current fixtures?

Fix issues before committing.

## When Stuck

Investigate first — read code, check tests, understand context.
Do not guess.

STOP and report if:
- Investigation does not resolve uncertainty
- Task requires architectural decisions with multiple valid approaches
- Story involves restructuring the plan didn't anticipate
- Codebase state doesn't match story assumptions
- The only apparent way forward is to overfit to tests, fixtures, or harness behavior

## Report Format

End with exactly one status line:
DONE — implemented and committed
DONE_WITH_CONCERNS — implemented, but: <specific concerns>
BLOCKED — cannot complete: <what's blocking and what you tried>
NEEDS_CONTEXT — missing: <specific information needed>
```
