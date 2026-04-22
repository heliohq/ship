---
name: dev
version: 0.6.0
description: >
  Execute implementation stories from a plan via parallel waves. Host (Claude) is the
  primary implementer; peer (Codex) is the independent reviewer. Dependency analysis
  groups file-independent stories into waves that can run in parallel on the current
  branch — single-story waves are implemented by the host; multi-story waves dispatch
  Claude Agent subagents in parallel. Each story is reviewed by the peer before the
  wave advances. Use when: "implement this plan", "execute the stories", "code this up",
  "build from the plan", or when a plan/stories already exist and need implementation.
  Note: if no plan exists yet, use /ship:design first. For the full pipeline
  (plan → code → e2e → review → QA → ship), use /ship:auto.
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

| Wave shape | Implementer | Reviewer | Fix-round owner |
|---|---|---|---|
| **Single-story** (most common) | Host (you), on current branch | Peer via `mcp__codex__codex` | Host — you apply fixes directly |
| **Multi-story parallel** | Fresh Claude Agent subagents per story, all on the current branch (dependency analysis guarantees their file scopes don't overlap — no worktrees needed) | Peer per story | Fresh Claude Agent subagent dispatch — whoever implemented a story is who fixes it |
| **Fix mode** (/ship:auto review_fix/qa_fix/e2e_fix dispatch) | Host — you | (next phase re-runs its own verification) | Host — you apply fixes directly |

The independence contract — reviewer MUST differ from implementer —
is met two ways: different provider (Codex ≠ Claude) AND different
session. Both hold across all wave shapes.

The fix-routing rule — **whoever implemented, fixes** — keeps context
tight. The implementer knows what they built and why; asking someone
else to fix their code loses that context.

## Roles

| Role | Who |
|------|-----|
| Orchestrator + primary implementer | **You (host agent)** — implement directly in single-story waves and fix mode |
| Parallel implementer | **Fresh Claude Agent subagent** — only in multi-story parallel waves, all on current branch (dependency analysis prevents file overlap) |
| Reviewer | **Peer agent (Codex)** — fresh dispatch per story |
| Multi-story fixer | **Fresh Claude Agent subagent** — dispatched when a sub-agent-implemented story needs a fix; "whoever implemented, fixes" |

## Quality Gates

| Gate | Condition | Fail action |
|------|-----------|-------------|
| Spec + plan read | Acceptance criteria extracted, TEST_CMD found | AskUserQuestion |
| Implement → Review | Story produced at least one commit (from subagent report, or HEAD moved since WAVE_BASE_SHA for single-story waves) | BLOCKED |
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
5. **Build pattern references.** For each story, find the closest
   analogous implementation before anyone writes code:
   - Search adjacent directories, feature folders, test folders, and
     shared component/module areas for similar files. Read the full
     files, not just matching snippets.
   - Record 1-3 references in `<task_dir>/dev-context.md` with:
     file path, why it is analogous, patterns to mirror, and intentional
     deviations.
   - Patterns to capture include import/export shape, file organization,
     naming, test setup, fixture style, error handling, logging, styling,
     theme usage, and framework-specific conventions.
   - For frontend/UI work, if `DESIGN.md` exists at project root, read it
     and include the relevant design rules. If not, read theme/config
     files plus representative components before writing styles.
   - If no analogous file exists, record the searches performed and
     `none found`; this is allowed, but silent skipping is not.

   Pattern references are evidence, not copy-paste licenses. Mirror the
   local structure and conventions, but do not clone product-specific
   logic, stale bugs, or unrelated behavior.
6. **Build story dependency graph.** For each story, identify:
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

### dev-context.md format

Write `<task_dir>/dev-context.md` during setup and update it if fix mode
adds new pattern evidence:

```markdown
# Dev Context

## Test Command
<TEST_CMD>

## Code Conduct
<CODE_CONDUCT>

## Pattern References
### Story <i>: <title>
- Reference: `<path>`
  - Why analogous: <short reason>
  - Mirror: <structure/test/style/error-handling conventions>
  - Deviations: <intentional differences, or "none">

## Waves
<wave grouping and dependency notes>
```

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
3. Read the existing `<task_dir>/dev-context.md` if present. If the fix
   touches a file or subsystem not covered by the recorded pattern
   references, read the nearest analogous file and append a short pattern
   note before editing.
4. **You apply the fixes directly.** No dispatch. Fix mode exists
   precisely because the caller has already done the analysis — your
   job is surgical application, not re-analysis, so a dispatch
   round-trip adds nothing.
5. Run `TEST_CMD` after fixes to verify no regressions.
6. Commit the fixes with Conventional Commit messages.

Fix mode skips: wave construction, full pattern-reference inventory,
dependency analysis, story-based peer review. The fixes are re-validated
by Auto's next-phase dispatch (`/ship:review`, `/ship:qa`, or the
`post_qa_fix → e2e-recheck` gate), not by dev's internal reviewer.

