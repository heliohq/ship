---
name: dev
version: 0.6.0
description: >
  Execute implementation stories from a plan via parallel waves. Dependency analysis
  groups independent stories into waves that run in parallel via git worktrees; each
  story is reviewed independently, and waves merge before proceeding. Use when:
  "implement this plan", "execute the stories", "code this up", "build from the plan",
  or when a plan/stories already exist and need implementation. Note: if no plan exists
  yet, use /ship:design first. For the full pipeline (plan → code → review → QA → ship),
  use /ship:auto.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
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
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-$(ship-plugin-root 2>/dev/null || echo "$HOME/.codex/ship")}"
SHIP_SKILL_NAME=dev source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```


# Ship: Implement

```
HOST IMPLEMENTS. PEER CROSS-VALIDATES.
EVERY FINDING NEEDS FILE:LINE + EVIDENCE.
```

## Runtime Resolution

See `../shared/runtime-resolution.md` for the host/peer concept and
dispatch commands. In /ship:dev, the **host is the primary implementer**
and the **peer (Codex when host is Claude, vice versa) is the independent
reviewer** — cross-validation across providers.

Two wave shapes, different dispatch patterns:

| Wave shape | Implementer | Reviewer |
|---|---|---|
| **Single-story** (most common) | Host (you), directly in current branch | Peer via `mcp__codex__codex` |
| **Multi-story parallel** | Fresh Claude Agent subagents per story, each in its own worktree (you cannot fork yourself) | Peer for each story diff |
| **Fix loop** | Host (you) — you already have the context, no dispatch needed | Peer re-reviews |

The independence contract — reviewer MUST differ from implementer —
is met two ways: different provider (Codex ≠ Claude) AND different
session. Both hold across all wave shapes.

## Roles

| Role | Who |
|------|-----|
| Orchestrator + primary implementer | **You (host agent)** — implement directly in single-story waves and fix loops |
| Parallel implementer | **Fresh Claude Agent subagent** — only in multi-story parallel waves, each in a git worktree |
| Reviewer | **Peer agent (Codex)** — fresh dispatch per story |

## Quality Gates

| Gate | Condition | Fail action |
|------|-----------|-------------|
| Spec + plan read | Acceptance criteria extracted, TEST_CMD found | AskUserQuestion |
| Implement → Review | STORY_HEAD_SHA != STORY_START_SHA (commits exist) | BLOCKED |
| Review → Next story | Verdict is PASS or PASS_WITH_CONCERNS | Targeted fix (max 2) |
| All stories → Done | Full test suite passes | Targeted fix for regression |

## Red Flag

**Never:**
- Skip the peer review — every story goes through Codex (or fallback)
  before the wave merges. This is the only cross-validation in the
  pipeline until /ship:review runs.
- Parallelize stories that share files without dependency analysis
- Re-implement a full story on FAIL — make targeted surgical fixes
- Advance to next story without getting a reviewer verdict
- Soften a test assertion to make it pass instead of fixing the code
- In multi-story waves: omit prior stories' context from each dispatched
  implementer prompt
- Reuse a reviewer dispatch across stories — fresh peer call each time
- Let the peer reviewer become your coder — if the reviewer suggests a
  fix, YOU apply it; don't ask the reviewer to write patches

---

## Progress Tracking

Use `TodoWrite` to track your own progress through implementation.
Build the todo list after Phase 1 (setup), once you know the actual
wave/story structure. The items should reflect the real work — don't
use a canned template.

**Principle**: one todo per wave (not per story) to keep the list short.
Use `activeForm` to show which story within a wave is active.
Always end with a regression test item when there are multiple stories.

**Example** (3-wave normal run):

```
TodoWrite([
  { content: "Wave 1: \"Add User model\", \"Add Product model\"",
    status: "in_progress", activeForm: "Implementing Story 1" },
  { content: "Wave 2: \"User API\", \"Product API\"",
    status: "pending", activeForm: "Implementing Wave 2" },
  { content: "Wave 3: \"Auth middleware\"",
    status: "pending", activeForm: "Implementing Wave 3" },
  { content: "Cross-story regression test",
    status: "pending", activeForm: "Running regression test" }
])
```

**Adaptations** (not exhaustive — use judgment):
- Single-story task → one item for the story + one for regression, no wave labels
- Fix mode (invoked with findings) → single item: `"Fix <review/QA> findings"`
- Targeted fix within a wave → update that wave's `activeForm`:
  `"Fixing Story N (round R/2)"`
- All stories in one wave (no parallelism) → list stories individually
  instead of grouping by wave

---

## Phase 1: Setup

1. Read **acceptance criteria** (from spec file, or derived from user request).
2. Read **implementation stories** (from plan file, or single story for small tasks).
   Accept any heading format: `## Story N`, `## Step N`, `## N. Title`,
   or numbered/bulleted lists. Normalize as ordered stories.
