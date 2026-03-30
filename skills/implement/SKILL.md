---
name: implement
description: "Use when executing implementation stories from a plan. Codex implements each story, Claude reviews spec compliance and code correctness. Stories run sequentially."
---

# Ship: Implement

Execute implementation stories from a plan. Each story: codex implements
with TDD, claude reviews spec compliance + code correctness, targeted
fix on failure. Stories run sequentially; review must pass before the
next story starts.

**Why separation of concerns:** You are the orchestrator — you never
write code, read diffs, or run tests. This buys three things:
1. **Context isolation** — codex implements with only the story context
   it needs, no session history to confuse it. A fresh reviewer judges
   each story without accumulated leniency from prior reviews.
2. **Preserved orchestrator context** — your context window stays clean
   for coordination, not filled with diffs and test output.
3. **Honest verification** — the reviewer never saw the implementation
   happen, so it cannot rationalize away problems it watched being built.

**Core principle:** Codex implements → structured one-pass review under
the Verification Principle (every finding must include file:line +
reproducible evidence, or it is not a valid finding) → targeted fix on
failure. No parallelism between stories, no skipping the review gate.

## Checklist

You MUST create a task for each of these steps and complete them in order:

1. **Read spec + plan** — locate acceptance criteria and implementation stories (see Input)
2. **Detect tooling** — find test command, extract code conduct from CLAUDE.md/AGENTS.md
3. **Per-story loop** — for each story: record start SHA → codex implements → record end SHA → verify commit exists → reviewer checks → verdict
4. **Cross-story regression** — run full test suite after all stories pass
5. **Report** — completion status with concerns log

Mark each task in_progress when starting, completed when done.

---

## Team Composition

### Implementor (codex)

- **Executor:** `codex exec --full-auto`
- **Model selection:** Use `-m <model>` based on story complexity:
  - Mechanical (isolated function, 1-2 files) → fast model
  - Integration (multi-file coordination) → standard model
  - Architecture (design judgment, broad codebase) → most capable model

### Reviewer (claude)

- **Executor:** `Agent` tool (fresh per review)
- **Tools:** Read, Grep, Glob, Bash (read-only)

---

## Input

