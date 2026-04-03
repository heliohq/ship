## [LRN-20260403-001] correction

**Logged**: 2026-04-03T00:00:00+08:00
**Priority**: high
**Status**: pending
**Area**: infra

### Summary
`/ship:auto` subagent dispatches must be phase-locked so imperative task wording cannot override the intended workflow stage.

### Details
When `/ship:auto` forwards context to subagents, raw imperative wording like `Implement ...`, `Fix ...`, or `Run ...` can cause the child agent to anchor on the task verb instead of the pipeline stage. Each dispatch prompt should explicitly state the current phase, the allowed objective for that phase, and the boundary of what the agent must not do. Design should treat the forwarded request as planning context, implementation phases should treat findings as fix context, review/QA should prohibit fixes, and verification steps should prohibit file edits.

### Suggested Action
For every `/ship:auto` dispatch, add a phase-specific preamble like `This is the <phase> phase only`, describe the allowed work for that phase, and wrap forwarded details under a labeled context block instead of passing them as an unscoped imperative instruction.

### Metadata
- Source: user_feedback
- Related Files: skills/auto/SKILL.md
- Tags: ship-auto, design-phase, prompt-contract

---
