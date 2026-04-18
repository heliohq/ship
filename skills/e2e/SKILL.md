---
name: e2e
version: 1.0.0
description: >
  Codify the change's user-facing behavior as persistent end-to-end tests that
  live in the repo and run in CI. Detects the existing E2E framework (Playwright,
  Cypress, pytest-playwright, etc.) or scaffolds one when absent, then writes or
  extends tests that lock in the spec's acceptance criteria. Use when: "add e2e
  tests", "write a playwright test", "codify this behavior", "regression test for
  this flow", or after QA passes in the auto pipeline. Note: this writes
  persistent test code — it is NOT the same as /ship:qa (which runs one-off
  exploratory checks and produces reports, not test code).
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Agent
  - AskUserQuestion
---

## Preamble (run first)

```bash
SHIP_PLUGIN_ROOT="${SHIP_PLUGIN_ROOT:-$(ship-plugin-root 2>/dev/null || echo "$HOME/.codex/ship")}"
SHIP_SKILL_NAME=e2e source "${SHIP_PLUGIN_ROOT}/scripts/preflight.sh"
```


# Ship: E2E

You are the first automated verification gate after dev. You write tests
that prove the change's acceptance criteria hold, run them against a real
app, and leave them committed in the repo so CI runs them on every future
commit. Review comes after you — so when reviewers see the diff, they see
code that already passed its own tests.

## Principal Contradiction

**"Trust me, it works" vs durable verification.** Dev just finished writing
code. The naïve next step is to ask a reviewer to read it. But a reviewer
can't tell from reading whether the app actually does what the spec asks —
only a running test can. Your job is to convert the spec's acceptance
criteria into runnable tests, prove they pass against the real app, and
commit them so they run forever.

QA (which runs after review) does a different job: human-like exploration
to catch what tests didn't think to check. You are the codified baseline;
QA is the creative sweep above it.

## Core Principle

```
CODIFY WHAT THE USER OBSERVES, NOT WHAT THE CODE DOES INTERNALLY.
ONE GOOD TEST PER ACCEPTANCE CRITERION > FIVE NOISY ONES.
MATCH THE REPO'S EXISTING STYLE BEFORE INVENTING A NEW ONE.
```

## Flow

```
1. Understand  Read spec + diff to know what behavior to codify
2. Detect      Find the existing E2E framework, or scaffold one
3. Author      Write/extend tests that cover the change
4. Run         Execute the suite, iterate until green or a real failure
5. Cleanup     Kill anything you started (shared/cleanup.md)
6. Report      Summarize tests added, results, and any regressions
```

## Red Flag

**Never:**
- Write tests for behavior that isn't in the spec — scope is the acceptance
  criteria the change introduced, plus regression coverage for flows the
  diff clearly affected. Nothing more.
- Test implementation details (private functions, internal state). E2E asserts
  on what a user or external caller sees.
- Paper over real bugs by weakening assertions or adding `skip` / `xfail` to
  make a test pass. If the app is broken, report it as a FAIL — don't hide it.
- Introduce a second E2E framework when one already exists. One is enough.
- Leave services, containers, or browsers running after you finish.
- Commit secrets into test fixtures. Use `.env.example` values or env vars.
- Mark the phase DONE with tests that never actually ran green at least once.

---

## Phase 1: Understand the change

The inputs decide everything. Read two things:

```bash
BASE=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
[ -z "$BASE" ] && BASE=$(git rev-parse --verify origin/main >/dev/null 2>&1 && echo main || echo master)
git diff "$BASE"...HEAD --stat
git diff "$BASE"...HEAD --name-only
```

1. **Spec** — `<task_dir>/plan/spec.md` (acceptance criteria you must codify)
2. **Diff** — what code actually changed, which flows it touches

That's it. In the /ship:auto pipeline you run right after dev and before
review/QA, so there is no earlier verification report to read. If you're
in re-run mode after an `e2e_fix`, the previous `<task_dir>/e2e/report.md`
may exist — useful for knowing which tests already failed.

### Skip check

Some changes don't need E2E coverage. Decide early:

| Diff shape | Decision |
|---|---|
| Docs-only (`*.md`, `LICENSE`, comments) | SKIP |
| Internal refactor with no user-observable change, fully covered by existing tests | SKIP (say so explicitly in the report) |
| CI / formatter / tooling config with no runtime effect | SKIP |
| New feature, bug fix, or behavior change that a user/API caller would notice | PROCEED |
| UI change (even minor) | PROCEED — visual regression and interaction flows matter |

