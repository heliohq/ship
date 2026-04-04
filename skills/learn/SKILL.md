---
name: learn
version: 1.0.0
description: >
  Capture learnings from sessions to prevent repeating mistakes.
  Reflects on what went wrong or was discovered, routes each learning
  to the right store (conventions, hookify, design doc, or staging).
  Use when: learn, what did we learn, capture learning, session retro,
  avoid this mistake, remember this.
  Auto-invoked at the end of /ship:auto pipelines.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CODEX_HOME:-$HOME/.codex}/ship}}"
SHIP_SKILL_NAME=learn source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: Learn

Every session makes the harness stronger. This skill captures what
was discovered or went wrong and routes it to the right persistent
store so future sessions don't repeat the same mistakes.

**Learnings staging file:** `.ship/learnings.md`

This file is a **staging area**, not a permanent store. Learnings that
prove durable get promoted to permanent stores and removed from staging.
Learnings that are transient or wrong get pruned.

## Red Flag

**Never:**
- Capture obvious or trivial learnings ("npm install installs packages")
- Capture transient errors (network blips, rate limits, one-time CI flakes)
- Let the staging file grow beyond ~30 entries — prune or promote
- Promote a learning without verifying it against current code
- Skip the routing step — every learning belongs in a specific store

---

## Detect Mode

Parse the input to determine which mode to run:

- `/ship:learn` (no arguments, or end of auto pipeline) → **Capture**
- `/ship:learn promote` → **Promote**
- `/ship:learn prune` → **Prune**
- `/ship:learn show` → **Show**

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

For each learning, classify where it belongs:

| Learning type | Destination | Example |
|---|---|---|
| Code constraint requiring AI judgment | `.ship/rules/CONVENTIONS.md` | "Don't simplify auth flows to fix errors" |
| Deterministic check (grep/regex can catch) | Hookify rule | "Never commit files matching *.env*" |
| Architectural decision or boundary | Design doc (`docs/design/`) | "Services A and B must not share a database" |
| Operational knowledge (everything else) | `.ship/learnings.md` (staging) | "CI test X is flaky — retry before filing bug" |

### Step 3: Write

**For convention rules:** append to `.ship/rules/CONVENTIONS.md` using the existing format:
```markdown
## <Rule name>
Scope: <glob pattern>
Constraint: <what must not happen>
Why: <what breaks>
Source: learned from session <date>
```

**For hookify rules:** invoke `Skill("hookify:writing-rules")` and generate the rule file.

**For design docs:** invoke `Skill("write-design-docs")` if the learning is substantial enough for a design doc. Otherwise append to an existing design doc's Boundaries section.

**For staging (operational knowledge):** append to `.ship/learnings.md`:
```markdown
## <Short title>
- Scope: <affected files/directories>
- Learned: <YYYY-MM-DD>
- Source: <what happened — one sentence>
```

Create `.ship/learnings.md` if it doesn't exist, with this header:
```markdown
# Learnings (Staging)

> Operational knowledge from recent sessions. Entries that prove durable
> get promoted to CONVENTIONS.md, hookify rules, or design docs.
> Run `/ship:learn promote` to review and promote. Run `/ship:learn prune`
> to clean stale entries.
```

### Step 4: Confirm

When invoked standalone, use AskUserQuestion to confirm each learning
before writing. Show the learning and its destination.

When invoked by `/ship:auto` (end of pipeline), capture silently —
only show a summary of what was captured.

---

## Mode: Promote

Review staging entries and promote durable ones to permanent stores.

### Step 1: Read `.ship/learnings.md`

If it doesn't exist or is empty, report "No learnings to promote" and stop.

### Step 2: For each entry

Ask via AskUserQuestion:

```
Learning: "<title>"
  Scope: <scope>
  Learned: <date>
  Source: <source>

Options:
  A) Promote to CONVENTIONS.md (code rule)
  B) Promote to hookify (deterministic check)
  C) Promote to design doc (architectural)
  D) Keep in staging
  E) Remove (no longer relevant)
```

### Step 3: Execute promotions

- A → append to CONVENTIONS.md, remove from learnings.md
- B → generate hookify rule, remove from learnings.md
- C → create/update design doc, remove from learnings.md
- D → keep as-is
- E → remove from learnings.md

---

## Mode: Prune

Remove stale or invalid learnings from staging.

### Step 1: Read `.ship/learnings.md`

### Step 2: For each entry

Check:
- **Age**: entries older than 30 days without promotion are candidates
- **Scope validity**: do the files/directories in Scope still exist?
- **Redundancy**: is this already covered by a CONVENTIONS.md rule or design doc?

### Step 3: Present candidates

Show stale/invalid entries via AskUserQuestion:
- A) Remove
- B) Keep
- C) Promote now

---

## Mode: Show

Display current learnings grouped by age.

Read `.ship/learnings.md` and present:
- Recent (< 7 days)
- Aging (7-30 days) — suggest promote or prune
- Stale (> 30 days) — suggest prune

---

## Session Start Integration

`.ship/learnings.md` is injected into every session by `session-start.sh`
alongside CONVENTIONS.md and DESIGN_INDEX.md. This gives the AI
context about recent operational discoveries without manual lookup.

## Execution Handoff

Output summary:

```
[Learn] Session captured.
  New learnings: <N>
  Routed to:
    - CONVENTIONS.md: <N> rules added
    - Hookify: <N> rules generated
    - Design docs: <N> updated
    - Staging: <N> entries added
  Staging total: <N> entries (<N> recent, <N> aging, <N> stale)

## What's next?
1. **Promote** — run /ship:learn promote to review staging
2. **Prune** — run /ship:learn prune to clean stale entries
3. **Continue** — learnings are captured, keep working
```
