# Setup Skill Rewrite — Design Spec

## Problem

The current `/setup` skill is a 730-line monolith that tries to do too much: empty repo scaffolding, tool installation, CI/CD generation, policy generation, AGENTS.md generation, and 4+ user decision points. This makes it slow, fragile, and overwhelming for non-SWE users.

## Goal

Rewrite `/setup` as a thin orchestrator (~120 lines) with optional modules in reference files. One command, one decision point, repo goes from bare to AI-ready with Ship enforcement active.

## Target Users

Includes non-SWE users who don't know what "ruff" or "eslint" means. They want "AI helps me code safely" — not tool selection menus.

## Core Principle

**Detect first, never assume.** Respect existing user configurations. Only recommend defaults when nothing exists.

---

## Architecture

```
skills/setup/
  SKILL.md                    (~120 lines, thin orchestrator)
  references/
    tooling.md                (install missing tools + update policy)
    ci.md                     (CI/CD + Dependabot + labeler)
    review.md                 (AI code review workflow)
    runtime-install-guide.md  (platform-specific install instructions)
  templates/
    ship.policy.json          (default policy template)
    agents-md.md              (AGENTS.md template)
    ci-node.yml               (GitHub Actions for Node)
    ci-python.yml             (GitHub Actions for Python)
    ci-go.yml                 (GitHub Actions for Go)
    dependabot.yml
    auto-merge-dependabot.yml
    labeler.yml
    labeler-workflow.yml
```

### Tier Mapping

| Tier | Phase 3 Core | tooling.md | ci.md | review.md |
|------|-------------|------------|-------|-----------|
| A) Full (recommended) | Yes | Yes | Yes | Yes |
| B) Basic | Yes | No | No | No |
| C) Custom | Yes | User picks | User picks | User picks |

---

## Phase 1: Detect (automatic, no user interaction)

### 1.1 Language + Package Manager Detection

Scan file markers, verify package managers are available:

| Language | File Markers | Package Manager Check |
|----------|-------------|----------------------|
| TypeScript/JS | `package.json`, `tsconfig.json` | `which npm` / `which yarn` / `which pnpm` |
| Python | `pyproject.toml`, `setup.py`, `requirements.txt` | `which pip` / `which uv` |
| Java | `pom.xml`, `build.gradle` | `which mvn` / `which gradle` |
| C# | `*.csproj`, `*.sln` | `which dotnet` |
| Go | `go.mod` | `which go` |
| Rust | `Cargo.toml` | `which cargo` |
| PHP | `composer.json` | `which composer` |
| Ruby | `Gemfile`, `*.gemspec` | `which bundle` / `which gem` |
| Kotlin | `build.gradle.kts`, `*.kt` | `which gradle` |
| Swift | `Package.swift`, `*.xcodeproj` | `which swift` |
| Dart/Flutter | `pubspec.yaml` | `which dart` / `which flutter` |
| Elixir | `mix.exs` | `which mix` |
| Scala | `build.sbt` | `which sbt` |
| C/C++ | `CMakeLists.txt`, `Makefile` | `which cmake` / `which make` |

### 1.2 Toolchain Detection

For each detected language, scan for **all mainstream tools** in each category. Use the first match found. Only mark as `missing` if no tool exists for that category.

**Detection order per language** (check all config file variants, use whichever the user has):

**Python:**
- Linter: `ruff.toml` / `pyproject.toml[ruff]` / `.flake8` / `setup.cfg[flake8]` / `.pylintrc` / `pyproject.toml[pylint]` → default: ruff
- Formatter: ruff format config / `.style.yapf` / `pyproject.toml[black]` / `setup.cfg[yapf]` → default: ruff format
- Type checker: `pyrightconfig.json` / `pyproject.toml[pyright]` / `mypy.ini` / `.mypy.ini` / `pyproject.toml[mypy]` → default: pyright
- Test runner: pytest config / `tests/` dir / `unittest` usage → default: pytest

**TypeScript/JS:**
- Linter: `eslint.config.*` / `.eslintrc.*` / `biome.json` → default: eslint
- Formatter: `.prettierrc*` / `package.json[prettier]` / `biome.json` / `dprint.json` → default: prettier
- Type checker: `tsconfig.json` with `strict: true` → default: tsc strict
- Test runner: vitest config / jest config / `*.test.*` files → default: vitest

**Go:**
- Linter: `.golangci.yml` / `.golangci.yaml` → default: golangci-lint
- Formatter: gofmt (built-in, always ready)
- Test runner: go test (built-in, always ready)

**Rust:**
- Linter: clippy (built-in, always ready)
- Formatter: rustfmt (built-in, always ready)
- Test runner: cargo test (built-in, always ready)

**Java:**
- Linter: `checkstyle.xml` / spotbugs config / `.editorconfig` → default: checkstyle
- Formatter: google-java-format config / `.editorconfig` → default: google-java-format
- Test runner: `src/test/` dir / junit config → default: maven test or gradle test

