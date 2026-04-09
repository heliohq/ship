---
name: handoff
version: 0.3.0
description: >
  Use when code is ready to ship: creates a PR, waits for CI/CD, addresses review
  comments and merge conflicts, and iterates until the PR is ready. Use when: "ship it",
  "create a PR", "open a pull request", "push and merge", "handoff", or when code changes
  are complete and need to go through PR creation and CI. Called by /ship:auto at the end,
  or invoked directly via /ship:handoff after manual work.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Agent
  - AskUserQuestion
  - TodoWrite
  - mcp__codex__codex
  - mcp__codex__codex-reply
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-$(ship-plugin-root 2>/dev/null || echo "$HOME/.codex/ship")}"
SHIP_SKILL_NAME=handoff source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```

### Ship CLI (optional)

The Ship CLI enables cloud features (team channels, task assignment) but is **not required** for core skills.
If `SHIP_CLI: not_installed`: proceed normally — all local skills work without it.
If `SHIP_TOKEN_EXPIRY` ≤ 3 days: mention token expiry to user.

# Ship: Handoff

Commit the related changes, push the branch, create or update the PR,
then keep looping until GitHub checks are fully green.

Do not stop when the PR is created.
Do not stop while any GitHub check is pending.
If any GitHub check fails, fix the problem, push again, and wait again.

Escalate to the user only for judgment decisions or after retry limits
are exhausted.

Done means:
- PR exists
- all GitHub checks are green
- no GitHub checks are pending

## Process Flow

Run this loop:

1. Pre-flight: resolve the branch, task context, and related changes to ship.
2. Run the relevant local verification.
3. Update any required changelog or directly affected docs.
4. Commit the related changes.
5. Push the branch.
6. Create or update the PR.
7. Inspect `.github/workflows` and current PR checks so you know what this repo treats as CI/CD.
8. Wait until GitHub checks finish.
9. If any relevant check is still pending, keep waiting.
10. If any relevant check fails, or an AI review workflow leaves actionable comments, fix the problem, verify the fix, commit, push, and wait again.
11. If the branch must be updated from base to clear drift, conflicts, or repo policy, sync with base inside the fix loop, then verify, commit, push, and wait again.
12. Ignore `cancelled` checks unless they block the repo's normal CI/CD path.
13. Stop after 3 fix rounds and escalate to the user.

Done means:
- the PR exists
- relevant GitHub checks are green
- no relevant GitHub checks are pending

## Red Flag

**Never:**
- **Stop when the PR is created** — #1 failure mode
- Push code changes without re-running relevant local verification
- Force push
- Treat `pending` checks as "good enough"
- Create the PR before local verification runs
- Use `git add -A` when unrelated local changes are present
- Forget to stage and commit changelog or doc edits before the first push
- Mark a thread or comment as resolved before the fix is actually pushed
- Resolve comments that still need product, security, or architecture judgment
- Fix failures without reading the actual check logs or review comments
- Sync with base preemptively — only when drift, conflicts, or repo policy require it
- Loop past 3 fix rounds — escalate instead
- Leave doc debt implicit — carry it into the PR

---

## Progress Tracking

Use `TodoWrite` to track your own progress through the handoff phases.
Create todos at the start based on what the repo actually needs.
Not every repo has a CHANGELOG, CI, or docs to update — only include
items for work that will actually happen.

**Principle**: one todo per phase the user would wait on. Fix rounds
are dynamic — add them only when a check fails.

**Example** (repo with CHANGELOG and CI):

```
TodoWrite([
  { content: "Pre-flight (resolve branch and scope)", status: "in_progress", activeForm: "Resolving branch and scope" },
  { content: "Run local verification",                status: "pending",     activeForm: "Running local verification" },
  { content: "Update CHANGELOG and docs",             status: "pending",     activeForm: "Updating CHANGELOG and docs" },
  { content: "Push and create PR",                    status: "pending",     activeForm: "Pushing and creating PR" },
  { content: "Wait for GitHub checks",                status: "pending",     activeForm: "Waiting for GitHub checks" }
])
```

**Adaptations** (not exhaustive — use judgment):
- No CHANGELOG.md and no doc changes needed → drop that item entirely
- No CI workflows in the repo → drop "Wait for GitHub checks"
- Check fails → insert `"Fix round N/3 — <issue summary>"` with `in_progress`
- PR already exists (update flow) → rename "Push and create PR" to
  "Push update to existing PR"

---

## Phase 1: Pre-flight

Resolve only the context needed to ship the PR:

1. Determine the current branch.
2. Determine the base branch:
   - use the existing PR base if a PR already exists
   - otherwise use the repo default branch
3. If the current branch is the base branch, create a feature branch before continuing.
4. Inspect the current scope with `git status --short`, `git diff <base>...HEAD --stat`, `git diff --cached --stat`, and `git diff --stat`.
5. Decide which local changes belong to this handoff.
6. Do not use `git add -A` unless every dirty file belongs to this handoff.
7. If unrelated local changes cannot be separated safely, stop and escalate instead of guessing.
8. If the caller already provides `task_dir`, use it. Otherwise do not guess one here; resolve it only if a later phase needs to write artifacts.

Output a short start summary with the branch, base branch, and scope being shipped.

## Phase 2: Verify Before PR

Before the first push in handoff, run the most relevant local verification
available for this repo.

- Prefer the same commands the repo or CI already uses.
- Run only the checks that are relevant to the changed area: tests, lint,
  typecheck, build, or targeted smoke checks as applicable.
- If code changes during handoff, run the relevant verification again before
  the next push.
- If a task directory already exists, do not invent extra artifacts just for handoff.
- If verification fails, fix the issue before pushing.

Output a short summary of what was run and whether it passed.

## Phase 3: Update CHANGELOG and Docs

### Step A: CHANGELOG (auto-generate)

`[ -f CHANGELOG.md ] || echo 'NO_CHANGELOG'`
- No CHANGELOG.md → skip silently.

If CHANGELOG.md exists:
1. Read header to learn the format
2. Generate entry from: `git log <base>..HEAD --oneline`
3. Categorize: Added / Changed / Fixed / Removed
4. Insert after header, dated today
5. Commit: `git add CHANGELOG.md && git commit -m "docs: update CHANGELOG"`

After changelog handling, check whether the shipped changes also changed any
user-facing or repo-facing documentation truths before the first push.

Use `references/documentation.md` for the documentation decision tree and
ownership rules.

- Only inspect docs that directly describe the changed commands, config,
  file paths, workflow, or behavior.
- Do not scan every markdown file in the repo.
- Route each changed truth to the narrowest correct document instead of
  defaulting to top-level docs.
- If a doc is mechanically stale, fix it in the same handoff loop.
- If the doc issue is semantic and you are not confident about the right
  wording, carry that note into the PR instead of inventing an explanation.
- Before moving on, explicitly record one of:
  - docs updated
  - docs checked, no update needed
  - doc debt to note in the PR

## Phase 4: Push and Create PR

When opening or updating the PR, keep the title and body concise.

Include only:
- what changed
- what local verification ran
- any known follow-up, risk, or skipped check

Do not invent a long template if the change is simple.

Push and create:
1. Review the final diff, then stage all related changes that should ship now, including any changelog or doc edits made in this handoff.
2. Commit the staged changes if anything new was staged in this phase.
3. `git push -u origin HEAD`
4. Create the PR if it does not exist.
5. If the PR already exists, update the body or add a short comment with the latest verification summary.

Output: `[Handoff] PR created: <url>`

## Phase 5: Wait for GitHub Checks

Inspect `.github/workflows` and the current PR checks once so you understand
what this repo expects to run.

Then monitor the PR on GitHub directly using `gh`:

```bash
# Check PR status and all check runs
gh pr view --json state,statusCheckRollup,reviews,mergeable

