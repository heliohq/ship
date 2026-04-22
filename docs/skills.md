# Skill Deep Dives

Detailed guides for every Ship skill — philosophy, workflow, and examples.

**Start here:** Run `/ship:auto` to see the full pipeline end-to-end. Use individual skills (`/ship:design`, `/ship:review`, etc.) when you only need one phase. Skills also trigger automatically based on what you're doing — say "plan this" and design kicks in, say "ship it" and handoff takes over.

**How auto-triggering works:** session start injects a short Ship routing policy that reinforces precedence and phase order. The host already provides the skill catalog; the injected policy just reminds the agent to invoke the matching `/ship:*` skill before acting and to default to `/ship:auto` for end-to-end feature work. See `docs/design/002-session-context-injection.md` for the full design.

| Skill | Role | What it does |
|-------|------|--------------|
| [`/ship:auto`](#auto) | **Pipeline Orchestrator** | The full pipeline. One command from task description to a PR with checks green and merge-ready. Delegates every phase to fresh subagents with quality gates at every transition. Fully autonomous — no approval gates. |
| [`/ship:design`](#design) | **Adversarial Designer** | The host agent and a peer agent independently investigate the codebase and produce specs in parallel. Divergences are resolved by code evidence and debate. The merged spec feeds an executable TDD plan validated by a peer drill. |
| [`/ship:dev`](#dev) | **Implementation Engine** | Host (Claude) implements directly; peer (Codex) cross-validates each story. File-independent stories in a wave run in parallel via Claude Agent subagents on the same branch — dependency analysis prevents overlap, no worktrees needed. |
| [`/ship:e2e`](#e2e) | **Regression Codifier** | Converts each change's acceptance criteria into persistent E2E tests committed to the repo. Detects or scaffolds the framework (Playwright, Cypress, pytest-playwright, etc.), runs the suite against the real app, and reports a pass/fail that reviewers see before they review the code. |
| [`/ship:review`](#review) | **Staff Engineer** | Find every bug in the diff. Add diagnosis only when multiple findings share one structural root cause. |
| [`/ship:qa`](#qa) | **Independent QA** | Exploratory human-like sweep against the running app — finds what the codified E2E suite didn't think to check (UX confusion, visual regressions, perf smells). Independence contract: cannot read review or plan. Only direct observation counts. |
| [`/ship:handoff`](#handoff) | **Release Engineer** | Creates a PR with a concise verification summary, then enters the fix loop: GitHub check failures, review comments, merge conflicts, and merge-readiness blockers. Doesn't stop until the PR is green and merge-ready or retries are exhausted. |
| [`/ship:refactor`](#refactor) | **Code Improver** | Four-lens parallel scan (structure, reuse, quality, efficiency), classify by risk (quick/planned), apply Fowler techniques with verification after every change. |
| [`/ship:setup`](#setup) | **Repo Bootstrapper** | Detects stack, installs tools, configures CI/CD and pre-commit hooks, discovers semantic constraints from code and git history, generates AGENTS.md + .learnings/LEARNINGS.md + hookify safety rules. Audits existing harness for staleness. |
| [`/ship:learn`](#learn) | **Session Learner** | Captures mistakes and discoveries from sessions into .learnings/LEARNINGS.md. Auto-verifies durable entries and prunes stale ones. |
| [`/ship:arch-design`](#arch-design) | **System Architect** | System design thinking — requirements gathering, component design, data modeling, scaling strategy, and trade-off analysis. Hands off to /ship:write-docs for the document. |
| [`/ship:write-docs`](#write-docs) | **Doc Author** | Creates and maintains structured project documentation under docs/ with frontmatter, status lifecycle, category conventions, and AI-indexed docs index. |
| [`/ship:visual-design`](#visual-design) | **Visual Design Author** | Creates DESIGN.md files — structured visual design systems (colors, typography, spacing, components) that AI agents read to generate consistent UI. |

---

## auto

This is the **full pipeline**.

You describe what you want to build. Ship handles the rest — plan, implement, E2E test, review, QA, simplify, handoff — with quality gates at every transition.

### Why an orchestrator?

AI coding agents are capable but unreliable. They skip tests, hallucinate about code they haven't read, review their own work and call it good, and declare victory without evidence. Ship makes these failure modes structurally impossible.

The orchestrator is code-driven: scripts/auto-orchestrate.sh owns all state management, artifact validation, phase transitions, and retry logic. The SKILL.md is a thin relay that dispatches Agent() calls and reports verdicts back to the script. A phase-guardrail.sh PreToolUse hook enforces artifact access rules (QA independence, review read-only, state file protection). State is tracked in .ship/ship-auto.local.md — the stop-gate hook prevents exit while the pipeline is active.

### The independence architecture

Implementation and review use **separate runtimes**. Cross-provider separation is preferred when available because model biases differ as well as session context. When only one provider is available, Ship still uses fresh same-provider sessions so review does not collapse into self-review.

The QA evaluator is contractually forbidden from reading the review or the plan. It can only look at the spec, the git diff, and the running application. Fresh context per phase means no accumulated bias, no rubber-stamping.

### Eight phases

    Bootstrap -> Design -> Dev -> E2E -> Review -> QA -> Simplify -> Handoff

1. **Bootstrap** — init task directory, detect base branch, create feature branch, write state file
2. **Design** — invoke /ship:design for adversarial planning
3. **Dev** — invoke /ship:dev to execute implementation stories (host implements; peer cross-validates)
4. **E2E** — invoke /ship:e2e to codify the change as persistent regression tests and run them. First automated gate after dev, so reviewers see green tests alongside the code
5. **Review** — invoke /ship:review for staff-engineer code review
6. **QA** — invoke /ship:qa against the running application for exploratory coverage beyond the codified tests
7. **Simplify** — behavior-preserving cleanup via /ship:refactor (four-lens scan: structure, reuse, quality, efficiency)
8. **Handoff** — invoke /ship:handoff to create PR and shepherd it until checks are green

Review, QA, and E2E all have fix loops: if issues are found, auto dispatches dev to fix them, then re-runs the phase. A `qa_fix:success` routes back through an E2E regression gate before the QA recheck — catches the case where a fix for a QA-reported issue accidentally breaks a committed E2E test. Every phase must produce its required artifacts — the orchestrator validates existence before advancing.

### State lives on disk

The current phase is tracked in .ship/ship-auto.local.md — a YAML frontmatter file with task_id, branch, and phase. The stop-gate hook reads this file and blocks session exit while the pipeline is active. On resume, auto reads the phase field and jumps directly to that phase.

### Example

    You:   Add rate limiting to the /api/upload endpoint

    Assistant: [Auto] Bootstrapping task: rate-limit-upload
            [Auto] Starting design phase...

            [Design] Read src/routes/api/upload.ts, traced to middleware chain...
            [Design] Found existing rate limiter in src/middleware/rateLimit.ts
                   but /api/upload bypasses it (line 42, direct route mount).
            [Design] Peer challenger confirmed: both plans agree on middleware approach.
            [Design] Execution drill passed — 3 stories, all implementable.

            [Auto] Design complete — 3 stories extracted.

            [Dev] Implementing 3 stories (host implements; peer reviews each)...
            [Dev] Story 1: PASS — middleware wired
            [Dev] Story 2: PASS — quota logic added with Redis counter
            [Dev] Story 3: PASS — 429 + Retry-After verified

            [E2E] Detected Playwright (existing tests/e2e/). Added 3 specs
                  for the new rate-limit flow. Suite green (18 tests).

            [Review] Code review (host sees code + green E2E suite)...
            [Review] 1 finding: Redis key missing TTL
            [Dev] Fixing review bugs...
            [Review] Re-reviewing... clean.

            [QA] Exploratory sweep against running app...
            [QA] Beyond-spec: concurrent uploads surface a 1-request leak;
                 recorded as concern (not FAIL — counter converges).
            [QA] Verdict: PASS_WITH_CONCERNS.

            [Simplify] No dead code found.

            [Handoff] Creating PR...
            PR #48 created. CI passing. Merge state clean. Ready for review.

One command. Task description to a PR with checks green and merge-ready. Fully autonomous.

---

## design

This is where **adversarial rigor** meets planning.

Most AI planning is a monologue. The model reads your request, skims the codebase, and writes a plan that sounds reasonable. The problem: "sounds reasonable" is not "survives contact with reality." Plans fail when they reference files that don't exist, assume APIs that have different signatures, or miss existing defenses that already handle the case.

### How it works

Two phases produce two artifacts:

**Phase 1: Design** — the host agent and a peer agent independently investigate the codebase using identical methodology and produce separate specs. The peer is dispatched first, then the host investigates in parallel. Neither sees the other's spec. Divergences are resolved by code evidence, and when evidence alone isn't conclusive, by debate (max 2 rounds on the peer thread/session, both sides cite file:line).

The merged spec follows brainstorming style — flexible sections scaled to complexity. A small bugfix gets a few paragraphs. An architectural change gets full sections.

**Phase 2: Write Plan** — The validated spec feeds an executable plan in writing-plans format: bite-sized TDD tasks with checkbox steps, complete code blocks, exact commands, no placeholders. The peer agent validates the plan via execution drill — checking format compliance, file path existence, and spec coverage.

### The adversarial loop

This is not a review. It is two independent investigations of the same problem by separate runtimes, ideally on different providers.

- **Specs diverge** — resolution by code evidence first. If still unresolved, debate with the peer agent on the same thread/session when possible (max 2 rounds, both sides cite file:line). Dispositions: patched, proven-false, conceded, or escalated to user.
- **Debate exhausted** — escalated items go to the user in standalone mode, or block in auto mode.

### The execution drill

The final gate: the peer agent reads the plan and checks every task for implementability. Format compliance (TDD order, checkboxes, no placeholders), file path verification (Create paths don't exist, Modify paths do), and spec coverage (every acceptance criterion has a task).

Tasks flagged UNCLEAR get revised and re-drilled once. Plans that survive are implementable.

### Example

    You:   Design adding WebSocket support for real-time notifications

    Assistant: [Design] Dispatching peer investigation...
            [Design] Investigating codebase...
            Read src/server.ts — Express app, no existing WS setup.
            Read src/routes/notifications.ts — polling endpoint, 5s interval.
            Read src/services/notificationService.ts — pushes to Redis pub/sub.
            Read package.json — no ws/socket.io dependency.

            [Design] Writing spec.md...

            [Design] Reading peer spec...
            [Design] Diffing specs...

            DIVERGENCE: Host spec modifies server.ts directly.
                        Peer spec creates separate ws-server.ts.
                        -> Code evidence: server.ts:14 already has upgrade
                          handler for health checks. Peer is right.
                        -> Disposition: conceded. spec.md updated.

            [Design] Writing plan.md (3 TDD tasks)...
            [Design] Execution drill...
            Peer flagged: "Task 2 Step 1 test references NotificationType
            but doesn't specify which file." -> UNCLEAR
            -> Revised: added src/types/notification.ts:8. Re-drilled: CLEAR.

            Design complete. spec.md + plan.md ready.

---

## dev

This is the **implementation engine**.

The key insight is role separation: **the host implements, the peer cross-validates.** Opus 4.7 is a strong implementer, and the host is the session that already has the full context (spec, plan, prior stories, CODE_CONDUCT, pattern references, TEST_CMD) — asking it to write the code directly is faster and produces better results than dispatching Codex as an implementer. Codex moves to the reviewer seat, where its different provider and training give an independent second eye on the diff.

### Role routing

| Wave shape | Implementer | Reviewer | Fix-round owner |
|---|---|---|---|
| Single-story (most common) | Host (you), on current branch | Peer (Codex) via `mcp__codex__codex` | Host — applies fixes directly |
| Multi-story parallel | Fresh Claude Agent subagents per story, all on the current branch (dependency analysis prevents file overlap — no worktrees) | Peer per story | Fresh Claude Agent subagent — whoever implemented, fixes |
| Fix mode (/ship:auto review_fix/qa_fix/e2e_fix) | Host — you | Next-phase re-run is the validator | Host — applies fixes directly |

Independence is preserved two ways: different provider (Codex ≠ Claude) AND different session. Both hold across all wave shapes. Fallback: if the peer runtime is unavailable, a fresh Claude Agent reviewer runs — same-provider independence is weaker, and the dev report flags it.

### Waves and dependency analysis

Stories are analyzed for dependencies (shared files, import chains) and grouped into **waves**. Independent stories within a wave run **in parallel** on the same branch — no git worktrees. The wave's dependency analysis is what prevents file-scope overlap; git's `.git/index.lock` serializes concurrent commits automatically.

1. **Build pattern references** — for each story, read the closest analogous implementation and tests, then record the files and conventions in `dev-context.md`
2. **Build dependency graph** — identify which stories create, modify, or import the same files
3. **Sort into waves** — topological sort into groups with no intra-group dependencies
4. **Per wave** — host implements single-story waves directly; multi-story waves dispatch parallel subagents; peer (Codex) reviews each story's commits
5. **Cross-story regression** — host runs full test suite after all waves complete

If a reviewer returns FAIL — targeted fix (max 2 rounds), not a full rewrite. Whoever implemented is who fixes: host for single-story and fix mode; a fresh sub-agent for multi-story.

### Example

    You:   /ship:dev

    Assistant: [Dev] Reading plan: 3 stories for rate-limit-upload

            [Dev] Dependency analysis: 2 waves
                  Wave 1: [Story 1, Story 2] <- parallel (no shared files)
                  Wave 2: [Story 3] <- depends on Story 1

            [Dev] Wave 1: dispatching 2 Claude Agent subagents in
                  parallel on current branch (dependency analysis says
                  their files don't overlap)...
                  Story 1 subagent: DONE — middleware/rate-limit.ts, commit a1
                  Story 2 subagent: DONE — services/quota.ts, commit a2
            [Review] Peer (Codex) reviews Story 1 → PASS
            [Review] Peer reviews Story 2 → FAIL — Redis key uses IP instead of user ID
            [Dev] Fresh subagent dispatched to fix Story 2 (round 1/2)
                  — "whoever implemented, fixes": new subagent plays
                  the implementer role with the original story + FAIL
                  findings. Commit a3.
            [Review] Peer re-reviews Story 2 → PASS.

            [Dev] Wave 2: Story 3 is single-story, I implement directly.
                  Return 429 with Retry-After header. Commit a4.
            [Review] Peer reviews Story 3 → PASS.

            [Dev] Cross-story regression: npm test → all tests green.
            [Dev] 3/3 stories, 2 waves complete.

---

## e2e

This is the **regression codifier**.

QA proves the change works *now*; E2E makes sure it keeps working *forever* by leaving a committed test behind. In the pipeline, E2E runs right after dev — before review — so reviewers see both the code and its green test suite in a single pass, the way a human PR reviewer does in a CI-green PR.

### How it works

Given the change's acceptance criteria and the diff, E2E:

1. **Detects the framework** — searches for Playwright, Cypress, pytest-playwright, Capybara, chromedp, and their config/manifest signatures. Uses whatever's already there.
2. **Scaffolds when absent** — if the repo has no E2E framework at all, picks a sensible default for the stack (Playwright for JS/TS with UI, pytest-playwright for Python, the native test runner for CLI-only projects) and installs it. The choice is deterministic, not asked — users who want to swap it later can, but the skill doesn't block on "which one should I pick?"
3. **Authors tightly-scoped tests** — one test per acceptance criterion, regression sentinels for flows the diff clearly touches, one negative test per new feature. Nothing more. Edge cases that belong in unit tests stay in unit tests.
4. **Runs the suite against the real app** — reuses `shared/startup.md` to bring the app up (same logic QA uses), then executes the framework's native test command. Traces, videos, and screenshots on failure get copied into the evidence dir.
5. **Fails on real bugs, not flakiness** — a test that only passes on retry is not passing; the skill fixes the root cause or reports FAIL. It does NOT weaken assertions to go green.

### Skip conditions

Not every change needs E2E. The skill skips when the diff is docs-only, tooling-only with no runtime effect, or an internal refactor with no user-observable change (and existing tests cover the behavior). Each SKIP is justified in the report.

### In the auto pipeline

After dev, E2E runs as the first automated gate. If tests pass, the pipeline advances to review. If a test fails because the implementation is wrong, the fix loop (`e2e_fix`) routes back to dev. When dev finishes and E2E re-checks green, the pipeline continues forward.

### Example

    You:   /ship:e2e

    Assistant: [E2E] Diff touches routes/api/upload.ts + middleware/rate-limit.ts
            [E2E] Detected Playwright (playwright.config.ts + tests/e2e/)
                  — using it. No scaffold needed.

            [E2E] Authoring tests under tests/e2e/:
                  - rate-limit.spec.ts: upload allowed under quota
                  - rate-limit.spec.ts: upload blocked at quota with 429
                  - rate-limit.spec.ts: Retry-After header present

            [E2E] Starting app (shared/startup.md)... ready on :3000
            [E2E] Running new tests... 3/3 PASS
            [E2E] Running full suite for regression... 18/18 PASS

            [E2E] Cleanup: killed app PID, docker compose stopped, port 3000 free.
            [E2E] DONE — 3 tests added, suite 18/18 green.

---

## review

This is the **staff engineer who finds the disease, not just the symptoms**.

Code review has one job: **find every bug** in the diff. N+1 queries, race conditions, trust boundary violations, missing error handling on partial failures, tests that test the wrong thing, forgotten enum handlers when new values are added. All of them, with file:line + triggering scenario.

When multiple findings share one structural root cause, the review adds a short **diagnosis** — but only when it genuinely explains the pattern. Diagnosis is optional and always secondary to concrete findings.

### How it works

1. **Scope the change** — read the diff, identify what files changed, trace the blast radius through imports and call sites
2. **Hunt for bugs** — walk every changed function looking for correctness issues, not style preferences
3. **Rank findings** — each finding gets a priority:
   - **P1** — will break in production (data loss, crash, security hole)
   - **P2** — will break under specific conditions (race condition, edge case, error path)
   - **P3** — latent risk (missing validation that hasn't been exploited yet)
4. **Diagnose root cause** — when multiple findings share one structural deficiency, add a short diagnosis explaining the pattern

### What it won't do

- No style or formatting nits
- No suggestions for "better" patterns that aren't bugs
- No rewriting code — findings only, with enough context to fix

### Example

    You:   /ship:review

    Assistant: [Review] Reading diff: 4 files changed, 127 insertions
            [Review] Tracing blast radius...
            src/api/rate-limit.ts -> src/middleware/index.ts -> 12 route handlers

            Findings:

            P1 — Redis counter never expires (src/api/rate-limit.ts:34)
              The INCR key has no TTL. After the first rate limit window,
              the counter grows forever. Users get permanently rate-limited.
              Trigger: any user who hits the limit once can never upload again.

            P2 — Race condition in quota check (src/api/rate-limit.ts:41-43)
              GET then INCR is not atomic. Two concurrent requests can both
              read count=99, both increment, both succeed. The 100th and
              101st requests both pass.
              Trigger: concurrent uploads from the same user.

            P3 — Missing error handling on Redis connection (src/api/rate-limit.ts:28)
              If Redis is down, getAsync throws unhandled. The upload endpoint
              returns 500 instead of falling back to permissive mode.
              Trigger: Redis restart during deployment.

            Diagnosis: all three findings trace to treating Redis as a simple
            key-value store instead of using atomic operations with built-in
            expiry (INCR + EXPIRE or SET with EX and NX).

---

## qa

This is **independent QA**.

The most important word is "independent." The QA evaluator is contractually forbidden from reading the review or the plan. It looks at three things: the spec (what was supposed to be built), the git diff (what changed), and the running application (what was actually built). This independence contract exists because every other phase has optimistic bias — the implementer thinks their code works, the reviewer saw the implementation context, the verifier ran the tests the implementer wrote. QA is the outsider.

### Evidence hierarchy

Every verdict must be backed by direct evidence — screenshots, curl responses, command output. "Should work based on code" is not evidence. HTTP 200 alone is not proof — inspect the response body.

### How it works

QA reads the spec and the git diff, then matches testing to what changed:

- **Frontend changes** — browser testing (via agent-browser)
- **API changes** — endpoint testing (via curl)
- **CLI changes** — terminal testing

Most projects have a frontend. When you test through the browser, you implicitly test the API, auth, database, and most of the stack.

### Example

    You:   /ship:qa

    Assistant: [QA] Reading spec and diff...
            [QA] Diff touches: src/api/rate-limit.ts, src/components/UploadForm.tsx
            [QA] Starting application... server ready on :3000

            [QA] Testing spec criteria:
            Rate limit at 100 uploads/hour — PASS
              curl: POST /api/upload x101, 101st returns 429 {"error":"rate limited"}
            Retry-After header present — PASS
              curl: Retry-After: 3600 in 429 response
            Non-upload endpoints unaffected — PASS
              curl: GET /api/status returns 200 during rate limit

            [QA] Beyond spec:
            - Concurrent uploads from same user: rate limit triggers correctly
            - Unauthenticated requests: returns 401 before rate limit check
            - Edge: 100th request returns 200, 101st returns 429

            Verdict: PASS — all spec criteria met, no issues found

---

## handoff

This is the **last mile**.

Most branches die after the interesting work is done. The code works, the tests pass, but the PR never gets created — or it gets created and then CI fails and nobody fixes it. Handoff exists to close that gap.

### The PR summary

Handoff doesn't just create a PR. It carries the minimum useful verification summary.

Every PR body should say:

- what changed
- what local verification ran
- any known follow-up, risk, or skipped check

### The fix loop

After creating the PR, handoff enters a loop:

1. Wait for CI
2. If CI fails — read logs, dispatch fix, re-push
3. If review comments — mechanical fixes auto-addressed, judgment calls escalated
4. If merge state is blocked, behind, or conflicting — sync/resolve, re-verify
5. If unresolved actionable review threads remain — fix or escalate

Handoff prefers clean linear history when it can do that safely. Before a
branch is pushed, that usually means rebase. After a PR exists, the agent
judges the branch state: if the branch is agent-owned, no human approvals or
unresolved human review threads exist, no other author has pushed commits, and
the repo expects linear history, it can rebase and push with
`--force-with-lease`. If those gates fail, it uses merge/update-branch or
escalates.

Completion requires more than green checks: no relevant checks can be pending,
the PR must not be conflicting, no local conflict state can remain, and any
branch update required by GitHub or repo policy must be done. Max 3 rounds. If
it can't get the PR checks green and merge-ready in 3 rounds, it escalates to
you with a clear explanation of what's blocking.

### Documentation truth check

Before declaring the PR ready, handoff checks the documents directly affected by the diff: commands, config, file paths, workflow behavior, public API, or durable repo guidance. It updates mechanically stale docs in the same loop, or carries semantic doc debt into the PR instead of inventing wording. It does not perform a full-repo documentation audit.

### What it won't do

- Never use plain force push; pushed-branch rebases require
  `--force-with-lease` and the safety gates above
- Never skip tests
- Never auto-merge (creates the PR, doesn't merge it)
- Never address security or architecture review comments without asking you

### Example

    You:   /ship:handoff

    Assistant: [Handoff] Checking proof freshness...
            Tests: PASS at a1b2c3d (current HEAD)
            Lint: PASS at a1b2c3d
            QA: PASS at a1b2c3d

            [Handoff] Checking merge readiness... clean.
            [Handoff] Creating PR #48...

            [Handoff] Waiting for CI...
            CI: 3/3 checks passed
            Merge state: CLEAN

            [Handoff] PR #48 checks are green and merge-ready.
            https://github.com/yourorg/yourrepo/pull/48

---

## refactor

This is the **structural diagnostician**.

Refactoring is not "clean up the code." It's answering: **why does adding a feature feel harder than it should?**

### Trace from pain, not from structure

Bad refactoring starts with "this module is too big" or "we should use the repository pattern." Good refactoring starts with a specific pain: "every time we add a new notification type, we have to change 4 files." That pain traces to a structural crack — a boundary that doesn't match how the code is actually used.

refactor traces from the concrete pain to the crack:

1. **Start with the painful change** — what specific thing is hard to do?
2. **Trace the dependency chain** — why does this change touch so many files?
3. **Find the crack** — which boundary is misaligned with usage?
4. **Validate with counterfactual** — if we fixed this crack, would the painful change become simple?
5. **Check git history** — is this a one-off or a pattern?

### Diagnosis depth matches input

- **Directive** ("extract this into a module") — light validation, then execute
- **Area** ("refactor the auth system") — medium diagnosis, then spec
- **Pain** ("adding notifications is painful") — full diagnosis from pain to crack
- **Vague** ("something feels wrong in this codebase") — full diagnosis, widest search

### What it produces

Code changes, not documents. Diagnoses the pain, traces to the structural crack, then fixes directly. Surgical execution for within-file smells, structural execution (with an execution card) for cross-file issues.

### Example

    You:   Every time I add a new payment provider, I have to change 6 files.

    Assistant: [Refactor] Tracing from pain...
            Read src/payments/stripe.ts, src/payments/paypal.ts
            Read src/routes/checkout.ts — switch statement on provider type (line 84)
            Read src/services/billing.ts — another switch (line 112)
            Read src/types/payment.ts — union type (line 23)
            Read tests/payments.test.ts — duplicated test setup per provider

            [Refactor] Found the crack:
            Payment providers are scattered across a type union, two switch
            statements, and duplicated test setup. Adding a provider means
            updating all four locations plus the route handler.

            The boundary should be: one file per provider that implements
            a common interface. The switch statements become a registry lookup.

            [Refactor] Git history confirms pattern:
            - 4 PRs in last 3 months each touched all 6 files
            - Average PR size for "add provider": 340 lines (should be ~80)

            [Refactor] Counterfactual:
            With a provider interface + registry, adding a provider is:
            1 new file implementing the interface, 1 line registering it.

            Spec written to .ship/tasks/refactor-payments/plan/spec.md
            Handing off to auto...

---

## setup

This is the **repo bootstrapper**.

New repo? Inherited codebase? Missing linter? No CI? setup handles all of it — and then discovers semantic constraints that AI agents would violate without project context.

### Infrastructure

Detects languages (15 supported including Shell), package managers, linters, formatters, type checkers, test runners, CI/CD, and pre-commit hooks. You pick which modules to configure. It respects existing config — if you already have husky or .pre-commit-config.yaml working, it won't migrate.

### Harness

Investigates code and git history for two types of rules:

- **Semantic rules** (.learnings/LEARNINGS.md) — things only AI can judge: "don't remove auth to fix errors", "price is in cents not dollars", "legacy module is being migrated". Injected into every session via SessionStart hook.
- **Safety rules** (hookify) — deterministic regex checks: block editing .env files, block DROP TABLE. Real-time PreToolUse blocking.

If harness files already exist (AGENTS.md, CLAUDE.md, .learnings/LEARNINGS.md), setup audits them for staleness before generating.

### Three-layer defense

| Layer | Tool | How | Cost |
|-------|------|-----|------|
| Real-time block | Hookify rules | regex on PreToolUse | Free |
| Semantic context | .learnings/LEARNINGS.md | SessionStart injection | Free |
| Commit-time | Pre-commit hook | lint + format | Free |

### Example

    You:   /ship:setup

    Assistant: [Setup] Detecting stack...
            TypeScript (pnpm)
            Linter: oxlint (ready)
            Formatter: prettier (ready)
            Test runner: vitest (ready)
            Pre-commit: lint-staged configured, no hook runner

            [Setup] Wiring lint-staged via core.hooksPath...

            [Setup] Investigating constraints...
            Git history: 1 revert (notebook metadata), 12 bug fixes
            Code: auth flow in src/auth/, no obvious semantic traps

            SAFETY RULES (hookify):
              [D1] Block .env file edits

            SEMANTIC RULES (.learnings/LEARNINGS.md):
              [S1] Don't remove auth checks to fix errors
                  Why: AI agents delete validation to make errors go away

            [Setup] Complete.

            AGENTS.md: generated
            .learnings/LEARNINGS.md: 1 semantic rule
            Hookify: 1 safety rule
            Pre-commit: wired via core.hooksPath

---

## learn

This is the **self-improving harness**.

Every session produces knowledge — mistakes made, surprises discovered, project quirks found. Without capture, the next session starts from scratch. /ship:learn captures that knowledge and routes it to the right persistent store.

### Fully autonomous

No user interaction. The skill reflects on the session, classifies each learning, and writes it to the correct store:

| Learning type | Destination |
|---|---|
| Code constraint requiring AI judgment | .learnings/LEARNINGS.md |
| Deterministic check (grep/regex can catch) | Hookify rule |
| Architectural decision or boundary | Design doc |
| Operational knowledge | .learnings/LEARNINGS.md (staging) |

### Staging lifecycle

.learnings/LEARNINGS.md is a staging area, not a permanent store. Learnings that prove durable (repeated, aged + still valid) get auto-promoted to permanent stores. Learnings that go stale (scope deleted, already covered, contradicted) get auto-pruned. The staging file stays lean.

### Harness memory layers

All injected at session start via session-start.sh:

1. **Embedded Ship routing policy** — concise session-start guidance that reinforces `/ship:*` precedence and default routing
2. **Verified entries from `.learnings/LEARNINGS.md`** — code-level guardrails trusted at session start
3. **docs/DOCS_INDEX.md** — architecture-level guardrails (auto-generated from design doc frontmatter)
4. **DESIGN.md** — visual design system pointer (title + section list; full content read on demand when writing frontend code)

### Example

    You:   /ship:learn

    Assistant: [Learn] Reflecting on session...

            Found 3 learnings:

            1. SEMANTIC — Price fields in src/models/order.ts are stored in
               cents, not dollars. AI agents kept generating dollar amounts
               in test fixtures, causing off-by-100x assertion failures.
               -> Written to .learnings/LEARNINGS.md

            2. SAFETY — AI agent edited .env.production directly to "fix"
               a missing DATABASE_URL. Should never touch .env files.
               -> Created hookify rule: block .env file edits

            3. ARCHITECTURAL — The notification service (src/services/notify.ts)
               must stay decoupled from the order service. Previous attempt
               to merge them broke the event replay system.
               -> Flagged for write-docs (no existing doc covers this boundary)

            Session learnings captured. 1 semantic rule, 1 hookify rule,
            1 write-docs candidate.

---

## arch-design

This is **system design thinking**.

Before writing a design document, you need to actually think through the design — requirements, components, trade-offs, scaling strategy. arch-design provides a structured methodology for that thinking, then hands off to `/ship:write-docs` for the actual document.

### Five phases

1. **Requirements Gathering** — functional requirements, non-functional requirements (latency, throughput, availability), constraints (tech stack, team, timeline)
2. **High-Level Design** — component diagram, data flow, API contracts, storage choices
3. **Deep Dive** — data model, API design, caching strategy, async/queues, error handling
4. **Scale and Reliability** — load estimation, scaling strategy, failover, monitoring
5. **Trade-off Analysis** — explicit trade-offs per major decision, alternatives considered, why this choice won

### Design doc output

When the design thinking is complete, the result is written as a design document via `/ship:write-docs`. Every design doc needs:

- **Boundaries section** (required) — the core anti-drift mechanism
- **Trade-offs section** (recommended) — alternatives and why this choice won
- **Assumptions section** (recommended) — what must be true for this design to hold

### Example

    You:   Design the notification system architecture

    Assistant: [Arch Design] Phase 1: Requirements...
            - Must handle 10k events/sec at peak
            - Delivery latency < 500ms p99
            - At-least-once delivery guarantee
            - Existing stack: Node.js, Redis, PostgreSQL

            [Arch Design] Phase 2: High-Level Design...
            Order Service -> Redis Pub/Sub -> Notification Service -> Delivery
            Storage: PostgreSQL for delivery log, Redis for dedup

            [Arch Design] Phase 3: Deep Dive...
            Data model: notifications table (id, type, payload, status, created_at)
            Retry: exponential backoff, 3 attempts, DLQ after exhaustion
            Idempotency: Redis SET NX with event ID

            [Arch Design] Phase 4: Scale...
            10k events/sec -> 2 consumer instances with horizontal scaling
            Redis cluster for pub/sub throughput
            PostgreSQL partitioned by month

            [Arch Design] Phase 5: Trade-offs...
            Redis pub/sub vs Kafka: chose Redis (simpler, team knows it,
            sufficient at current scale). Revisit at 100k events/sec.

            [Arch Design] Handing off to /ship:write-docs...

---

## write-docs

This is **structured documentation for AI and humans**.

Docs prevent knowledge rot — the slow death of useful information when it lacks structure, status tracking, or discoverability. Without managed docs, guides go stale, troubleshooting playbooks drift from reality, and design decisions are lost.

### How it works

1. **Pick a category** — which subdirectory under `docs/` does this belong in? (design, guides, troubleshooting, reference, or create a new one)
2. **Write the doc** — structured markdown with YAML frontmatter under `docs/<category>/`, following the numbered naming convention (e.g., `guides/003-getting-started.md`)
3. **Add frontmatter** — title, description, category, number, status, last_modified. The `category` field matches the subdirectory name.
4. **Index automatically** — `generate-docs-index.sh` builds a compact table from all doc frontmatter across categories, injected at session start so AI agents know what docs exist

### Structured for AI indexing

Every managed doc has YAML frontmatter with fields designed for machine consumption:

- **description** — one sentence for AI relevance filtering
- **category** — which category this doc belongs to (design, guides, troubleshooting, etc.)
- **status** — trust signal (current, draft, partially-outdated, superseded, not-implemented)
- **services** — which directories this doc covers
- **last_modified** — when the doc was last updated

### Status lifecycle

    draft -> current -> partially-outdated -> superseded

- **draft** — proposed, not yet validated. AI should read but not treat as authoritative.
- **current** — validated and enforced. AI must follow boundaries defined here.
- **partially-outdated** — some sections no longer reflect code. AI should verify specific claims before acting on them.
- **superseded** — replaced by a newer doc. AI should follow the replacement.

### Example

    You:   Document the auth failure troubleshooting steps

    Assistant: [Write Docs] Investigating...
            Read src/auth/middleware.ts — JWT validation, token refresh flow
            Read support tickets — common failure patterns: expired tokens, clock skew

            [Write Docs] Writing docs/troubleshooting/001-auth-failures.md...

            ---
            title: Authentication Failures
            description: Diagnosis and fix steps for common auth failures including
              expired tokens, clock skew, and missing refresh tokens.
            category: troubleshooting
            number: "001"
            status: current
            services: [src/auth]
            last_modified: 2026-04-13
            ---

            ## Symptom
            Users get 401 responses after token expiry...

            ## Diagnosis
            Check the JWT expiry timestamp vs server clock...

            ## Fix
            1. Verify NTP sync on the server...

            [Write Docs] Updating docs index...
            Doc troubleshooting/001 indexed and injected at session start.

---

## visual-design

This is **visual consistency for AI-generated UI**.

A DESIGN.md is like AGENTS.md for visual identity: drop it in your project root and any AI coding agent generates UI that matches your design language. No Figma exports, no JSON schemas — just markdown.

### Three modes

| Mode | When to use | Process |
|------|------------|---------|
| **From Scratch** | User describes a vision | Collaborative discovery: one question at a time, propose 2-3 directions, validate palette and typography before completing all 9 sections |
| **From URL** | User provides a website | DOM inspection: clarify scope and intent, extract exact values from computed styles, validate extracted foundation with user |
| **From Codebase** | Existing project needs a DESIGN.md | Reverse-engineering: detect tech stack, extract tokens from config/CSS/theme, validate with user, fill gaps from framework defaults |

All three modes share the same output: a 9-section DESIGN.md + a self-contained preview.html.

### The 9-section format

Every DESIGN.md follows the same structure: Visual Theme, Color Palette, Typography, Component Stylings, Layout Principles, Depth & Elevation, Do's and Don'ts, Responsive Behavior, and Agent Prompt Guide. Section 9 (Agent Prompt Guide) is the cheat sheet — an agent reading just that section can produce on-brand components.

### Session-start injection

When DESIGN.md exists at project root, session-start.sh injects a lightweight pointer (title + section list) into every agent session — not the full file. When writing frontend code, agents read DESIGN.md on demand for the actual design tokens and values.

### Example

    You:   /ship:visual-design — capture the design of linear.app

    Assistant: [Visual Design] Scope: linear.app homepage + features page
            Intent: inspiration (not exact recreation)

            [Visual Design] Inspecting site...
            Extracted 18 colors, 2 font families, 6 shadow levels

            [Visual Design] Extracted palette:
            - Void Black (#0A0A0B): Primary background
            - Linear Blue (#5E6AD2): Brand primary, CTAs
            - Soft Gray (#8A8F98): Body text
            ... (15 more)

            Does this capture the palette? [user confirms]

            [Visual Design] Writing DESIGN.md (9 sections)...
            [Visual Design] Generating preview.html...
            [Visual Design] Complete.

            DESIGN.md + preview.html written to project root.