**C#:**
- Linter: dotnet analyzers (built-in, always ready)
- Formatter: dotnet format (built-in, always ready)
- Test runner: dotnet test (built-in, always ready)

**PHP:**
- Linter: `phpstan.neon` / `phpcs.xml` → default: phpstan
- Formatter: `.php-cs-fixer.php` / `.php-cs-fixer.dist.php` → default: php-cs-fixer
- Test runner: `phpunit.xml` / `phpunit.xml.dist` → default: phpunit

**Ruby:**
- Linter: `.rubocop.yml` → default: rubocop
- Formatter: rubocop (built-in with linter)
- Type checker: `sorbet/` dir / `.srb/` → default: none (optional)
- Test runner: `spec/` dir (rspec) / `test/` dir (minitest) → default: minitest

**Kotlin:**
- Linter: `.editorconfig[ktlint]` / `detekt.yml` → default: ktlint
- Formatter: ktlint (built-in with linter)
- Test runner: gradle test (built-in)

**Swift:**
- Linter: `.swiftlint.yml` → default: swiftlint
- Formatter: `.swiftformat` → default: swiftformat
- Test runner: swift test / XCTest (built-in)

**Dart/Flutter:**
- Linter: `analysis_options.yaml` (built-in dart analyze)
- Formatter: dart format (built-in, always ready)
- Test runner: dart test / flutter test (built-in)

**Elixir:**
- Linter: `.credo.exs` → default: credo
- Formatter: mix format (built-in, always ready)
- Type checker: dialyxir config → default: none (optional)
- Test runner: ExUnit (built-in, always ready)

**Scala:**
- Linter: `.scalafix.conf` / wartremover config → default: scalafix
- Formatter: `.scalafmt.conf` → default: scalafmt
- Test runner: scalatest / specs2 config → default: sbt test

**C/C++:**
- Linter: `.clang-tidy` → default: clang-tidy
- Formatter: `.clang-format` → default: clang-format
- Test runner: CMake test config / gtest → default: ctest

### Tool Status

Each tool gets one of three states:
- `ready` — config exists AND tool can execute
- `missing` — no config found for this category
- `broken` — config exists but tool fails to execute

Verification: run `<tool> --version` or equivalent. For tools that are built-in to the language runtime (gofmt, rustfmt, dart format, etc.), always mark as `ready` if the runtime exists.

**Handling `broken` tools:** Config exists but tool fails. Don't write to policy pre_commit (same as `missing`). Show as `△` in Phase 2 results with the error. In completion summary, list as warning: "fix manually, rerun /setup". The `tooling.md` module does NOT attempt to fix broken tools — only installs missing ones.

### 1.3 Existing Configuration Detection

```bash
# Ship configuration
.ship/ship.policy.json  → POLICY:exists
AGENTS.md / CLAUDE.md   → AGENTS:exists

# Git workflow
.gitignore              → GITIGNORE:exists
.github/pull_request_template.md → PR_TEMPLATE:exists

# CI/CD
.github/workflows/*.yml → CI:exists
.github/dependabot.yml  → DEPENDABOT:exists

# Existing AI instructions
.cursorrules / .cursor/rules/              → CURSOR:exists
.github/copilot-instructions.md            → COPILOT:exists
```

### 1.4 Output

Phase 1 produces an internal data structure (in agent working memory, no file written). All results feed into Phase 2 presentation and Phase 3 generation.

---

## Phase 2: Choose (1 user decision)

Single AskUserQuestion that:
1. Shows detection results (ready/missing/broken per tool)
2. Highlights which policy gates won't work due to missing tools
3. Presents tier choice (A/B/C)
4. Includes optional gotchas input at the bottom

### Tier A (Full)
User sees outcome-oriented description, not tool names:
> "Install missing tools, configure CI, generate security policy and AI handbook. AI auto-checks code quality, dangerous operations auto-blocked."

### Tier B (Basic)
> "Generate security policy and AI handbook. No tools installed, no CI. Existing tools included in quality checks."

### Tier C (Custom)
Expands to show modules (3-5) with checkboxes. Modules 1-2 (policy + AGENTS.md) always included. Also shows boundaries customization and gotchas input.

---

## Phase 3: Core (automatic)

### 3.1 Generate `.ship/ship.policy.json`

1. Read template `templates/ship.policy.json`
2. Fill `quality.pre_commit` with **only `ready` tools** from Phase 1
   - Use the actual detected tool and command, not hardcoded defaults
   - User has flake8 → write `flake8`, not `ruff check .`
3. Fill `quality.require_tests.source_patterns` and `test_patterns` per detected language
4. Append custom boundaries from Phase 2 (if C tier) to `no_access`
5. If `.ship/ship.policy.json` already exists → show diff, ask user to confirm

### 3.2 Generate `AGENTS.md`

