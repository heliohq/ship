# Exploratory Testing

Go beyond the spec. Test what a real user might do that the spec didn't
anticipate. Focus on areas touched by the diff.

## Core principle

The spec describes the happy path. Users don't follow the happy path.
Exploratory testing finds what breaks when reality deviates from the spec.

## Per-page exploration checklist (web apps)

For each page/route affected by the diff:

### 1. Visual scan
- Does the page look right?
- Layout broken? Elements overlapping?
- Text truncated or overflowing?
- Images loading?

### 2. Interactive elements
- Click every button, link, toggle
- Do they respond? Do they give feedback?
- Disabled states correct?

### 3. Forms
- Submit empty form — error messages clear?
- Submit with invalid data — validation works?
- Submit twice rapidly — no duplicate entries?
- Very long input — does it break layout?

### 4. Navigation
- Browser back/forward — does it work?
- Deep link — does the URL load the right page?
- Refresh — does the page preserve state?

### 5. Edge cases
- Zero items — empty state shown?
- Many items — pagination/scroll works?
- Special characters — `<script>`, unicode, emoji
- Very long text — truncation or wrap?

### 6. Console
- Any JS errors during interactions?
- Failed network requests?
- Deprecation warnings?

## For API services

- Missing required fields → proper error response?
- Wrong field types → validation error, not 500?
- No auth token → 401, not crash?
- Expired token → 401, not 500?
- Wrong role → 403?
- Concurrent identical requests → no race condition?

## For CLI tools

- No arguments → help message?
- Invalid arguments → clear error?
- Missing input file → descriptive error?
- Very large input → handles or errors gracefully?

## Recording findings

Each exploratory finding:
```
Severity: critical | high | medium | low
Page/endpoint: <where>
Steps to reproduce: <1-2-3>
Evidence: <screenshot or response>
```

## Severity guide

| Severity | Meaning | Example |
|----------|---------|---------|
| Critical | Blocks core workflow, data loss | Submit crashes, data deleted |
| High | Major feature broken, no workaround | Button does nothing |
| Medium | Feature works with problems | Error message unclear |
| Low | Cosmetic, minor polish | Alignment off by a few pixels |

## Important

Exploratory findings do NOT affect the functional MUST/SHOULD score.
They are reported separately. The caller decides whether to fix them.
Critical findings are flagged as PASS_WITH_CONCERNS.
