# Reviewer — Peer Cross-Validation Prompt

Used in Phase 2 Step B of `/ship:dev`. The peer (Codex when host is
Claude, vice versa) reviews each story independently — different
provider, different session from whoever implemented the code.

## Dispatch (preferred: peer for cross-provider independence)

```
mcp__codex__codex({
  prompt: <prompt below, with all placeholders filled>
})
```

If the peer runtime is unavailable (e.g., Codex MCP not configured),
fall back to a fresh Claude Agent subagent — same-provider review is
weaker than cross-provider, so note this in the dev report:

```
Agent({
  prompt: <prompt below, with all placeholders filled>,
  subagent_type: "general-purpose",
  description: "Review story <i>/<N>"
})
```

The reviewer's job is to **validate**, not to write code. If you
(reviewer) identify a fix, describe it in the FAIL findings — the host
will apply the fix themselves and re-dispatch you for a fresh review.

## Philosophy: Verification Principle

Every finding must include verifiable evidence (file:line + reproducible
scenario), or it is not a valid finding. This prevents both sycophantic
approval and adversarial nitpicking.

## Prompt

```text
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

Inspect this story's changes. The host will tell you how:

- **Single-story waves**: `git diff <WAVE_BASE_SHA>..HEAD` covers this story.
- **Multi-story waves**: the host passes a list of commit SHAs
  produced by this story (other stories in the wave may be interleaved
  on the branch — do NOT assume a contiguous range). Inspect each with
  `git show <sha>` or `git diff <sha>^..<sha>`.

Review only this story's scope. Changes from other stories in the same
wave are out of scope for this review.

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

Report ONLY issues that meet at least one of:
- Can cause a runtime error (with input/scenario that triggers it)
- Can cause data loss or corruption (with sequence of events)
- Is a security vulnerability (with attack vector)
- Contradicts an established codebase pattern (cite existing file:line)
- Lets tests pass while real behavior is still wrong, including fixture-coupled logic, hardcoded expected values, or harness manipulation

Treat reward-hacking-style shortcuts as correctness failures, not clever implementation.

For each issue: what's wrong, where (file:line), how to trigger, how to fix.

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