# Read individual check run logs when a check fails
gh run view <run-id> --log-failed

# List review comments to see what reviewers said
gh pr view --json reviews,comments

# Check for merge conflicts
gh pr view --json mergeable --jq '.mergeable'
```

Interpret the results:

- `statusCheckRollup` all `SUCCESS` or `NEUTRAL` → green
- Any check `IN_PROGRESS` or `QUEUED` → pending, keep waiting
- Any check `FAILURE` or `ACTION_REQUIRED` → enter the fix loop
- `mergeable` is `CONFLICTING` → merge conflict, enter the fix loop
- If the wait times out, escalate as an external GitHub wait, not as a code fix failure.
- Treat `cancelled` checks as informational unless they block the normal CI/CD path.
- Check roughly every 30 seconds.
- Continue until the PR is green, clearly needs action, or the wait timeout is exceeded.

## Phase 6: Fix Loop

If CI failures, review comments, or merge conflicts exist, fix them.
Max 3 rounds — after that, escalate.

In each fix round:

1. Re-read the current PR status on GitHub.
2. If checks failed, inspect the failing check logs and fix the smallest
   real cause.
3. If review comments are actionable, fix mechanical or correctness issues.
4. If a comment requires product, security, or architecture judgment,
   escalate instead of guessing.
5. If the branch has merge conflicts, base drift, or a repo policy requires
   an update from base, sync with base and resolve it carefully.
6. Do not resolve conflicts mechanically with `--ours` or `--theirs` unless
   one side is clearly disposable.
7. Read both sides of the conflict and preserve the behavior this PR is
   trying to ship. If both sides contain valid changes, merge them.
8. If you cannot resolve the conflict confidently, escalate instead of guessing.
9. After any code change, run the relevant local verification again.
10. Commit the fix and push it.
11. If the push fully addresses GitHub feedback, mark the addressed feedback as resolved:
    - for review threads, resolve the thread
    - for obsolete bot or workflow comments, hide/minimize the comment with
      classifier `RESOLVED`
12. Never resolve, hide, or minimize feedback that is only partially addressed
    or still needs user judgment.
13. Go back to Phase 5.

Use GitHub GraphQL when needed:

```bash
# Resolve a PR review thread
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }' -F threadId="<thread-id>"