3. Detect the repo's test command by inspecting project root
   (`Makefile`, `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`,
   CI configs, `CLAUDE.md`/`AGENTS.md`). If none found, AskUserQuestion.
   Record as `TEST_CMD`.
4. Extract code conduct from `CLAUDE.md`, `AGENTS.md`, lint/formatter
   configs, and existing code patterns. Record as `CODE_CONDUCT`.
5. **Build story dependency graph.** For each story, identify:
   - Files/modules it will create or modify (from plan text)
   - Explicit dependencies (e.g., "uses the model from story 1")
   - Shared resources (e.g., two stories both modify the same config file)

   A story **depends on** another if it reads/imports what the other
   creates, or both modify the same file. Build a DAG and topologically
   sort into **waves** — groups of stories with no dependencies between
   them.

   ```
   Example: 5 stories
     Story 1: add User model          → no deps
     Story 2: add Product model       → no deps
     Story 3: add API for User        → depends on 1
     Story 4: add API for Product     → depends on 2
     Story 5: add auth middleware      → depends on 3, 4

   Waves:
     Wave 1: [Story 1, Story 2]       ← parallel
     Wave 2: [Story 3, Story 4]       ← parallel
     Wave 3: [Story 5]                ← sequential
   ```

   If the plan does not provide enough information to determine file
   overlap, default to **sequential** (single story per wave). Do not
   guess — false parallelism causes merge conflicts.

### Locating input

1. **Caller provides paths** → use them directly.
2. **Caller provides a task directory** → look for spec/plan files inside.
3. **No formal plan or spec exists** → derive acceptance criteria from
   user request + source files, confirm via AskUserQuestion, break into
   stories if multi-file. Do not ask the user to write a plan.
4. **Caller provides review/QA findings (fix mode)** → this is a targeted
   fix, not a full implementation. See Fix Mode below.

### Fix Mode

When invoked by `/ship:auto` with review findings or QA issues to fix,
operate in fix mode instead of the full wave loop:

1. Read the findings/issues provided by the caller.
2. For each finding, identify the affected file(s) and the fix needed.
3. **You apply the fixes directly.** No dispatch. Fix mode exists
   precisely because the caller has already done the analysis — your
   job is surgical application, not re-analysis, so a dispatch
   round-trip adds nothing.
4. Run `TEST_CMD` after fixes to verify no regressions.
5. Commit the fixes with Conventional Commit messages.

Fix mode skips: wave construction, dependency analysis, story-based
peer review. The fixes are re-validated by Auto's next-phase dispatch
(`/ship:review`, `/ship:qa`, or the `post_qa_fix → e2e-recheck` gate),
not by dev's internal reviewer.

Return: which findings were fixed, what verification ran, any remaining
concerns.

## Phase 2: Per-Wave Loop

For each wave, run all stories in the wave through Steps A→B→(C)→D.
- **Single-story wave**: run directly on the current branch.
- **Multi-story wave**: each story gets its own branch via git worktree.
  After all stories in the wave pass review, merge all branches back.

### Wave setup (multi-story waves only)

```bash
WAVE_BASE_SHA=$(git rev-parse HEAD)
# For each story in the wave:
git worktree add .ship/worktrees/story-<i> -b story-<i>
```

Each dispatched implementer receives `cwd: .ship/worktrees/story-<i>`
(or the absolute path) so it works in its own isolated copy.

### Wave merge (multi-story waves only)

After all stories in a wave pass review:

```bash
# For each story branch in the wave:
git merge story-<i> --no-edit
git worktree remove .ship/worktrees/story-<i>
git branch -d story-<i>
```

### Merge conflict resolution

If `git merge` fails with conflicts:

1. Read BOTH sides of the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
2. Preserve the behavior this PR ships — both sides may have valid changes.
3. **You resolve it yourself.** Conflict resolution needs the full context
   of what the PR is shipping; no dispatch round-trip is faster and
   cleaner. Read both sides, pick or merge, commit.
4. After resolution, run `TEST_CMD` to verify the merged result.
5. If tests fail after resolution, try once more (round 2/2).
6. If 2 rounds fail → BLOCKED. Do NOT use `--ours` or `--theirs` blindly.

