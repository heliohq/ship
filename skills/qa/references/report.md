# QA Report Template

## Machine-readable header (first content line)

```
<!-- QA_RESULT: <PASS|FAIL|SKIP> <functional>/10 MUSTS:<p>/<t> SHOULDS:<p>/<t> CRITERIA:<total> HEALTH:<health>/10 EXPLORATORY:<count> -->
```

Examples:
- `<!-- QA_RESULT: PASS 9/10 MUSTS:4/4 SHOULDS:2/3 CRITERIA:7 HEALTH:10/10 EXPLORATORY:1 -->`
- `<!-- QA_RESULT: FAIL 3/10 MUSTS:1/4 SHOULDS:2/3 CRITERIA:7 HEALTH:7/10 EXPLORATORY:3 -->`
- `<!-- QA_RESULT: SKIP 0/10 MUSTS:0/0 SHOULDS:0/0 CRITERIA:0 HEALTH:0/10 EXPLORATORY:0 -->`

## Full template

````markdown
# QA Evaluation Report

<!-- QA_RESULT: <verdict> <functional>/10 MUSTS:<p>/<t> SHOULDS:<p>/<t> CRITERIA:<total> HEALTH:<health>/10 EXPLORATORY:<count> -->

## Metadata

| Field | Value |
|-------|-------|
| Date | <YYYY-MM-DD HH:MM UTC> |
| HEAD | <short sha> |
| Spec | <relative path to spec.md> |
| App type | <web app / API / CLI / library> |
| Browser | <Chrome MCP / Computer Use / none> |
| Duration | <seconds>s |

## Rubric

Full rubric: [rubric.md](rubric.md)

## Functional Results

| # | Criterion | Type | Verdict | Evidence | Link |
|---|-----------|------|---------|----------|------|
| 1 | <name> | MUST | PASS/FAIL | L1/L2 | [detail](#criterion-1) |
| 2 | <name> | SHOULD | PASS/FAIL/SKIP | L1/L2 | [detail](#criterion-2) |

### Criterion 1: <name>

- **Type:** MUST
- **Verdict:** PASS / FAIL
- **Evidence level:** L1 / L2
- **Test method:** <what was done>

**Evidence:**
<screenshot path, curl output, console log>

**Rationale:**
<why this verdict>

---

<!-- Repeat for each criterion -->

## Exploratory Findings

| # | Finding | Severity | Page/Endpoint |
|---|---------|----------|---------------|
| 1 | <description> | critical/high/medium/low | <where> |

### Finding 1: <description>

- **Severity:** <level>
- **Steps to reproduce:** <1-2-3>
- **Evidence:** <screenshot or response>

---

## Health Report

| Check | Result | Threshold |
|-------|--------|-----------|
| Console errors | <N> | 0 |
| HTTP 500s | <N> | 0 |
| Page load time | <X>s | <5s |
| Broken assets | <N> | 0 |
| A11y warnings | <N> | report only |

Health score: <health>/10

<!-- ===== FAIL verdict ===== -->

## Principal Failure

**<criterion name>** (MUST) — <one-sentence summary>

- Expected: <from rubric>
- Observed: <from evidence>
- Root cause: <analysis>
- **Fix guidance:** <file, function, direction>

### Secondary Failures

- **<name>** (<type>) — <summary>. Likely caused by principal failure: yes/no.

### Suggestions

1. **[Principal]** <actionable fix for main failure>
2. **[Secondary]** <fix for next failure>
3. **[Exploratory]** <fix for notable exploratory finding>

<!-- ===== PASS verdict ===== -->

## Summary

All MUST criteria passed. <functional>/10 functional, <health>/10 health.

### SHOULD Warnings
- **<name>** — <what was not fully satisfied>

### Notable Exploratory Findings
- <any findings worth awareness>
````

## Verdict rules

1. Any MUST FAIL → overall **FAIL**
2. Any MUST with only L2 evidence → overall **FAIL**
3. All MUST PASS + functional >= 7 → overall **PASS**
4. All MUST PASS + health < 5 → **PASS_WITH_CONCERNS**
5. All MUST PASS + critical exploratory finding → **PASS_WITH_CONCERNS**
6. No criteria evaluated → overall **SKIP**

## Important

- Do NOT retry failed criteria. Record and move on.
- FAIL feedback must lead with principal failure, not a laundry list.
- Include only first 500 chars of response bodies in evidence.
- Every MUST criterion requires L1 evidence when browser is available.