# Hide/minimize an obsolete bot or workflow comment as resolved
gh api graphql -f query='
  mutation($subjectId: ID!) {
    minimizeComment(input: {subjectId: $subjectId, classifier: RESOLVED}) {
      minimizedComment { isMinimized }
    }
  }' -F subjectId="<comment-node-id>"
```

Output: `[Handoff] Fix round <i>/3 — <what was fixed>. Tests pass. Re-checking CI...`

---

## Execution Handoff

Output the report card (read `skills/shared/report-card.md` for the standard format):

```
## [Handoff] Report Card

| Field | Value |
|-------|-------|
| Status | <DONE / BLOCKED> |
| Summary | PR #<N> — checks <green / pending / failed> |

### Metrics
| Metric | Value |
|--------|-------|
| PR URL | <url> |
| Check status | <green / N passing, M failed> |
| Fix rounds | <N>/3 |

### Artifacts
| File | Purpose |
|------|---------|
| PR on GitHub | Shipped code |
| CHANGELOG.md | Updated changelog (if repo has one) |
```

Always output the full report card including Next Steps — the orchestrator reads it the same way a human does.

---

## Example Workflow

```
[Handoff] Starting — branch: feat/auth-hardening, base: main
[Handoff] Scope: 4 committed files, 2 local doc edits

── Phase 2: Verify Before PR ─────────────────────────────

[Handoff] Running local verification...
  - npm test
  - npm run lint
  Result: PASS

── Phase 3: Update CHANGELOG and Docs ────────────────────

[Handoff] CHANGELOG.md exists — adding entry
[Handoff] Docs checked — README.md updated, AGENTS.md no change needed

── Phase 4: Push and Create PR ───────────────────────────

[Handoff] Reviewing final diff and staging shipped changes...
[Handoff] Committing staged changes...
[Handoff] Pushing branch...
[Handoff] PR created: https://github.com/org/repo/pull/123

── Phase 5: Wait for GitHub Checks ───────────────────────

[Handoff] Inspecting workflows and current checks...
[Handoff] Waiting for GitHub checks...
  state: pending
  pending: ci/test, ai-review

[Handoff] Waiting for GitHub checks...
  state: action required
  failing check: ci/test

── Phase 6: Fix Loop (round 1/3) ─────────────────────────

[Handoff] Reading failed check logs...
[Handoff] Fixing smallest real cause: missing nil guard in auth middleware
[Handoff] Re-running local verification...
  - npm test
  Result: PASS
[Handoff] Committing fix and pushing...

── Phase 5: Wait for GitHub Checks ───────────────────────

[Handoff] Waiting for GitHub checks...
  state: action required
  actionable review: AI review requested error-path coverage

── Phase 6: Fix Loop (round 2/3) ─────────────────────────

[Handoff] Adding missing error-path test and response handling
[Handoff] Re-running local verification...
  - npm test
  - npm run lint
  Result: PASS
[Handoff] Committing fix and pushing...
[Handoff] Resolving addressed review thread on GitHub...
[Handoff] Hiding obsolete github-actions bot comment as RESOLVED...

── Phase 5: Wait for GitHub Checks ───────────────────────

[Handoff] Waiting for GitHub checks...
  state: green

[Handoff] PR checks green: https://github.com/org/repo/pull/123
```

### What This Shows

| Principle | How the example enforces it |
|-----------|-----------------------------|
| **PR creation is not the finish line** | The loop continues after PR creation until checks are green |
| **Verify before first push** | Local verification runs before the first PR is opened |
| **Docs belong before PR** | CHANGELOG/docs updates happen before the initial push |
| **Fix the smallest real cause** | The CI failure is addressed from logs, not by broad refactoring |
| **AI review is part of the loop** | Actionable AI review feedback triggers a second fix round |
| **Resolved feedback is closed explicitly** | After a fix is pushed, addressed threads/comments are marked resolved on GitHub |
| **Re-verify after every code change** | Each fix round reruns local verification before push |
| **Retry limit is explicit** | The example shows numbered fix rounds tied to the max of 3 |

## Completion

Done when:

- the PR exists
- relevant GitHub checks are green
- no relevant GitHub checks are pending

Escalate when:

- 3 fix rounds are exhausted
- a remaining issue requires user judgment
- GitHub checks stay pending past the wait timeout
