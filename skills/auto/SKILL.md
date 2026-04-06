---
name: auto
version: 0.7.0
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

Code-driven orchestrator. The shell script `scripts/auto-orchestrate.sh` owns all
deterministic logic: state management, artifact validation, phase transitions, retry
counting, and prompt generation from templates. You are a thin dispatch relay.

## Core Principle

```
You relay between the orchestration script and Agent() calls.
You interpret natural-language agent responses and report structured verdicts.
You do NOT write code, manage state, or decide phase transitions — the script does.
The script tells you what to do next. Follow it.
```

## Red Flags

**Never:**
- Write code yourself — all code changes go through subagents
- Manage phase state — only the script writes `.ship/ship-auto.local.md`
- Skip calling the script after an agent returns
- Invent a phase transition — the script decides
- Dispatch subagents in background

---

## Dispatch Loop

### Step 1: Initialize or Resume

Check if an active task exists, then call the orchestration script:

```
If .ship/ship-auto.local.md exists:
  result = Bash("${SHIP_PLUGIN_ROOT}/scripts/auto-orchestrate.sh resume")
Else:
  result = Bash("${SHIP_PLUGIN_ROOT}/scripts/auto-orchestrate.sh init '<user description>'")
```

Parse the result for `ACTION`, `PHASE`, `PROMPT_FILE`, and `MESSAGE` (KEY:VALUE lines).

If `ACTION:error` → output the MESSAGE and stop.

### Step 2: Dispatch Loop

While `ACTION` is `dispatch`:

1. **Read the prompt**: `Read(PROMPT_FILE)` to get the agent prompt content.

2. **Output the message**: show `MESSAGE` to the user (e.g. `[Ship] Design complete. Starting dev...`).

3. **Dispatch the agent**: `Agent(prompt=<prompt file contents>)`.

4. **Interpret the response**: read the agent's return and classify it using the Verdict Guide below. Extract:
   - `verdict`: one of `success`, `findings`, `fail`, `blocked`, `skip`
   - `summary`: a one-line description of what happened
   - If the response contains specific findings or issues (review bugs, QA failures), write them to a temp file for the script.

5. **Report back to the script**:
   ```
   result = Bash("${SHIP_PLUGIN_ROOT}/scripts/auto-orchestrate.sh complete <PHASE> --verdict=<verdict> --summary='<summary>' [--findings-file=<path>]")
   ```

6. **Parse the new result** for `ACTION`, `PHASE`, `PROMPT_FILE`, `MESSAGE`.

7. If `ACTION` is `dispatch` → continue the loop (go to step 1).

### Step 3: Terminal

- `ACTION:done` → output MESSAGE to the user. Pipeline complete.
- `ACTION:escalate` → read REASON and PHASE. Output REASON to the user.
  Pipeline blocked at the indicated phase — user intervention needed.
  (The orchestrator already dispatched the learn agent before emitting escalate,
  so learnings are captured. No additional dispatch needed here.)
- `ACTION:error` → output MESSAGE. Something went wrong.

---

## Verdict Interpretation Guide

This is the **one place** where your LLM intelligence is needed. When reading an
agent's return, classify it as one of these verdicts:

| Verdict | When to use |
|---------|-------------|
| `success` | Agent clearly indicates the phase goal is met. Design produced artifacts. Dev completed stories. Review is clean. QA passed. Handoff has PR with green checks. |
| `findings` | Agent reports specific issues that need fixing. Review found P1/P2/P3 bugs. Use only for review and QA phases. |
| `fail` | Agent says it cannot complete. Missing context, broken dependencies, test failures without specific fixable items. |
| `blocked` | Agent needs external input, human decision, or something outside the pipeline's control. |
| `skip` | Agent indicates the phase is not applicable. Only valid for **qa** and **simplify** phases. |

### Tips

- If the agent says "complete" or "done" with specific deliverables → `success`
- If the agent lists bugs/issues but says the review/QA itself completed → `findings`
- If the agent's response is ambiguous, lean toward `fail` — the script will retry
- Always extract the findings text when verdict is `findings` or `fail` — the script
  needs it for the fix prompt

### Writing findings to a file

When the agent returns findings (review bugs, QA failures), write them to a temp file:

```
Bash("cat > /tmp/ship-findings-$$.md << 'FINDINGS_EOF'
<paste the findings section from agent response>
FINDINGS_EOF")
```

Then pass `--findings-file=/tmp/ship-findings-$$.md` to the complete command.

---

## Example Flow

```
── Initialize ──
Bash("auto-orchestrate.sh init 'add dark mode toggle'")
→ ACTION:dispatch  PHASE:design  PROMPT_FILE:.ship/tasks/.../prompts/design.md

── Design ──
Read(.ship/tasks/.../prompts/design.md) → prompt
Agent(prompt=<prompt>) → "Design complete. 3 stories. Artifacts written."
Bash("auto-orchestrate.sh complete design --verdict=success --summary='3 stories'")
→ ACTION:dispatch  PHASE:dev  PROMPT_FILE:.ship/tasks/.../prompts/dev.md

── Dev ──
Agent(prompt=<dev prompt>) → "Implementation complete. All tests pass."
Bash("auto-orchestrate.sh complete dev --verdict=success --summary='3/3 stories done'")
→ ACTION:dispatch  PHASE:review  PROMPT_FILE:.ship/tasks/.../prompts/review.md

── Review (with findings) ──
Agent(prompt=<review prompt>) → "Found 2 bugs: P1 null check, P2 stale fallback"
Write findings to /tmp/ship-findings-123.md
Bash("auto-orchestrate.sh complete review --verdict=findings --summary='2 bugs' --findings-file=/tmp/ship-findings-123.md")
→ ACTION:dispatch  PHASE:review_fix  PROMPT_FILE:.ship/tasks/.../prompts/dev-fix.md

── Review Fix ──
Agent(prompt=<fix prompt>) → "Fixed both bugs. Tests pass."
Bash("auto-orchestrate.sh complete review_fix --verdict=success --summary='2 bugs fixed'")
→ ACTION:dispatch  PHASE:review  PROMPT_FILE:.ship/tasks/.../prompts/review.md

── Review (clean) ──
Agent(prompt=<review prompt>) → "No bugs found."
Bash("auto-orchestrate.sh complete review --verdict=success --summary='clean'")
→ ACTION:dispatch  PHASE:qa  ...

── (continues through QA → simplify → handoff → learn → done) ──
```