The skill needs two things to operate:
- **Acceptance criteria** — what "done" looks like (from a spec file,
  or derived from the user's request)
- **Implementation stories** — ordered steps (from a plan file, or
  a single story for small tasks)

### Locating input

1. **Caller provides paths** → use them directly.
2. **Caller provides a task directory** → look for spec/plan files inside.
3. **No formal plan or spec exists** → investigate first:
   - Read the user's request and relevant source files
   - Derive a concrete list of acceptance criteria
   - Present the criteria to the user via AskUserQuestion for confirmation
   - Break the work into stories if it touches multiple files or concerns;
     keep it as a single story only if it is truly atomic

   Do not ask the user to write a plan. Derive what you need from context.

## Process

1. Read the **acceptance criteria** (from spec file, or derived per
   Input section above). This is the reference for the reviewer's
   spec checklist.
2. Read the **implementation stories** (from plan file, or single story
   for small tasks). Accept any heading format: `## Story N`,
   `## Step N`, `## N. Title`, or numbered/bulleted lists. Normalize
   them as ordered stories for the loop.
3. Detect the repo's test command by inspecting the project root:
   - `Makefile` → `make test`
   - `package.json` → `npm test` or `pnpm test` or `yarn test`
   - `pytest.ini` / `pyproject.toml` / `setup.cfg` → `pytest`
   - `go.mod` → `go test ./...`
   - `Cargo.toml` → `cargo test`
   - `mix.exs` → `mix test`
   - `build.gradle` / `pom.xml` → `./gradlew test` or `mvn test`
   - `.csproj` / `.sln` → `dotnet test`
   - `Gemfile` → `bundle exec rspec` or `bundle exec rake test`
   Also check for repo-specific test scripts (e.g. `scripts/test.sh`,
   CI config test steps) and CLAUDE.md/AGENTS.md for documented test
   commands. If none found, use AskUserQuestion. Record as `TEST_CMD`.
4. Extract the repo's code conduct: read `CLAUDE.md`, `AGENTS.md`, and
   any local `AGENTS.md` or `CLAUDE.md` in directories the plan touches.
   Look for coding style rules, naming conventions, error handling
   patterns, test conventions, and hard rules. Also inspect any lint or
   formatter configs in the project root for implicit conventions. If no
   documented conventions exist, sample 2-3 existing files in the same
   directory as the planned changes to infer patterns. Record as
   `CODE_CONDUCT`.
5. Create a task for each story via TaskCreate. Mark in_progress when
   starting, completed when review passes.
6. Run the per-story loop sequentially. Each story must pass review
   before the next story starts.
7. After all stories: run `TEST_CMD` one final time to catch cross-story
   regressions. If tests fail, dispatch a targeted fix and re-verify.
8. Report completion status with concerns log.

---

## Per-Story Loop

```
For each story i/N:
  1. Record STORY_START_SHA = current HEAD
  2. Implementor implements (codex exec) → commit(s)
  3. Record STORY_HEAD_SHA = current HEAD
  4. Reviewer checks code + spec (Agent, fresh) → verdict
     PASS → step 5
     PASS_WITH_CONCERNS → record concerns → step 5
     FAIL → targeted fix (max 2 rounds) → re-review
  5. Record cross-story context → next story
```

### Step A: Implement

Record `STORY_START_SHA`:
```bash
git rev-parse HEAD
```

Dispatch codex exec using the prompt template at `./implementer-prompt.md`.
Fill all placeholders (story text, acceptance criteria, prior stories,
CODE_CONDUCT, TEST_CMD) before dispatch. Run with `--full-auto`.

After Implementor returns:
1. Record `STORY_HEAD_SHA=$(git rev-parse HEAD)`
2. If `STORY_HEAD_SHA == STORY_START_SHA` and status is DONE → treat as
   BLOCKED (claimed done but made no commits).
3. If Implementor reported BLOCKED or NEEDS_CONTEXT → escalate to caller.
4. If Implementor reported DONE_WITH_CONCERNS → log concerns, proceed to
   review normally.
5. Otherwise → proceed to Step B.

### Step B: Review

Dispatch a fresh Agent using the prompt template at `./reviewer-prompt.md`.
Fill all placeholders (story number, SHAs, TEST_CMD, spec requirements,
story text) before dispatch.

After Reviewer returns, read the verdict:
- **PASS** → proceed to Step D.
- **PASS_WITH_CONCERNS** → append concerns to `concerns.md` (in task dir
  if one exists, otherwise in the repo root). Proceed to Step D.
- **FAIL** → proceed to Step C (targeted fix). Max 2 rounds.
  If 2 rounds exhausted and still FAIL → escalate as BLOCKED.
- **No recognized verdict** → re-dispatch a fresh Reviewer once.
  If still unparseable → treat as FAIL.

### Step C: Targeted Fix

On FAIL, first verify repo state is clean:

```bash
git rev-parse HEAD   # confirm current HEAD
git status --short   # check for uncommitted changes
```

If there are uncommitted partial changes from a crashed prior attempt,
stash or discard them before proceeding (warn the user).

Dispatch a targeted fix via codex exec:

```bash
codex exec "Fix the following issues found by a code reviewer.

## Issues to Fix
<Reviewer's FAIL findings, verbatim>

## Code Conduct
<CODE_CONDUCT>

## Rules
- Fix ONLY the issues listed above. Do not refactor or improve other code.
- Follow the Code Conduct conventions above.
- Run the full test suite after fixes: <TEST_CMD>
- If a fix requires a new test, add it.
- Commit using the commit format from Code Conduct, or Conventional Commits.

Do NOT re-implement the story. Make surgical fixes." --full-auto
```

After fix commits:
1. Update `STORY_HEAD_SHA=$(git rev-parse HEAD)`
2. Return to **Step B** with fresh Reviewer using updated commit range.

### Step D: Record Context

After each story completes (PASS or PASS_WITH_CONCERNS), record a summary:

```
Story <i>: "<title>"
  Commits: <STORY_START_SHA>..<STORY_HEAD_SHA> (<N> commits)
  Files: <list of ALL files changed across all commits in range>
  Concerns: <any PASS_WITH_CONCERNS notes, or "none">
```

Use `git diff --name-only <STORY_START_SHA>..<STORY_HEAD_SHA>` to get the
complete file list including any targeted fix commits.

Pass this summary to the next story's Implementor prompt in the
"Prior Stories Completed" section to prevent duplicate work, file
conflicts, and context gaps.

---

## Progress Reporting

Use `[Implement]` prefix for all status output:

```
[Implement] Starting — 5 stories, test cmd: make test
[Implement] Story 1/5: "Add user model" → implementing...
[Implement] Story 1/5: implemented (3 files, 1 commit). Reviewing...
[Implement] Story 1/5: PASS.
[Implement] Story 2/5: "Wire API endpoints" → implementing...
[Implement] Story 2/5: implemented (4 files, 1 commit). Reviewing...
[Implement] Story 2/5: FAIL — missing input validation. Fixing (1/2)...
[Implement] Story 2/5: fix applied (1 commit). Re-reviewing...
[Implement] Story 2/5: PASS (2 rounds).
[Implement] Story 3/5: "Add auth middleware" → implementing...
[Implement] Story 3/5: implemented (2 files, 1 commit). Reviewing...
[Implement] Story 3/5: PASS_WITH_CONCERNS — edge case in token expiry.
...
[Implement] All 5 stories complete. 1 concern recorded.
```

Rules:
- Every status line starts with `[Implement]`
- Show phase transitions: implementing → reviewing → verdict
- Include counts: story 2/5, fix round 1/2
- On PASS_WITH_CONCERNS: include the concern summary
- Never go silent for more than one dispatch without a status update

## Error Handling

Error cases are evaluated in order — first specific match wins.

| Condition | Action |
|-----------|--------|
| Reviewer FAIL, rounds < 2 | Targeted fix (Step C) → fresh re-review |
| Reviewer FAIL, rounds exhausted | Escalate BLOCKED with full findings |
| Reviewer malformed output | Re-dispatch fresh Reviewer once, then treat as FAIL |
| Implementor BLOCKED or NEEDS_CONTEXT | Escalate to caller with report |
| Implementor DONE_WITH_CONCERNS | Log concerns, proceed to Reviewer normally |
| codex exec resource limit (exit 124/137) | Story too large — break it or reduce scope, escalate BLOCKED |
| codex exec other crash (exit ≠ 0) | Check HEAD + working tree for partial changes; stash/discard if dirty; retry once; if still fails → BLOCKED |
| Agent dispatch failure | Retry once, then BLOCKED |

## Completion Status

Report one of:

- **DONE** — all stories implemented, reviewed, and committed.
  Include: total stories, total review rounds, concerns count.
- **DONE_WITH_CONCERNS** — all stories pass, but concerns were recorded.
  Include: concerns.md path for downstream review.
- **BLOCKED** — a story failed after max retries or hit an unresolvable issue.
  Include: which story, what failed, what was tried.
- **NEEDS_CONTEXT** — missing information. Include: what's needed, from whom.

## Red Flags

**Never:**
- Write code yourself instead of dispatching codex exec
- Read the diff yourself instead of dispatching a fresh Agent reviewer
- Run tests yourself instead of letting codex/reviewer handle it
- Fall back to "I'll just do it myself" when codex is slow or unavailable — report BLOCKED
- Skip review because "codex's self-review looked good"
- Start the next story before the current story's review returns a verdict
- Run multiple implementation dispatches in parallel (file conflicts)
- Implement directly on main/master without explicit user consent
- Do a full re-implementation on FAIL instead of a targeted fix
- Let codex modify tests to make them pass instead of fixing code
- Accept "close enough" on spec checklist — any ❌ or ⚠️ is FAIL, no exceptions
- Omit prior stories context from the implementor prompt (causes duplicate work or conflicts)
- Retry after crash without checking HEAD/working tree for partial changes
- Skip TaskCreate/TaskUpdate to track per-story progress
