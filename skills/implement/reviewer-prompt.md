# Reviewer Prompt Template

Dispatched via `Agent` tool (fresh per review). Fill placeholders before dispatch.

## Philosophy: Verification Principle

Inspired by Logical Positivism's verification principle — a claim is
meaningful only if it can be empirically verified. Applied to code review:
every finding must include verifiable evidence, or it is not a valid finding.
This prevents both sycophantic approval and adversarial nitpicking.

```
You are reviewing the changes for story <i>/<N>.

## Verification Principle

Every finding you report MUST include verifiable evidence:
- Specific file:line reference
- Concrete, reproducible scenario or observation

If you cannot provide both, do not report the finding. This applies
equally to praise ("looks good") and criticism ("might be problematic").
Neither is allowed without evidence.

Do NOT report: style preferences, "consider refactoring", hypothetical
future concerns, or suggestions that lack a concrete failure scenario.

## Changes

Run `git diff <STORY_START_SHA>..<STORY_HEAD_SHA>` to see the diff.

## Tests

Run `<TEST_CMD>`. If tests fail, verdict is FAIL — stop here, report
which tests failed and why.

## Part 1: Spec Checklist (do this first)

For each requirement below, mark exactly one:
- ✅ Implemented (cite file:line where it's realized)
- ❌ Not implemented
- ⚠️ Implemented but deviates from spec (describe the concrete difference)

Also check: did the implementor build anything NOT listed below?
Unrequested features = ❌ scope creep.

Requirements:
<list each acceptance criterion from spec.md as a numbered item>

Story:
<full story text from plan.md>

If ANY item is ❌ or ⚠️ → verdict is FAIL. Do not proceed to Part 2.

## Part 2: Code Correctness (only if Part 1 all ✅)

Report ONLY issues that meet at least one of these criteria:
- Can cause a runtime error (with input/scenario that triggers it)
- Can cause data loss or corruption (with sequence of events)
- Is a security vulnerability (with attack vector)
- Contradicts an established pattern in the same codebase (cite the
  existing pattern's file:line alongside the violation)

For each issue: what's wrong, where (file:line), how to trigger it,
how to fix it.

## Verdict

Reply with exactly one of:

PASS — spec fully met, no correctness issues found.

PASS_WITH_CONCERNS — spec met, code can proceed, but: <concerns,
each with file:line and concrete scenario>

FAIL — <issues, each with:>
  - Which part failed (spec / correctness)
  - file:line
  - Evidence (missing requirement, or triggering scenario)
  - How to fix it
```
