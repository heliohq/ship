---
name: auto
version: 0.1.0
description: >
  Run Ship's full production workflow from raw requirement to PR: design, dev,
  E2E, review, QA, refactor, and handoff. Use only for explicit /ship:auto,
  auto pipeline requests, or end-to-end delivery.
allowed-tools:
  - Bash
  - Read
  - Agent
  - TodoWrite
---

# Ship: Auto

Full staged workflow for explicit end-to-end production delivery.

## Execution

Resolve `../../scripts/auto-orchestrate.sh` relative to this skill file, then
run the shared stage-aware orchestrator:

```bash
SHIP_ORCH="../../scripts/auto-orchestrate.sh"
if [ -f .ship/ship-auto.local.md ]; then
  "$SHIP_ORCH" resume
else
  "$SHIP_ORCH" init '<user requirement goes here>'
fi
```

Then follow the `/ship:auto` dispatch loop: read `PROMPT_FILE`, dispatch the
agent, classify the report card, and call `complete <PHASE>`.

## Standalone Skill Boundary

`/ship:auto` is only for full production workflow runs. If the user asks for a
specific phase such as design, development, E2E, review, QA, refactor, or
handoff, invoke that standalone `/ship:*` skill directly instead of routing
through auto.
