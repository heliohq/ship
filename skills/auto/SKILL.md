---
name: auto
version: 0.8.0
description: >
  Full pipeline orchestrator: design → dev → review → QA → simplify → handoff.
  Code-driven coordinator — all state management, artifact validation, phase transitions,
  and retry logic live in scripts/auto-orchestrate.sh. You are a thin relay that
  dispatches Agent() calls and interprets sub-skill responses.
  Use when the task involves a scoped code change.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
  - mcp__codex__codex
  - mcp__codex__codex-reply
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-$HOME/.codex/ship}}"
SHIP_SKILL_NAME=auto source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Auth Gate

If `SHIP_AUTH: not_logged_in`: AskUserQuestion — "Ship requires authentication to use all skills. Login now? (A: Yes / B: Not now)". A → run `ship auth login`, verify with `ship auth status --json`, proceed if logged_in, stop if failed. B → stop.
If `SHIP_AUTO_LOGIN: true`: skip AskUserQuestion, run `ship auth login` directly.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: warn user their token expires soon.

# Ship: Auto

Code-driven orchestrator. You are a thin dispatch relay between
`scripts/auto-orchestrate.sh` (which makes all decisions) and `Agent()` calls
(which do the actual work). Follow the loop below exactly.

**Never** write code, manage state, decide phase transitions, or dispatch agents in background.

---

## Step 1: Initialize or Resume

Run this to start or resume the pipeline:

```bash
SHIP_ORCH="${SHIP_PLUGIN_ROOT}/scripts/auto-orchestrate.sh"
if [ -f .ship/ship-auto.local.md ]; then
  "$SHIP_ORCH" resume
else
  "$SHIP_ORCH" init '<user description goes here>'
fi
```

The script outputs KEY:VALUE lines. Extract these four values:
- `ACTION` — what to do next (`dispatch`, `done`, `escalate`, `error`)
- `PHASE` — current phase name
- `PROMPT_FILE` — path to the prompt file for the agent
- `MESSAGE` — status message to show the user

If `ACTION` is `error` → show MESSAGE to the user and stop.

## Step 2: Dispatch Loop

Repeat while `ACTION` is `dispatch`:

**2a.** Show `MESSAGE` to the user.

**2b.** Read the prompt file and dispatch an agent:

```bash
Read(PROMPT_FILE)
```

Then call:

```
Agent(prompt=<contents of PROMPT_FILE>)
```

**2c.** Read the agent's report card. Every sub-skill outputs a structured
report card with a `Status` field. Map it to a verdict:

| Report Card Status | Verdict |
|-------------------|---------|
| DONE | `success` |
| DONE_WITH_CONCERNS | `success` |
| PASS | `success` |
| FINDINGS | `findings` |
| FAIL | `fail` |
| BLOCKED | `blocked` |
| NEEDS_CONTEXT | `fail` |
| SKIP | `skip` (qa only) |

**Edge cases:**
- No report card in response → classify as `fail`
- Status is BLOCKED but response suggests a fix → classify as `fail`
- When in doubt, lean toward `fail` — the script will retry.

**2d.** If the verdict is `findings` or `fail` and the agent listed specific issues,
save them to a temp file:

```bash
cat > /tmp/ship-findings-$$.md << 'FINDINGS_EOF'
<findings from agent response>
FINDINGS_EOF
```

**2e.** Report the verdict back to the script:

```bash
"${SHIP_PLUGIN_ROOT}/scripts/auto-orchestrate.sh" complete <PHASE> \
  --verdict=<verdict> \
  --summary='<one line summary>' \
  --findings-file=/tmp/ship-findings-$$.md   # only if findings file was created
```

**2f.** Parse the script output for `ACTION`, `PHASE`, `PROMPT_FILE`, `MESSAGE` again.
If `ACTION` is `dispatch` → go back to **2a**.

## Step 3: Terminal

- `ACTION:done` → show MESSAGE to the user. Pipeline complete.
- `ACTION:escalate` → show REASON to the user. Pipeline blocked — user intervention needed.
- `ACTION:error` → show MESSAGE. Something went wrong.

---

## Example

```
── Step 1 ──
Bash("$SHIP_ORCH init 'add dark mode toggle'")
→ ACTION:dispatch  PHASE:design  PROMPT_FILE:.ship/tasks/.../prompts/design.md
  MESSAGE:[Auto] Task created. Starting design phase...

── Step 2a ──
Output: [Auto] Task created. Starting design phase...

── Step 2b ──
Read(.ship/tasks/.../prompts/design.md) → prompt content
Agent(prompt=<prompt content>) → "Design complete. 3 stories."

── Step 2c ──
verdict = success

── Step 2e ──
Bash("$SHIP_ORCH complete design --verdict=success --summary='3 stories'")
→ ACTION:dispatch  PHASE:dev  PROMPT_FILE:.ship/tasks/.../prompts/dev.md
  MESSAGE:[Auto] Design complete. Starting dev...

── (loop continues: dev → review → qa → simplify → handoff → learn → done) ──
```
