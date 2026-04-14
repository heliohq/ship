---
name: using-ship
description: Use when starting any conversation involving software engineering tasks — planning, coding, reviewing, testing, refactoring, or shipping code changes. Establishes how to route work through the ship pipeline (design → dev → review → qa → refactor → handoff), requiring Skill tool invocation before ANY response including clarifying questions.
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a `/ship:*` skill applies to what you are doing, you ABSOLUTELY MUST invoke it via the Skill tool.

IF A SHIP SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. This is not optional. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## Instruction Priority

Ship skills override default system prompt behavior, but **user instructions always take precedence**:

1. **User's explicit instructions** (CLAUDE.md, AGENTS.md, direct requests) — highest priority
2. **Ship skills** — override default system behavior where they conflict
3. **Default system prompt** — lowest priority

If the user says "just edit the file directly, skip the pipeline," follow the user. The user is in control.

## How to Access Skills

**In Claude Code:** Use the `Skill` tool. When you invoke a skill, its content is loaded and presented to you — follow it directly. Never use the Read tool on skill files.

**In Cursor:** Same — use the `Skill` tool.

**In Codex CLI:** Skills are exposed as slash commands (`/ship:auto`, `/ship:design`, etc.). Invoke them the same way you would any other command.

# Using Ship

Ship is a full software delivery pipeline packaged as skills. Each skill handles one phase of work:

```
design → dev → review → qa → refactor → handoff
   ↓       ↓      ↓       ↓       ↓         ↓
  plan   code   bugs   runtime cleanup    PR
                       checks
```

`/ship:auto` runs the whole pipeline end-to-end. The individual skills run one phase at a time.

## The Rule

**Invoke the relevant `/ship:*` skill BEFORE any response or action.** Even a 1% chance a skill might apply means you should invoke it to check. If an invoked skill turns out to be wrong for the situation, you don't need to use it.

This applies to:
- Clarifying questions — check for skills FIRST
- "Quick" edits — check for skills FIRST
- Codebase exploration — check for skills FIRST
- Planning discussions — check for skills FIRST

## When to Use Each Skill

| Trigger condition | Invoke |
|---|---|
| User wants to plan/scope/investigate before coding ("plan this", "how should we implement", "what's the best approach", "scope the work") | `/ship:design` |
| User wants the full pipeline end-to-end — plan, code, review, test, ship ("ship this", "build end to end", "implement and ship", "full pipeline") | `/ship:auto` |
| A plan/stories already exist and need implementation ("implement this plan", "execute the stories", "code this up from the plan") | `/ship:dev` |
| Code changes need correctness review — static analysis, not runtime ("review the code", "check for bugs", "is this correct", "code review") | `/ship:review` |
| Code needs runtime testing — start the app and verify behavior ("test this", "QA the changes", "does it actually work", "run QA") | `/ship:qa` |
| Code is done, needs PR creation and CI ("ship it", "create a PR", "open a pull request", "push and merge") | `/ship:handoff` |
| Refactoring or cleanup — no new features ("refactor", "clean up", "simplify", "reduce duplication", "dead code") | `/ship:refactor` |
| System architecture design thinking ("design this system", "what's the architecture", "trade-offs for X", "how should we architect", "system design for") | `/ship:arch-design` |
| Creating/editing documentation under docs/ ("write a doc", "document this", "create a guide", "write a design doc", "create an ADR", "update the docs") | `/ship:write-docs` |
| Creating/editing DESIGN.md visual design systems ("design tokens", "color palette", "typography", "visual design system") | `/ship:visual-design` |
| Bootstrapping repo infrastructure ("setup", "init", "bootstrap", "configure CI") | `/ship:setup` |
| Capturing session learnings ("what did we learn", "capture learning", "avoid this mistake") | `/ship:learn` |

## Auto vs Individual Phases

- **`/ship:auto`** — when the user wants the whole thing. "Ship this feature." "Build end to end." Any scoped code change that should go from idea to merged PR.
- **Individual phases** — when the user explicitly asks for one phase. "Just review this." "Run QA only." "I already have a plan, just implement it."

When in doubt between `/ship:auto` and individual skills, prefer `/ship:auto` for feature work and individual skills for targeted phases.

## Red Flags

These thoughts mean STOP — you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is a simple fix, no pipeline needed" | Simple fixes accumulate bugs. Use `/ship:auto` or `/ship:dev`. |
| "Let me just explore the codebase first" | `/ship:design` tells you HOW to explore. Check first. |
| "I'll answer the clarifying question, then invoke the skill" | Skill check comes BEFORE clarifying questions. |
| "This is just a code review, I can eyeball it" | `/ship:review` has structured checks. Use it. |
| "The user said 'fix this' so I should fix it" | "Fix this" means "run the fix pipeline" — usually `/ship:auto`. |
| "I'll skip design and go straight to code" | Design prevents rework. Don't skip it on feature work. |
| "This doesn't need formal QA" | `/ship:qa` catches runtime bugs static checks miss. |
| "I know how to write a PR" | `/ship:handoff` ensures CI and conventions pass. Use it. |
| "Refactoring is just cleanup, no need for a skill" | `/ship:refactor` bundles dead-code detection + simplification. |
| "I'll capture learnings later" | "Later" = "never." `/ship:learn` is one command. |

## Phase Ordering

Phases depend on each other. Respect the order:

1. **Design** produces spec + plan. Required input for dev.
2. **Dev** implements the plan. Required input for review.
3. **Review** is static analysis (no app runtime). Catches logic bugs.
4. **QA** is runtime verification (start the app, exercise features). Catches integration bugs.
5. **Refactor** is polish after functionality is verified. Never before.
6. **Handoff** creates the PR and waits for CI. Final step.

`/ship:auto` enforces this order. Individual skills let you resume from any phase if you already have the upstream artifacts.

## Skill Priority

When multiple skills could apply:

1. **Pipeline skills first** (`/ship:auto`, `/ship:design`, `/ship:dev`, etc.) — these are the main delivery path.
2. **Side skills second** (`/ship:arch-design`, `/ship:write-docs`, `/ship:visual-design`) — these handle adjacent artifacts, not code delivery.
3. **Meta skills last** (`/ship:setup`, `/ship:learn`) — these manage the pipeline itself.

"Let's build X" → `/ship:auto`. "Document the X system" → `/ship:write-docs`. "What did we learn?" → `/ship:learn`.

## User Instructions Win

Instructions say WHAT, not HOW. "Add X" or "Fix Y" doesn't mean skip the pipeline — it means run the pipeline to add X or fix Y. But if the user explicitly says "skip the pipeline, just edit the file directly," follow them. The user is in control.

## When Not to Invoke a Ship Skill

- Pure Q&A: "what does this function do?" — read the code and answer. No pipeline needed.
- External research: "how does Postgres handle X?" — answer from knowledge, no pipeline.
- Tiny one-line doc fix on an existing file: Edit directly. Pipeline is overkill.
- Conversations with no code outcome: talking through trade-offs without committing to an implementation.

Everything else — if there's any chance it will result in a code change, a plan, a review, or an artifact under `docs/` — invoke the matching `/ship:*` skill.
