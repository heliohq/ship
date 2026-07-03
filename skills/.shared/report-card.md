# Report Card Format

Ship skills end with a report card. How much of it to emit depends on
who is reading:

- **Dispatched runs** (under /ship:auto or any Agent() call): output the
  full card below, verbatim structure — the caller machine-parses the
  `Status` field and relays the rest. This is a contract, not a style.
- **Standalone with a human**: the reader is a person, not a parser.
  Lead with the outcome in one or two sentences of prose, keep the
  `Status | Summary` table, and include Metrics/Artifacts tables only
  when the counts or paths genuinely help. Offer next steps
  conversationally instead of the canned list — and only ones that make
  sense for what just happened.

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

In dispatched runs, always include Next Steps — the orchestrator reads
them to route the pipeline:

```markdown
### Next Steps
1. **Recommended** — /ship:<next-skill>
2. **Alternative** — /ship:<other-skill>
3. **Other** — <description>
```

## Phase-Specific Metrics

| Phase | Metrics |
|-------|---------|
| Auto | Phases completed, Review fix rounds, QA fix rounds, E2E fix rounds, Total agents dispatched |
| Design | Stories count, Files traced, Divergences resolved, Drill steps CLEAR |
| Dev | Stories completed, Waves, Concerns, Test result |
| Review | P1/P2/P3 counts (or "Clean") |
| QA | Criteria passed/total, Issues beyond spec |
| E2E | Framework (pre-existing/scaffolded), Tests added, Suite pass rate, Regressions |
| Refactor | Smells fixed, Lines before/after, Functions extracted, Dead code deleted |
| Handoff | PR URL, Check status, Fix rounds |
| Arch Design | Lenses applied, Alternatives rejected, Assumptions recorded, Revisit triggers |
| Write Docs | Docs created, Docs updated, Index regenerated |

## Status Values

| Status | Meaning |
|--------|---------|
| DONE | Phase goal met, no issues |
| DONE_WITH_CONCERNS | Goal met but residual concerns logged |
| FINDINGS | Goal met but issues found that need fixing (review/QA) |
| BLOCKED | Cannot proceed without external input |
| SKIP | Phase not applicable |
