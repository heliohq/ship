---
name: learn
version: 1.0.0
description: >
  Capture learnings from sessions to prevent repeating mistakes.
  Reflects on what went wrong or was discovered, routes each learning
  to .learnings/LEARNINGS.md (and hookify/design docs when applicable).
  Use when: learn, what did we learn, capture learning, session retro,
  avoid this mistake, remember this, show learnings, list learnings,
  what do we know, current learnings.
  Auto-invoked at the end of /ship:auto pipelines.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-$(ship-plugin-root 2>/dev/null || echo "$HOME/.codex/ship")}"
SHIP_SKILL_NAME=learn source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Ship CLI (optional)

The Ship CLI enables cloud features (team channels, task assignment) but is **not required** for core skills.
If `SHIP_CLI: not_installed`: proceed normally — all local skills work without it.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: mention token expiry to user.

# Ship: Learn

Every session makes the harness stronger. This skill captures what
was discovered or went wrong and routes it to the right persistent
store so future sessions don't repeat the same mistakes.

**Learnings file:** `.learnings/LEARNINGS.md`

This is the **single persistent store** for all project learnings.
Verified entries are rules — they replace what CONVENTIONS.md used to be.
Pending entries are fresh observations that auto-verify when validated
or auto-prune when stale.

## Red Flag

**Never:**
- Capture obvious or trivial learnings ("npm install installs packages")
- Capture transient errors (network blips, rate limits, one-time CI flakes)
- Let the file grow beyond ~30 entries — prune stale ones
- Mark a learning as verified without checking it against current code
- Skip classification — every learning needs a type, priority, and status

---

## Detect Mode

Parse the input to determine which mode to run:

- `/ship:learn` (no arguments, or end of auto pipeline) → **Capture** (includes auto-promote and auto-prune)
- `/ship:learn show` → **Show** current staging entries and their status

---

## Mode: Capture

Reflect on the current session and capture learnings.

### Step 1: Reflect

Review the conversation for:
- **Mistakes made** — wrong approach tried, then corrected
- **Surprises** — code behaved differently than expected
- **Project quirks** — build flags, env setup, timing, ordering requirements
- **Patterns that worked** — approaches that should be repeated
- **User corrections** — things the user told you to do differently

The test for each: **would knowing this save 5+ minutes in a future session?** If not, skip it.

### Step 2: Route

For each learning, classify its type and priority, then write to
`.learnings/LEARNINGS.md` — the single store for all learnings.

**Additionally** (both optional — skip if the tool/skill is unavailable):
- If the learning is a deterministic check (grep/regex can catch it)
  AND hookify is installed, also generate a hookify rule via
  `Skill("hookify:writing-rules")`.
- If it's substantial enough for a design doc, also invoke
  `Skill("arch-design")`.

### Step 3: Write

Append to `.learnings/LEARNINGS.md` using this format:

```markdown
## [LRN-YYYYMMDD-NNN] <type>

**Logged**: <ISO 8601 timestamp>
**Priority**: high | medium | low
**Status**: pending | verified
**Area**: <infra | code | ci | qa | design | ops>

### Summary
<One sentence — the core insight>

### Details
<What happened, why it matters, what the impact was>

### Suggested Action
<What to do differently next time>

### Metadata
- Source: <session_observation | user_feedback | auto_detected>
- Related Files: <file paths>
- Tags: <relevant tags>

---
```

**ID format:** `LRN-YYYYMMDD-NNN` where NNN is a zero-padded sequence
number for that day. Check existing entries to avoid duplicates.

**Type:** one of: `correction`, `pattern`, `pitfall`, `quirk`, `preference`

**Status:**
- `pending` — fresh from this session, not yet validated
- `verified` — confirmed against code, high confidence (equivalent to
  what was previously a convention rule)

Create `.learnings/LEARNINGS.md` if it doesn't exist.

High-confidence learnings (clear code constraints, user corrections,
repeated patterns) should be written directly as `Status: verified`.
Uncertain or operational learnings start as `Status: pending`.

---

## Auto-Verify and Auto-Prune (runs during capture)

When adding new learnings, also scan existing entries:

### Verify detection

A pending entry should be upgraded to `verified` when:
- **Repeated**: the same insight was captured again (validates it)
- **Aged + still valid**: older than 14 days AND related files still exist
- **User confirmed**: the user explicitly agreed with the learning

Update the entry's Status to `verified` in place.

### Prune detection

An entry should be removed when:
- **Scope invalid**: the files/directories in Related Files no longer exist
- **Stale**: older than 30 days and still `pending` (never verified)
- **Contradicted**: a newer learning or code change contradicts it

Auto-prune: remove from file silently.

### Safety

- Never auto-verify if the insight contradicts an existing verified entry
- Never auto-prune a learning that was added in the current session
- Log all promotions and prunes in the Execution Handoff output so the user can review

---

## Mode: Show

Display current learnings grouped by status.

Read `.learnings/LEARNINGS.md` and present:
- Recent (< 7 days)
- Promotion candidates (> 14 days, still valid)
- Prune candidates (scope invalid, redundant, or > 30 days)

---

## Session Start Integration

`.learnings/LEARNINGS.md` is injected into every session by `session-start.sh`
alongside DOCS_INDEX.md. This gives the AI
context about recent operational discoveries without manual lookup.

## Execution Handoff

Output the report card (read `skills/shared/report-card.md` for the standard format):

```
## [Learn] Report Card

| Field | Value |
|-------|-------|
| Status | DONE |
| Summary | <N> learnings captured |

### Metrics
| Metric | Value |
|--------|-------|
| New entries | <N> |
| Verified | <N> |
| Pending | <N> |
| Auto-promoted | <N> pending → verified |
| Auto-pruned | <N> stale/contradicted removed |
| Hookify rules | <N> generated |
| Total entries | <N> (<V> verified, <P> pending) |

### Artifacts
| File | Purpose |
|------|---------|
| .learnings/LEARNINGS.md | Persistent learnings store |
```
