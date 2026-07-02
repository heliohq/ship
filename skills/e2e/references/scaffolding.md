# Scaffolding When No Framework Exists

When detection found nothing, install the default for the detected stack.
Scaffolding is a real commit: it adds a dep, a config file, maybe a test
directory, and a script entry. The user knows this is happening — we picked
the default for them on purpose.

## General rules

- **Use the repo's existing package manager.** If `pnpm-lock.yaml` is
  present, use pnpm. `yarn.lock` → yarn. `bun.lockb` → bun. Otherwise npm.
- **Pin versions conservatively.** Take the latest stable at scaffold time;
  don't pin to old versions to be "safe" — CI runs the same version on
  every machine.
- **Don't touch unrelated config.** If `tsconfig.json` already exists, add a
  separate `tsconfig.e2e.json` rather than editing the main one.
- **Wire it into CI hints.** Add a script entry (`npm test:e2e`, a
  `Makefile` target, etc.) so future CI integration is one step.

## Playwright (Node.js / TypeScript)

The most common default. Install non-interactively (the interactive
`create playwright` wizard is unreliable headless):

```bash
# Pick the package manager from the lockfile
if [ -f pnpm-lock.yaml ]; then PM="pnpm"; PMX="pnpm dlx"
elif [ -f yarn.lock ];     then PM="yarn"; PMX="yarn dlx"
elif [ -f bun.lockb ];     then PM="bun";  PMX="bunx"
else                            PM="npm";  PMX="npx"
fi

$PM add -D @playwright/test
$PMX playwright install --with-deps
```

Then create `playwright.config.ts` — this config encodes Ship's evidence
conventions (trace/screenshot/video on failure), keep those settings:

```ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: process.env.CI ? 'github' : 'html',
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});
```

Add `"test:e2e": "playwright test"` to `package.json` scripts if missing
(edit the file directly), and `mkdir -p tests/e2e` so the first test has
a home.

## pytest-playwright (Python)

```bash
# Pick the installer from lockfiles
if [ -f poetry.lock ];  then poetry add --group dev pytest-playwright
elif [ -f uv.lock ];    then uv add --dev pytest-playwright
elif [ -f Pipfile ];    then pipenv install --dev pytest-playwright
else                         pip install pytest-playwright
fi

# Download browsers
playwright install --with-deps chromium
```

Create `tests/e2e/conftest.py`:

```python
import os
import pytest

@pytest.fixture(scope="session")
def base_url():
    return os.environ.get("BASE_URL", "http://localhost:8000")
```

Extend `pytest.ini` (or create one) so `pytest` picks up the e2e directory:

```ini
[pytest]
testpaths = tests
markers =
    e2e: end-to-end browser tests (run with `pytest -m e2e`)
```

Add a make target or tool command:

```bash
# Makefile append (if Makefile exists)
cat >> Makefile <<'EOF'

.PHONY: test-e2e
test-e2e:
	pytest tests/e2e -m e2e
EOF
```

## supertest (JS/TS API-only, when a test runner already exists)

Only when the project already has Jest, Vitest, or node:test wired up and
the diff is backend-only: `$PM add -D supertest @types/supertest`, tests
in `tests/e2e/*.spec.ts` importing the app directly.

## Capybara + Selenium (Rails)

Rails already has Capybara wired via `rails generate`. If not scaffolded:

```ruby
# Gemfile (group :test do ... end)
gem 'capybara'
gem 'selenium-webdriver'
```

```bash
bundle install
rails generate system_test InitialE2E
```

Tests live in `spec/system/` or `test/system/` depending on whether the
repo uses RSpec or Minitest.

## chromedp (Go, browser flow required)

Prefer `net/http/httptest` for pure API. Only reach for chromedp when a
real browser is needed: `go get -u github.com/chromedp/chromedp`, tests
in `tests/e2e/` using `chromedp.NewContext` with a 30s
`context.WithTimeout`.

## Playwright (Electron)

```bash
$PM add -D @playwright/test
$PMX playwright install --with-deps chromium
```

Config uses `_electron`:

```ts
import { _electron as electron, test, expect } from '@playwright/test';

test('launches', async () => {
  const app = await electron.launch({ args: ['.'] });
  const win = await app.firstWindow();
  await expect(win).toHaveTitle(/.+/);
  await app.close();
});
```

## After scaffolding

1. **Commit the scaffold separately from your first test.** One commit
   "chore: add playwright for e2e tests", one commit "test: cover <feature>"
   — makes review easier. In /ship:auto mode, the handoff phase squashes
   however the repo prefers; at least keep the changes in logically
   separable blocks.
2. **Verify the scaffold works before writing real tests.** Run the empty
   suite or a placeholder test to confirm the runner, browser install, and
   start command all work end-to-end. Fix infra before writing product
   tests.
3. **Update `.gitignore`** for framework output dirs:
   ```
   /playwright-report/
   /test-results/
   /cypress/screenshots/
   /cypress/videos/
   /e2e-artifacts/
   ```

Output after scaffolding:

```
[E2E] Scaffolded <framework>.
[E2E] Config: <file>
[E2E] Test dir: <path>
[E2E] Run command: <cmd>
[E2E] .gitignore updated for output dirs
```