Return: which findings were fixed, what verification ran, any remaining
concerns.

## Phase 2: Per-Wave Loop

For each wave, run all stories in the wave through Steps A→B→(C)→D.
All work happens on the **current branch** — no worktrees, no story-
specific branches.

### Why no worktrees

Waves are constructed specifically because the stories in them don't
share files (that's the whole point of dependency analysis in Phase 1).
If two stories in a wave would touch the same file, they belong in
different waves — that's a wave-construction error, not a merge-conflict
to solve. Git's own commit serialization via `.git/index.lock` is
sufficient protection against races on simultaneous commits to the same
branch.

Record `WAVE_BASE_SHA` once at wave start so you can compute per-story
file scope later:

```bash
WAVE_BASE_SHA=$(git rev-parse HEAD)
```

### Step A: Implement

**Single-story wave (and all fix rounds where host is the implementer) — you implement directly.**

Use `implementer-prompt.md` as your own checklist: read the story text,
acceptance criteria, prior stories, CODE_CONDUCT, pattern references,
and TEST_CMD, then write the code in the current branch. Commit using
Conventional Commits as you go. Run `TEST_CMD` before declaring the
story complete.

**Multi-story parallel wave — dispatch Claude Agent subagents in parallel.**

You cannot fork yourself, so multi-story parallelism needs sub-agents.
Dispatch one Agent per story, all in a single message so they run in
parallel. All subagents share the same cwd (the current branch); the
wave's dependency analysis guarantees their file scopes don't overlap.

```
Agent({
  subagent_type: "general-purpose",
  description: "Implement story <i>/<N>",
  prompt: <implementer-prompt.md with placeholders filled for this story>
})
```

Each subagent edits files, commits its own changes, and reports back
with: the files it changed, the commit SHAs it produced, and its
status. Git's index lock serializes concurrent commits automatically.

**After implementation completes (either path):**

1. Record each story's commit SHAs from the subagent reports (or, for
   single-story waves, from your own commits).
2. If the subagent's reported commits are empty and its status is DONE
   → BLOCKED (no actual code change).
3. If a subagent reported BLOCKED or NEEDS_CONTEXT → escalate.
4. If a subagent reported DONE_WITH_CONCERNS → log concerns.

Proceed to **Step B**. A story is only complete when peer review returns PASS.

### Step B: Review (peer cross-validation)

Dispatch the peer (Codex) using the prompt template in
`reviewer-prompt.md`. Fill all placeholders (story number, commit SHAs
or file list from Step A, TEST_CMD, spec requirements, story text)
before dispatch.

```
mcp__codex__codex({
  prompt: <reviewer-prompt.md with placeholders filled>,
  ...
})
```

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

**Whoever implemented the story, fixes the story.** This keeps the
context tight — the fixer already knows what the code does, what
trade-offs were made, and what the reviewer saw.

Routing:

| Who implemented | Who fixes |
|---|---|
| Host (single-story wave) | Host — you apply the fix directly |
| Sub-agent (multi-story wave) | Fresh sub-agent dispatch with the original story + prior implementation summary + FAIL findings |
| Host in fix mode (/ship:auto dispatch) | Host — you apply the fix directly |

Before dispatching or editing, verify repo state:

```bash
git rev-parse HEAD
git status --short
```

If uncommitted partial changes exist, stash or discard (warn the user).

**If you (host) are fixing:** read the reviewer's FAIL findings
verbatim, apply surgical fixes on the current branch, run `TEST_CMD`,
commit.

**If dispatching a sub-agent to fix** (multi-story wave): the sub-agent
is new but plays the same role the original implementer did. Give it:

- The original story text and acceptance criteria
- A summary of what was implemented (files changed, key commits)
- The reviewer's FAIL findings verbatim
- The same Fix rules below

```
Agent({
  subagent_type: "general-purpose",
  description: "Fix story <i>/<N> — round <R>/2",
  prompt: <fix prompt with findings + original story context>
})
```

Fix rules (whoever is applying):
- Fix ONLY the issues the reviewer listed. Do not refactor or improve
  other code.
- Run `TEST_CMD` after fixes. If a fix requires a new test, add it.
- Do NOT soften test assertions to make them pass. Fix the code.
- Do NOT re-implement the story. Make surgical fixes.
- Commit using Conventional Commits.

After fix commits:
1. Re-record the story's commit SHAs (original + fix commits).
2. Return to **Step B** with a fresh reviewer dispatch. (Do NOT reuse
   the prior reviewer session — fresh eyes each round.)

### Step D: Record Context

After each story completes (PASS or PASS_WITH_CONCERNS), record:

```
Story <i>: "<title>"
  Commits: <list of commit SHAs produced by this story>
  Files: <list of files changed by this story's commits>
  Concerns: <any PASS_WITH_CONCERNS notes, or "none">
```