If skipping, write a one-paragraph justification to
`<task_dir>/e2e/report.md` and emit the SKIP report card. Don't scaffold
frameworks or touch the test dir.

## Phase 2: Detect the framework

Read `references/frameworks.md` for the full detection + selection matrix.
Short version:

1. **Look for what's already there.** Search for Playwright, Cypress,
   pytest-playwright, Capybara, Testcafe, Nightwatch, rod, chromedp,
   `*.spec.ts`, `*.cy.js`, `tests/e2e/`, `e2e/`. If you find a framework
   in use, you are done — use it.
2. **If nothing exists**, pick one for the repo's primary language/stack and
   scaffold it. Read `references/scaffolding.md` for the install recipe.
   You do not need to ask the user — we pick a sensible default, and the
   choice can be swapped out later if they disagree. Scaffolding is a real
   commit (adds a dep and config files); that's intentional.

Default choices when scaffolding is needed:

| Stack | Default framework |
|---|---|
| JS/TS with a UI (Next, Vite, Remix, Nuxt, Astro, SvelteKit) | Playwright |
| JS/TS backend-only (Express, Fastify, Hono, Koa) | Playwright API testing (`request` fixture) or `supertest` + the repo's existing test runner |
| Python with a UI (Django templates, Flask+Jinja, FastAPI+frontend) | `pytest-playwright` |
| Python backend-only (FastAPI, Flask, Django REST) | `pytest` + `httpx` |
| Go | `net/http/httptest` + `go test` for API; `chromedp` only if browser flow required |
| Ruby on Rails | Capybara + Selenium (Rails convention) |
| CLI-only project | The repo's native test runner with subprocess-based integration tests |
| Electron | Playwright's Electron support |

The Playwright default exists because it's multi-language (TS, Python, .NET,
Java), ships its own browsers, and gives us screenshots/videos/traces for
debugging CI failures. If the agent sees a reason to pick otherwise — the
repo is Ruby, the team clearly favors RSpec, etc. — override the default.

## Phase 3: Author tests

Read `references/authoring.md` for patterns, selectors, data setup, and
assertion guidelines.

### What to cover

1. **Every acceptance criterion from the spec** — each becomes one test (or
   one `describe` block with a couple of cases). If QA verified it manually,
   automate the same flow.
2. **Regression sentinels for flows the diff clearly touched** — if the PR
   modifies checkout, at least one checkout happy-path test must exist after
   this phase. If the PR modifies an API endpoint, that endpoint must have
   a test.
3. **One negative test per new feature** — a predictable error path (bad
   input, missing auth, etc.). Just enough to prove error handling isn't
   silently broken.

### What to NOT cover

- Edge cases that belong in unit tests (algorithm branches, validation rules)
- Styling details (unless visual regression is already set up in the repo)
- Third-party service internals (mock or stub at the boundary)
- Flows the diff didn't touch — you are scoping to the change

### Where to write

Match the repo's convention. Common patterns:

| Framework | Location |
|---|---|
| Playwright | `tests/e2e/`, `e2e/`, `playwright/tests/` |
| Cypress | `cypress/e2e/` |
| pytest-playwright | `tests/e2e/`, `tests/integration/` |
| Capybara | `spec/system/`, `spec/features/` |

If the repo already has one of these directories, use it. If scaffolding from
scratch, prefer `tests/e2e/` (readable, language-agnostic).

## Phase 4: Run

Bring the app up via the shared startup reference:

```
Read ../shared/startup.md. Set EVIDENCE_DIR=".ship/tasks/<task_id>/e2e"
before running its commands so logs and PIDs land under the e2e folder.
Start services → run migrations → verify readiness.
```

Track PIDs in `<task_dir>/e2e/pids.txt` (the shared startup reference does
this automatically via `$EVIDENCE_DIR`). Phase 5 reads the same file.

Then run the suite. The exact command depends on the framework, but the
workflow is constant:

1. Run the **new/modified** tests first. Fastest feedback.
2. If they pass, run the full E2E suite to check for regressions.
3. If anything fails, decide: **test issue** (flaky selector, bad assumption)
   or **real bug** (implementation is wrong).
   - Test issue → fix the test, rerun. Up to 3 retries. If still failing
     after 3, it's not a test issue — it's a bug.
   - Real bug → report it as a FAIL. Do NOT weaken the test to make it
     pass. If the pipeline is in auto mode, this triggers `e2e_fix`, which
     routes back to /ship:dev to fix the code.

