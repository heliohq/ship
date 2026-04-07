# Report Card Format

All Ship skills output a structured report card at the end of execution.
This format is consistent across all skills so users always know where to look.

## Template

```markdown
## [Phase] Report Card

| Field | Value |
|-------|-------|
| Status | <DONE / DONE_WITH_CONCERNS / FINDINGS / BLOCKED / SKIP> |
| Summary | <one-line description of what happened> |

### Metrics
| Metric | Value |
|--------|-------|
| <phase-specific metric> | <value> |

### Artifacts
| File | Purpose |
|------|---------|
| <path> | <what it is> |
```

In standalone mode, append:

```markdown
### Next Steps
1. **Recommended** — /ship:<next-skill>
2. **Alternative** — /ship:<other-skill>
3. **Other** — <description>
```

In /ship:auto mode, skip the Next Steps section — Auto owns the flow.

## Phase-Specific Metrics

| Phase | Metrics |
|-------|---------|
| Design | Stories count, Files traced, Divergences resolved, Drill steps CLEAR |
| Dev | Stories completed, Waves, Concerns, Test result |
| Review | P1/P2/P3 counts (or "Clean") |
| QA | Criteria passed/total, Issues beyond spec |
| Refactor | Smells fixed, Lines before/after, Functions extracted, Dead code deleted |
| Handoff | PR URL, Check status, Fix rounds |
| Learn | Entries captured, Verified, Pruned |

## Status Values

| Status | Meaning |
|--------|---------|
| DONE | Phase goal met, no issues |
| DONE_WITH_CONCERNS | Goal met but residual concerns logged |
| FINDINGS | Goal met but issues found that need fixing (review/QA) |
| BLOCKED | Cannot proceed without external input |
| SKIP | Phase not applicable |