Since all stories commit to the same branch, derive the file list from
the subagent's report (multi-story waves) or from
`git show --name-only <sha>` per commit (either path). Do NOT use
`git diff WAVE_BASE..HEAD --name-only` — that aggregates all stories
in the wave.

Pass this summary to the next wave's prompts in the "Prior Stories
Completed" section so each implementer sees what's already been built.

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
[Dev] Pattern references recorded in <task_dir>/dev-context.md
[Dev] Wave w/W (parallel|sequential): Stories [list]
[Dev] Story i/N: "<title>" → implementing...
[Dev] Story i/N: PASS | FAIL — <detail>. Fixing (round/2)...
[Dev] Wave w/W: merging branches... ✓
[Dev] All N stories complete. M concerns recorded.
```

## Artifacts

```text
.ship/tasks/<task_id>/
  dev-context.md — TEST_CMD, CODE_CONDUCT, pattern references, wave notes
  concerns.md   — recorded PASS_WITH_CONCERNS notes (if any)
```

## Example Workflow

Condensed. The full flow repeats implement → review → (fix) → next per
story.

```
[Dev] Starting — 5 stories, test cmd: npm test
[Dev] Pattern references:
  Story 1 "User model" -> models/account.ts, tests/models/account.test.ts
  Story 2 "Product model" -> models/catalog-item.ts
[Dev] Dependency analysis:
  Wave 1: [Story 1 "User model", Story 2 "Product model"] ← parallel
  Wave 2: [Story 3 "User API", Story 4 "Product API"]     ← parallel
  Wave 3: [Story 5 "Auth middleware"]                      ← single-story

═══ Wave 1 (parallel, 2 stories, same branch) ═══════════

[Dev] WAVE_BASE_SHA = abc1234. Dispatching 2 Claude Agent subagents
      in parallel (same cwd — dependency analysis says their files
      don't overlap).
      Story 1 subagent: DONE — edited models/user.ts, committed abc5
      Story 2 subagent: DONE — edited models/product.ts, committed abc6
[Dev] Peer (Codex) reviews each story's commits — both PASS.

═══ Wave 2 (parallel, 2 stories) ═══════════════════════

[Dev] Subagents implement stories 3, 4 in parallel on same branch.
      Story 3 subagent: DONE — routes/users.ts
      Story 4 subagent: DONE — routes/products.ts
[Dev] Peer reviewer → Story 3 FAIL: missing input validation.
[Dev] Dispatching a fresh subagent to fix Story 3 (whoever implemented
      it, fixes it — here that role is a new subagent with the original
      story + the FAIL findings).
      Fix subagent: DONE — commit abc9, TEST_CMD PASS.
[Dev] Re-dispatch peer reviewer for Story 3 → PASS (round 2/2).
[Dev] Story 4 → PASS (same review batch).

═══ Wave 3 (single story) ══════════════════════════════

[Dev] I implement Story 5 directly. Commit, TEST_CMD → PASS.
[Dev] Peer reviewer → PASS_WITH_CONCERNS ("jwt secret hardcoded in test
      fixtures"). Appending to concerns.md.

── Phase 3: Cross-Story Regression ──────────────────────

[Dev] I run the full test suite: npm test → PASS (47 tests).

[Dev] DONE_WITH_CONCERNS — 5/5 stories, 3 waves, 1 concern recorded.
```

## Error Handling

| Condition | Action |
|-----------|--------|
| Reviewer FAIL, rounds < 2 | Fix is applied by whoever implemented (host or fresh sub-agent) → fresh peer re-review |
| Reviewer FAIL, rounds exhausted | Escalate BLOCKED with findings |
| Reviewer malformed output | Re-dispatch peer reviewer once with format reminder; treat second failure as FAIL |
| Reviewer unavailable (Codex down) | Fall back to fresh Claude Agent reviewer; note weaker independence in report |
| Sub-agent implementer (multi-story wave) reports BLOCKED or NEEDS_CONTEXT | Escalate to caller |
| Sub-agent implementer reports DONE_WITH_CONCERNS | Log concerns, proceed to review |
| Sub-agent implementer crash (exit != 0) | Check HEAD + working tree; stash if dirty; retry once; then BLOCKED |
| Agent dispatch failure | Retry once, then BLOCKED |
| Two sub-agents in a wave touched the same file (race on commit or unexpected diff) | Wave construction error — abort wave, revisit dependency analysis, rebuild waves, retry |

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
| .ship/tasks/<task_id>/dev-context.md | TEST_CMD, CODE_CONDUCT, pattern references, wave notes |
| .ship/tasks/<task_id>/concerns.md | Residual concerns (if any) |

### Next Steps
1. **Review (recommended)** — /ship:review to review the full diff
2. **QA** — /ship:qa to test the running application
3. **Full pipeline** — /ship:auto to review, QA, and ship
```