### Save artifacts

Playwright/Cypress produce traces, videos, and screenshots on failure. Copy
them into `<task_dir>/e2e/` so debuggers (human or agent) have evidence:

```bash
# $EVIDENCE_DIR was set before entering shared/startup.md — reuse it here
mkdir -p "$EVIDENCE_DIR/artifacts"
# Framework-specific examples — adapt to whatever the runner actually produces
[ -d playwright-report ] && cp -r playwright-report "$EVIDENCE_DIR/artifacts/" 2>/dev/null
[ -d test-results ] && cp -r test-results "$EVIDENCE_DIR/artifacts/" 2>/dev/null
[ -d cypress/screenshots ] && cp -r cypress/screenshots "$EVIDENCE_DIR/artifacts/" 2>/dev/null
[ -d cypress/videos ] && cp -r cypress/videos "$EVIDENCE_DIR/artifacts/" 2>/dev/null
```

## Phase 5: Cleanup

**Mandatory — never skip, even on failure or timeout.** Follow
`../shared/cleanup.md` with the same `EVIDENCE_DIR` you set in Phase 4.
It kills tracked PIDs (graceful then forceful), stops any docker compose
stack, and verifies ports are free. Do not inline your own cleanup logic —
the shared contract is the single source of truth.

## Phase 6: Report

Write `<task_dir>/e2e/report.md` with:

1. **Framework** — name, version, whether it was pre-existing or scaffolded
2. **Tests added/modified** — file paths and what each covers
3. **Run results** — pass/fail counts, timing
4. **Failures** (if any) — test name, assertion, and verdict (test issue vs
   real bug, with evidence)
5. **Regressions** (if any) — previously-passing tests that broke

Keep the report tight — the tests themselves are the durable artifact;
the report is for the pipeline to route decisions.

---

## Re-run mode

When invoked with `--recheck` (after `e2e_fix` made code changes):
- Restart services
- Run only the previously-failing tests + full regression suite
- Skip writing new tests (already written in first pass)
- Cleanup is still mandatory

## Standalone mode

When invoked outside `/ship:auto` (user types `/ship:e2e` directly):
- There is no `<task_dir>`. Pick one: `.ship/e2e-<date>/` works as a
  fallback evidence directory, or write directly next to the repo's test
  directory if no evidence is needed.
- The "understand" phase relies on `git diff` alone (no spec, no QA
  report). Use AskUserQuestion if the diff's intent is unclear — what
  flow does the user want locked in?

## Artifacts

```text
<task_dir>/
  e2e/
    report.md          — run summary & test inventory
    pids.txt           — tracked PIDs for cleanup
    artifacts/         — framework traces, videos, screenshots on failure

<repo>/tests/e2e/      — actual test files (committed to repo)
  or framework-idiomatic path depending on detection
```

## Reference files

- `../shared/startup.md` — bring the app up (shared with /ship:qa)
- `../shared/cleanup.md` — mandatory cleanup contract (shared with /ship:qa)
- `references/frameworks.md` — detection checks + framework selection matrix
- `references/scaffolding.md` — install recipes for each default framework
- `references/authoring.md` — writing good E2E tests (selectors, data,
  assertions, parallelization, stability)

## Execution Handoff

Output the report card (read `skills/shared/report-card.md` for the standard
format):

```
## [E2E] Report Card

| Field | Value |
|-------|-------|
| Status | <DONE / FAIL / BLOCKED / SKIP> |
| Summary | <N> tests added, <M>/<total> passing |

### Metrics
| Metric | Value |
|--------|-------|
| Framework | <name> (<pre-existing | scaffolded>) |
| Tests added | <N> |
| Tests modified | <N> |
| Suite pass rate | <N>/<total> |
| Regressions | <N> |
| Failures (real bugs) | <N> |

### Artifacts
| File | Purpose |
|------|---------|
| <task_dir>/e2e/report.md | Run summary |
| <task_dir>/e2e/artifacts/ | Traces, videos, screenshots (on failure) |
| <repo>/tests/e2e/*.spec.ts | New/modified test files (committed) |

### Next Steps
1. **Fix failures** — /ship:dev to address real bugs found by new tests
2. **Review next (if green)** — /ship:review to check correctness of the code
3. **Iterate tests** — /ship:e2e --recheck after fixes
```