1. Read template `templates/agents-md.md`
2. Fill:
   - **Commands**: actual detected commands (not recommendations)
   - **Repository Map**: detected languages + directory structure
   - **Code Style**: read actual code samples, only note deviations from language defaults
   - **Boundaries**: extracted from policy.json no_access/read_only
   - **Testing**: detected test runner + config
   - **Gotchas**: Phase 2 user input (if any)
3. Target: <200 lines
4. If `AGENTS.md` already exists → show diff, ask user to confirm

### 3.3 Auxiliary

- Create `.ship/audit/` directory
- Update `.gitignore`: add `.ship/tasks/` and `.ship/audit/` (NOT `.ship/` broadly — policy.json must be git-tracked)
- One atomic commit: `feat: generate ship policy and AGENTS.md`

### 3.4 User Review

Show generated AGENTS.md content, ask:
- A) Confirm, continue
- B) I want changes (tell me what to adjust)

---

## Phase 4: Modules (per tier selection)

### Execution Order
```
Tier A: tooling.md → ci.md → review.md
Tier B: skip, go to Done
Tier C: only selected modules in order
```

### `references/tooling.md` — Install Missing Tools

1. Iterate Phase 1 `missing` tools
2. Install at project level (never global, never sudo)
   - Python: `uv add --dev <pkg>` or `pip install <pkg>`
   - Node: `npm install -D <pkg>` (or yarn/pnpm equivalent)
   - Other languages: their respective package managers
3. Verify installation: run tool, confirm it works
4. **Closed loop: update policy.json `quality.pre_commit`** with newly installed tools via jq
5. Update AGENTS.md Commands table
6. Permission errors → report to user, don't sudo
7. Commit: `feat(tooling): install <tool1>, <tool2>`

### `references/ci.md` — CI/CD Configuration

1. Check if `.github/workflows/` already has CI → skip if yes
2. Read language-specific template (`templates/ci-*.yml`)
3. Replace template placeholders with **actual commands** from Phase 1/4a
4. Generate `dependabot.yml` (per detected ecosystem)
5. Generate `labeler.yml` (per actual directory structure)
6. Generate `auto-merge-dependabot.yml`
7. Commit: `chore: set up CI/CD`

### `references/review.md` — AI Code Review

1. Check for existing AI review config → skip if yes
2. Ask user which AI to use (1 AskUserQuestion):
   - A) Claude (Anthropic API key)
   - B) Codex (OpenAI API key)
   - C) Both
   - D) Skip
3. Generate `.github/workflows/ai-review.yml`
4. Commit: `chore: set up AI code review`

---

## Completion Summary

Show outcome-oriented summary:

```
Setup complete.

Security:
  ✓ ship.policy.json — dangerous operations auto-blocked
  ✓ Secret scanning — .env / API keys auto-blocked on write
  ✓ Audit log — all AI operations logged to .ship/audit/

Quality:
  ✓ <list of ready tools>
  ✓ Pre-commit checks: lint + test on every commit

CI/CD: (if tier A/C)
  ✓ GitHub Actions — lint + test + typecheck on every PR
  ✓ Dependabot — weekly dependency updates
  ✓ AI Code Review — PR auto-review

Documentation:
  ✓ AGENTS.md (<N> lines)

Next: /ship:auto "describe what you want to build"
```

Warnings for incomplete items:
```
⚠ pytest config exists but cannot execute — fix manually, rerun /setup
```

---

## What Setup Does NOT Do

- Does not scaffold empty repos (user should init their project first)
- Does not configure deployment (separate concern)
- Does not modify source code (only config files and documentation)
- Does not replace existing tool configurations
- Does not install tools globally or use sudo

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Missing tools in policy pre_commit | Don't write | Avoids false blocks on every commit |
| Tool installation | Auto-install in full tier | Non-SWE users don't know tool names |
| User decision points | 1 main + 1 for AGENTS.md review | Minimize interruptions |
| Existing configs | Detect and respect | Never overwrite user's tool choice |
| Tier system | Outcome-oriented (Full/Basic/Custom) | Non-SWE users choose outcomes, not tools |
| Boundaries question | Only in Custom tier | Defaults cover 90% of cases |
| Gotchas | Optional input in Phase 2 | Available but not forced |
| Empty repo scaffolding | Removed | Not setup's responsibility |
| Deploy config | Removed | Separate skill concern |

---

## Removed From Current Setup

- Phase 0: Empty repo detection + scaffolding
- Phase 4 Q2: Deploy information question
- Phase 4 Q4: AI review as separate question (moved to module)
- 4 separate AskUserQuestion calls → merged into 1
- Inline tool installation logic → moved to references/tooling.md
- Inline CI/CD generation logic → moved to references/ci.md
- Inline AI review logic → moved to references/review.md

## Files Changed

- `skills/setup/SKILL.md` — complete rewrite (~120 lines)
- `skills/setup/references/tooling.md` — new file
- `skills/setup/references/ci.md` — new file
- `skills/setup/references/review.md` — new file
- `skills/setup/references/runtime-install-guide.md` — keep as-is
- `skills/setup/templates/*` — keep all as-is
