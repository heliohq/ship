---
name: auto
version: 0.9.0
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
  - TodoWrite
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

## Progress Tracking

Use `TodoWrite` to track your own progress across the pipeline.
Long-running orchestration spans many agent dispatches — todos help you
stay oriented on what's done, what's next, and where you are in the loop.

**Initialize after Step 1** (once you know the task_id):

```
TodoWrite([
  { content: "Design phase",   status: "in_progress", activeForm: "Running design phase" },
  { content: "Dev phase",      status: "pending",     activeForm: "Running dev phase" },
  { content: "Review phase",   status: "pending",     activeForm: "Running review phase" },
  { content: "QA phase",       status: "pending",     activeForm: "Running QA phase" },
  { content: "Simplify phase", status: "pending",     activeForm: "Running simplify phase" },
  { content: "Handoff phase",  status: "pending",     activeForm: "Running handoff phase" },
  { content: "Capture learnings", status: "pending",  activeForm: "Capturing learnings" }
])
```

**Update rules:**
- When a phase dispatches → mark it `in_progress`, mark the prior phase `completed`
- Update `activeForm` with hints from the script's MESSAGE output —
  e.g., `"Design — investigating codebase"` instead of just `"Running design phase"`.
  This gives sub-phase awareness without managing sub-phase todos.
- When `review_fix` or `qa_fix` dispatches → insert a dynamic item:
  `"Fix review findings (round N/3)"` or `"Fix QA issues (round N/3)"`
  with status `in_progress`. Remove it when done.
- On `escalate` → mark the current phase item as `in_progress` (it stays
  visible so the user sees where the pipeline stopped)
- On `done` → mark all remaining items `completed`

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
- **Review phase:** if the response contains ANY P1 or P2 findings, classify
  as `findings` regardless of the Status field. P2s are real issues that must
  be fixed. Only classify review as `success` when there are zero P1/P2
  findings (P3s alone are acceptable). (The orchestrator script also enforces
  this deterministically, but catching it here avoids a wasted round-trip.)
- When in doubt, lean toward `fail` — the script will retry.

**2d. Verify (independent check).**

If the initial verdict is `success` or `skip`, run a lightweight verification
before advancing. This catches cases where the phase agent claims success but
missed explicit requirements from the prompt.

Read `references/phase-verifier.md` for the full verifier prompt. Dispatch a
verification Agent with:

```
Agent(prompt="""
<verifier prompt from references/phase-verifier.md>

## Phase: <PHASE>

## Original Prompt:
<contents of PROMPT_FILE>

## Agent Response:
<the phase agent's full response>

## Artifacts to check:
<list the files the phase should have produced — see artifact map below>
""")
```

**Artifact map** (what each phase must produce):

| Phase | Required artifacts |
|-------|-------------------|
| design | `{{TASK_DIR}}/plan/spec.md`, `{{TASK_DIR}}/plan/plan.md`, `{{TASK_DIR}}/plan/peer-spec.md`, `{{TASK_DIR}}/plan/diff-report.md` |
| dev | Code changes on branch (git diff non-empty) |
| review | `{{TASK_DIR}}/review.md` |
| qa | Files in `{{TASK_DIR}}/qa/` |
| simplify | `{{TASK_DIR}}/simplify.md` |
| handoff | PR exists, checks green |
| learn | Entry in `.learnings/LEARNINGS.md` |

**Map verifier verdict to action:**

| Verifier verdict | Action |
|-----------------|--------|
| `pass` | Keep the original verdict, proceed |
| `pass_with_concerns` | Keep the original verdict, log concerns in summary |
| `fail` | **Downgrade** verdict to `fail` — include the verifier's gap list as findings |

**Skip verification for:** `review_fix`, `qa_fix`, `learn` phases (these are
retry/terminal phases where verification adds overhead but little value).

**2e.** If the verdict is `findings` or `fail` and the agent listed specific issues,
save them to a temp file:

```bash
cat > /tmp/ship-findings-$$.md << 'FINDINGS_EOF'
<findings from agent response>
FINDINGS_EOF
```

**2f.** Report the verdict back to the script:

```bash
"${SHIP_PLUGIN_ROOT}/scripts/auto-orchestrate.sh" complete <PHASE> \
  --verdict=<verdict> \
  --summary='<one line summary>' \
  --findings-file=/tmp/ship-findings-$$.md   # only if findings file was created
```

**2g.** Parse the script output for `ACTION`, `PHASE`, `PROMPT_FILE`, `MESSAGE` again.
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
Agent(prompt=<prompt content>) → "Design complete. 3 stories. [report card: DONE]"

── Step 2c ──
verdict = success (from report card)

── Step 2d (verify) ──
Agent(prompt=<verifier prompt + original prompt + agent response + artifact paths>)
→ "Mandate: fulfilled. Gaps: None. Verdict: pass"
verdict stays success

── Step 2f ──
Bash("$SHIP_ORCH complete design --verdict=success --summary='3 stories, verified'")
→ ACTION:dispatch  PHASE:dev  PROMPT_FILE:.ship/tasks/.../prompts/dev.md
  MESSAGE:[Auto] Design complete. Starting dev...

── (loop continues: dev → review → qa → simplify → handoff → learn → done) ──
```