### Step A: Implement

Record `STORY_START_SHA`:
```bash
git rev-parse HEAD   # in the story's worktree for multi-story waves
```

**Single-story wave (and all fix rounds) — you implement directly.**

Use `implementer-prompt.md` as your own checklist: read the story text,
acceptance criteria, prior stories, CODE_CONDUCT, TEST_CMD, then write
the code in the current branch. Commit using Conventional Commits as you
go. Run `TEST_CMD` before declaring the story complete. You already have
all the context the skill has gathered — no dispatch round-trip is
needed.

**Multi-story parallel wave — dispatch fresh Claude Agent subagents.**

You cannot fork yourself, so multi-story parallelism needs sub-agents.
Dispatch one Agent per story, all in a single message so they run in
parallel. Use `subagent_type: "general-purpose"` and fill the prompt
template in `implementer-prompt.md` with that story's specifics. Set
`cwd` to the story's worktree.

```
Agent({
  subagent_type: "general-purpose",
  description: "Implement story <i>/<N>",
  prompt: <implementer-prompt.md with placeholders filled for this story>
})
```

**After implementation completes (either path):**

1. Record `STORY_HEAD_SHA=$(git rev-parse HEAD)`.
2. If `STORY_HEAD_SHA == STORY_START_SHA` → BLOCKED (no commits were made).
3. If a dispatched sub-agent reported BLOCKED or NEEDS_CONTEXT → escalate.
4. If implementation-self-reported DONE_WITH_CONCERNS → log concerns.

Proceed to **Step B**. A story is only complete when peer review returns PASS.

### Step B: Review (peer cross-validation)

Dispatch the peer (Codex) using the prompt template in
`reviewer-prompt.md`. Fill all placeholders (story number, SHAs,
TEST_CMD, spec requirements, story text) before dispatch.

```
mcp__codex__codex({
  prompt: <reviewer-prompt.md with placeholders filled>,
  ...
})
```

Save the returned `session_id` as `REVIEWER_SESSION_ID` — useful if you
need to ask the reviewer a clarifying question (not to issue fixes; fixes
are yours to write).

**Fallback if Codex is unavailable**: dispatch a fresh Claude Agent
(`subagent_type: "general-purpose"`) with the same prompt. Independence
is weaker (same provider) but better than no review — note this in the
report.

After the reviewer returns, read the verdict:
- **PASS** → proceed to Step D.
- **PASS_WITH_CONCERNS** → append concerns to `concerns.md`. Proceed to Step D.
- **FAIL** → proceed to Step C. Max 2 rounds.
  If 2 rounds exhausted and still FAIL → escalate as BLOCKED.
- **No recognized verdict** → re-dispatch the reviewer once with an
  explicit format reminder. If still unparseable → treat as FAIL.

### Step C: Targeted Fix

On FAIL, verify repo state:

```bash
git rev-parse HEAD
git status --short
```

If uncommitted partial changes exist, stash or discard (warn the user).

**You apply the fix directly.** No dispatch. You have the full context of
what you implemented (or what the sub-agent implemented — the diff is
right there in the worktree). Read the reviewer's FAIL findings
verbatim, apply surgical fixes, commit.

Fix rules (apply to yourself):
- Fix ONLY the issues the reviewer listed. Do not refactor or improve
  other code.
- Run `TEST_CMD` after fixes. If a fix requires a new test, add it.
- Do NOT soften test assertions to make them pass. Fix the code.
- Do NOT re-implement the story. Make surgical fixes.
- Commit using Conventional Commits.

After fix commits:
1. Update `STORY_HEAD_SHA=$(git rev-parse HEAD)`.
2. Return to **Step B** with a fresh reviewer dispatch using the
   updated commit range. (Do NOT reuse the prior reviewer session —
   fresh eyes each round.)

### Step D: Record Context

After each story completes (PASS or PASS_WITH_CONCERNS), record:

```
Story <i>: "<title>"
  Commits: <STORY_START_SHA>..<STORY_HEAD_SHA> (<N> commits)
  Files: <list of ALL files changed across all commits in range>
  Concerns: <any PASS_WITH_CONCERNS notes, or "none">
```

Use `git diff --name-only <STORY_START_SHA>..<STORY_HEAD_SHA>` to get
the complete file list. Pass this summary to the next story's prompt
in the "Prior Stories Completed" section.

## Phase 3: Cross-Story Regression

After all stories pass, **you run** `TEST_CMD` yourself and report the
result. No dispatch — it's a shell command, not a reasoning task.

