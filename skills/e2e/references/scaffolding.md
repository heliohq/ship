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

This is the most common default. The official installer does almost
everything for you.

```bash
# Pick the package manager from the lockfile
if [ -f pnpm-lock.yaml ]; then PM="pnpm"; PMX="pnpm dlx"
elif [ -f yarn.lock ];     then PM="yarn"; PMX="yarn dlx"
elif [ -f bun.lockb ];     then PM="bun";  PMX="bunx"
else                            PM="npm";  PMX="npx"
fi

# Install + download browsers + create config
$PMX create playwright@latest --quiet --ct=false --install-deps --lang=TypeScript --gha=false

# What this produces:
#   playwright.config.ts       — base config
#   tests/                     — directory for specs
#   tests-examples/            — examples (delete if you don't want them)
#   package.json scripts.test  — may or may not be added depending on prompts
```

If the interactive installer is problematic in a headless environment, do
it manually:

```bash
$PM add -D @playwright/test
$PMX playwright install --with-deps
```

Then create `playwright.config.ts`:

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

And add the npm script if missing:

```bash
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json','utf8'));
pkg.scripts = pkg.scripts || {};
if (!pkg.scripts['test:e2e']) pkg.scripts['test:e2e'] = 'playwright test';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"
```

Create the test directory so your first test has a home:

```bash
mkdir -p tests/e2e
```

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

Only use this path when the project already has Jest, Vitest, or node:test
wired up and the diff is backend-only.

```bash
$PM add -D supertest @types/supertest
```

Example test skeleton at `tests/e2e/api.spec.ts`:

```ts
import request from 'supertest';
import { app } from '../../src/app';

describe('POST /items', () => {
  it('creates an item', async () => {
    const res = await request(app).post('/items').send({ name: 'x' });
    expect(res.status).toBe(201);
    expect(res.body).toMatchObject({ name: 'x' });
  });
});
```

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
real browser is needed.

```bash
go get -u github.com/chromedp/chromedp
mkdir -p tests/e2e
```

Skeleton:

```go
package e2e

import (
    "context"
    "testing"
    "time"

    "github.com/chromedp/chromedp"
)

func TestLandingPage(t *testing.T) {
    ctx, cancel := chromedp.NewContext(context.Background())
    defer cancel()
    ctx, cancel = context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    var title string
    err := chromedp.Run(ctx,
        chromedp.Navigate("http://localhost:8080"),
        chromedp.Title(&title),
    )
    if err != nil || title == "" {
        t.Fatalf("navigation failed: %v title=%q", err, title)
    }
}
```

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
