# Framework Detection & Selection

This file answers two questions: **does the repo already use an E2E
framework?** and if not, **which one should we pick?** The goal is a
single clear answer — "use X, here's where its tests live" — so Phase 3
can start writing.

## Phase A: Detection

Check in order. Stop the moment you have a confident answer.

### 1. Config files (highest signal — explicit)

```bash
ls playwright.config.ts playwright.config.js playwright.config.mjs 2>/dev/null
ls cypress.config.ts cypress.config.js cypress.json 2>/dev/null
ls wdio.conf.ts wdio.conf.js 2>/dev/null          # WebdriverIO
ls nightwatch.conf.js nightwatch.json 2>/dev/null # Nightwatch
ls testcafe.json .testcaferc.json 2>/dev/null     # TestCafe
ls .nuxt-test.js vitest.e2e.config.ts 2>/dev/null # Vitest (when used for e2e)
```

A config file means the framework is definitely in use. Use it.

### 2. Package manifest

```bash
# Node
grep -E '"(playwright|@playwright/test|cypress|webdriverio|testcafe|nightwatch|puppeteer)"' package.json 2>/dev/null

# Python
grep -E '(playwright|pytest-playwright|selenium|splinter|helium)' pyproject.toml requirements*.txt 2>/dev/null

# Ruby
grep -E '(capybara|selenium-webdriver|cuprite|ferrum)' Gemfile 2>/dev/null

# Go
grep -E '(chromedp|rod|playwright-go)' go.mod 2>/dev/null

# Java
grep -E '(selenium|playwright|cypress-io)' pom.xml build.gradle 2>/dev/null
```

### 3. Test directories

```bash
ls -d tests/e2e e2e cypress playwright/tests tests/integration 2>/dev/null
find . -maxdepth 4 -type d \( -name 'e2e' -o -name 'cypress' -o -name 'system' \) 2>/dev/null | head -5
```

### 4. Test file patterns

```bash
# Playwright: *.spec.ts inside e2e/ or tests/
find . -maxdepth 4 -name '*.spec.ts' -path '*e2e*' 2>/dev/null | head -3
# Cypress: *.cy.{js,ts}
find . -maxdepth 4 -name '*.cy.ts' -o -name '*.cy.js' 2>/dev/null | head -3
# RSpec system tests: spec/system/*_spec.rb
find spec/system -maxdepth 2 -name '*_spec.rb' 2>/dev/null | head -3
```

### Decision

- **Multiple frameworks found**: use the one with the most test files (`find
  <dir> -type f | wc -l`). Don't introduce a second one.
- **One framework found**: use it.
- **None found**: proceed to Phase B (selection).

Output what you decided:

```
[E2E] Detected framework: <name> (pre-existing)
[E2E] Test location: <path>
[E2E] Test command: <cmd>  # from package.json scripts / Makefile / Procfile
```

## Phase B: Selection (only when nothing exists)

Pick the default for the repo's primary stack. Scaffolding is Phase C
(see `scaffolding.md`).

| Detected stack | Default framework | Why |
|---|---|---|
| JS/TS + browser UI (Next, Nuxt, Vite, Remix, Astro, SvelteKit, CRA) | **Playwright** | Multi-browser, first-party TS, great CI story, free traces |
| JS/TS backend-only (Express, Fastify, Hono, NestJS API) | **Playwright** (`request` fixture) or **supertest** if an existing unit-test runner is present | Playwright's `request` API avoids a new dep; supertest if Jest/Vitest already drives tests |
| Python + browser UI (Django, Flask+Jinja, FastAPI+frontend) | **pytest-playwright** | Works with the ecosystem's default runner, same browser story as JS |
| Python backend-only (FastAPI, Flask, Django REST) | **pytest + httpx** | Fast, no browser needed, matches project idiom |
| Ruby on Rails | **Capybara + Selenium** | Rails convention, integrates with RSpec/minitest |
| Go | **`net/http/httptest` + `go test`** for API; **chromedp** only if a browser flow is required | Native toolchain is already strong; only reach for a browser lib if needed |
| Elixir + Phoenix | **Wallaby** or **Hound** | Phoenix convention |
| Electron | **Playwright** (Electron support) | `_electron.launch` API |
| CLI-only (any language) | Native test runner + subprocess-driven integration tests | No browser, no need for an E2E-specific framework |

### Tiebreakers

If multiple defaults could fit (e.g., a Python project that has a FastAPI
backend AND a React frontend under `web/`):

1. **What does the diff touch?** If the change is UI-only, pick a browser
   framework. If it's pure API, skip the browser tool.
2. **What does CI already know how to run?** Prefer frameworks whose
   `npm test`, `pytest`, `go test`, etc. are already wired into CI.
3. **What is the team's apparent preference?** Comments in CLAUDE.md /
   AGENTS.md, or patterns in adjacent repos (same org), win over defaults.

### When the repo is a monorepo

Treat each package independently. A test for a backend route goes in
`packages/api/tests/e2e/`; a test for the frontend goes in
`packages/web/tests/e2e/`. If a cross-package flow needs coverage, write it
at the root level with a root-level runner (usually Playwright).

### What to output after selection

```
[E2E] No pre-existing framework found.
[E2E] Selected: <framework> for <stack>.
[E2E] Rationale: <one sentence>
[E2E] Next: scaffold (see scaffolding.md).
```

No AskUserQuestion here — the selection is deterministic given the detected
stack. The user asked us to trust the agent, so we do.

## Anti-patterns

- **Don't introduce a second framework.** If the repo has Cypress, keep
  using Cypress even if you'd personally prefer Playwright. The cost of
  two runners in CI outweighs the benefit of a "better" tool.
- **Don't pick a framework just because it's trendy.** The defaults above
  prioritize "works with what's already here" and "gives useful debug
  artifacts on failure" — not popularity.
- **Don't try to write an E2E test without a framework.** If the stack
  genuinely has no E2E story (rare, usually pure library code with no
  runtime), write integration tests using the native test runner instead
  and note it in the report as a SKIP with justification.