```bash
<TEST_CMD>
```

If tests fail, apply targeted fixes yourself (same rules as Step C —
surgical, don't soften assertions) and re-run. Max 2 rounds; then
BLOCKED.

---

## Progress Reporting

Use `[Dev]` prefix:

```
[Dev] Starting — N stories in W waves, test cmd: <TEST_CMD>
[Dev] Wave w/W (parallel|sequential): Stories [list]
[Dev] Story i/N: "<title>" → implementing...
[Dev] Story i/N: PASS | FAIL — <detail>. Fixing (round/2)...
[Dev] Wave w/W: merging branches... ✓
[Dev] All N stories complete. M concerns recorded.
```

## Artifacts

```text
.ship/tasks/<task_id>/
  concerns.md   — recorded PASS_WITH_CONCERNS notes (if any)
```

## Example Workflow

Condensed for readability. The full flow would include the same
implement → review → (fix) → merge pattern for every story.

```
[Dev] Starting — 5 stories, test cmd: npm test
[Dev] Dependency analysis:
  Wave 1: [Story 1 "User model", Story 2 "Product model"] ← parallel
  Wave 2: [Story 3 "User API", Story 4 "Product API"]     ← parallel
  Wave 3: [Story 5 "Auth middleware"]                      ← single-story

═══ Wave 1 (parallel, 2 stories) ═══════════════════════

[Dev] Created worktrees story-1, story-2. Dispatching 2 Claude Agent
      subagents in parallel (I can't fork myself)...
      Story 1 subagent: DONE (3 commits, cwd story-1)
      Story 2 subagent: DONE (2 commits, cwd story-2)
[Dev] Peer (Codex) reviews each diff — both PASS.
[Dev] Merging story-1, story-2 → main. Tests green.

═══ Wave 2 (parallel, 2 stories) ═══════════════════════

[Dev] Subagents implement stories 3, 4 in parallel.
[Dev] Peer reviewer → Story 3 FAIL: missing input validation.
[Dev] I apply the fix directly in the story-3 worktree.
      Run TEST_CMD → PASS. Re-dispatch peer reviewer → PASS (round 2/2).
[Dev] Story 4 → PASS. Merge both.

═══ Wave 3 (single story) ══════════════════════════════

[Dev] I implement Story 5 directly in current branch (no worktree needed).
      Commit, run TEST_CMD → PASS.
[Dev] Peer reviewer → PASS_WITH_CONCERNS ("jwt secret hardcoded in test
      fixtures"). Appending to concerns.md.

── Phase 3: Cross-Story Regression ──────────────────────

[Dev] I run the full test suite: npm test → PASS (47 tests).

[Dev] DONE_WITH_CONCERNS — 5/5 stories, 3 waves, 1 concern recorded.
```

## Error Handling

| Condition | Action |
|-----------|--------|
| Reviewer FAIL, rounds < 2 | You apply the targeted fix → fresh peer re-review |
| Reviewer FAIL, rounds exhausted | Escalate BLOCKED with findings |
| Reviewer malformed output | Re-dispatch peer reviewer once with format reminder; treat second failure as FAIL |
| Reviewer unavailable (Codex down) | Fall back to fresh Claude Agent reviewer; note weaker independence in report |
| Sub-agent implementer (multi-story wave) reports BLOCKED or NEEDS_CONTEXT | Escalate to caller |
| Sub-agent implementer reports DONE_WITH_CONCERNS | Log concerns, proceed to review |
| Sub-agent implementer crash (exit != 0) | Check HEAD + working tree; stash if dirty; retry once; then BLOCKED |
| Agent dispatch failure | Retry once, then BLOCKED |

## Execution Handoff

Output the report card (read `skills/shared/report-card.md` for the standard format):

```
## [Dev] Report Card

| Field | Value |
|-------|-------|
| Status | <DONE / DONE_WITH_CONCERNS / BLOCKED / NEEDS_CONTEXT> |
| Summary | <N>/<total> stories complete |

### Metrics
| Metric | Value |
|--------|-------|
| Stories | <N>/<total> |
| Waves | <W> |
| Concerns | <N> (in concerns.md) |
| Tests | <passed / failed> |

### Artifacts
| File | Purpose |
|------|---------|
| .ship/tasks/<task_id>/concerns.md | Residual concerns (if any) |

### Next Steps
1. **Review (recommended)** — /ship:review to review the full diff
2. **QA** — /ship:qa to test the running application
3. **Full pipeline** — /ship:auto to review, QA, and ship
```

