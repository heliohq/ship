# Functional Testing

Verify each spec criterion against the running application. Not code
review — real interaction with the product.

Evidence Hierarchy is defined in SKILL.md (the authoritative source).

## Rubric item structure

Each criterion gets a rubric item:

| Field | Description |
|-------|-------------|
| Name | Short identifier |
| Type | MUST or SHOULD |
| Hidden Assumptions | Sub-checks the criterion depends on (Assumption Audit) |
| Full Marks | What PASS looks like (specific, observable) |
| Fail Signals | What FAIL looks like |
| Test Method | How to verify against the running app |
| Evidence Level | L1 for MUST, L1 or L2 for SHOULD |

## Assumption Audit

For each criterion, identify hidden assumptions:

Example: "Dashboard shows user count"
- Hidden: dashboard page loads without error
- Hidden: user count API returns data
- Hidden: count is rendered in expected location

Each assumption becomes a sub-check. Prevents false PASSes.

## Execution order

1. All MUST criteria first (in rubric order)
2. Then SHOULD criteria
3. Check time budget before each — skip remaining if running late

## Scoring

```
functional = (passed_musts / total_musts) * 7 + (passed_shoulds / total_shoulds) * 3
```

- 10/10 = all pass
- 7/10 = all MUST pass, all SHOULD fail (minimum passing)
- <7 = at least one MUST failed
- No SHOULDs: `(passed_musts / total_musts) * 10`
- No MUSTs: malformed spec = FAIL
