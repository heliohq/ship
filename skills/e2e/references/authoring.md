# Writing E2E Tests — Ship Calibration

This file calibrates E2E authoring to ship's conventions. Generic E2E
wisdom (selector hierarchy, auto-wait, test independence, API-arrange +
UI-act, parallelization) is assumed — this file captures only the
opinionated rules that keep multiple runs converging on the same style
and the same scope.

## The one rule

Assert on what a user or external caller observes. Not the DOM tree, not
internal state, not the count of API calls. A test is a specification of
externally visible behavior — anything else fights future refactors.

## Scope (the discipline that matters most)

For each change, cover exactly these three things:

1. **Every acceptance criterion from the spec** — one test per criterion,
   or one `describe` with 2-3 cases if the criterion has meaningful
   variations (logged-in vs guest, admin vs user). Not 10 cases.
2. **Regression sentinels for flows the diff clearly touched** —
   modified checkout? A checkout happy-path test must exist after this
   phase. Modified an API endpoint? That endpoint needs a test.
3. **One negative test per new feature** — a predictable error path
   (bad input, missing auth). Just one — proves error handling isn't
   silently broken, without polluting the suite.

**Do NOT cover:**
- Edge cases that belong in unit tests (algorithm branches, validation
  rules, boundary conditions)
- Styling details (unless visual regression is already set up)
- Third-party service internals (stub at the boundary)
- Flows the diff didn't touch

If you're writing more than ~5 tests for a single spec, stop — you're
drifting into unit-test territory, which is cheaper and faster there.

## Selectors — quick reference

Order of preference: **role + accessible name** → **`data-testid`** →
**label / text** → **CSS / XPath** (last resort, isolate in a
page-object). Add `data-testid` to the component if it's missing rather
than resorting to CSS.

## Flake policy (non-negotiable)

- **A test that only passes on retry is NOT passing.** Fix the root
  cause. "It's just flaky" is never the verdict.
- **Never use fixed `sleep` / `waitForTimeout` to stabilize an
  assertion.** Use framework auto-wait or wait on a user-visible signal
  (toast, heading, role appearing). Fixed waits are bug bait — too short
  fails under load, too long wastes CI.
- **After one failed retry, decide within seconds**:
  - *Real assertion mismatch* → report FAIL, do NOT weaken the assertion
    to make it green. The e2e_fix loop exists for exactly this case.
  - *Selector/timing issue* → fix the test, rerun up to 3 times, then
    stop. A test that needs 4 retries to pass is not a test.

## Assertions — calibration

Prefer **a few strong assertions** over many weak ones. "Order
confirmation shows order ID and total" is one strong test. Asserting on
every piece of text on the page is brittle noise. Avoid whole-page
snapshots — they're always regret in 3 months.

## File placement

Match the repo's existing convention if one exists. Otherwise:

| Framework | Default dir |
|---|---|
| Playwright, pytest-playwright | `tests/e2e/` |
| Cypress | `cypress/e2e/` |
| Capybara (RSpec) | `spec/system/` |

Keep fixtures and page-objects light — only extract when you'd otherwise
repeat the same 5-line block in 3+ tests. Premature abstraction hurts
here as much as in production code.
