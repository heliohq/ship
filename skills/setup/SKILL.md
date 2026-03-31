---
name: setup
version: 1.1.0
description: >
  Bootstrap a repo for AI-ready development with Ship enforcement.
  Detects languages and tooling across 14 languages, generates
  AI-driven coding convention rules (.ship/rules/) and AI handbook
  (AGENTS.md). Optional modules
  install missing tools, configure CI/CD, and set up AI code review.
  Use when: setup, init, bootstrap, make repo AI-ready.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# Ship: Setup

One command. Repo goes from bare to AI-ready with Ship enforcement
active. Idempotent.

## Principal Contradiction

**Unconstrained AI's destructive potential vs constrained AI's productivity.**

Without a harness, the more capable the AI, the greater the risk —
it can modify secrets, skip quality checks, rewrite CI pipelines,
and produce code that ignores project conventions. Setup builds the
AI Harness: the constraint framework that channels AI capability into
safe, productive work. Policy is not the opposite of AI freedom — it
is the guarantee of AI trustworthiness.

## Core Principle

```
DISCIPLINE IS THE GUARANTEE OF FREEDOM.
DETECT FIRST, NEVER ASSUME, RESPECT EXISTING CONFIG.
```

Setup never invents a default stack when a repo already picked one.
It detects what exists, lets the user choose the level of enforcement,
and generates the harness accordingly.

## Process Flow

```dot
digraph setup {
    rankdir=TB;

    "Start" [shape=doublecircle];
    "Detect languages, tools, existing config" [shape=box];
    "Present detection results to user" [shape=box];
    "User chooses tier (Full / Basic / Custom)" [shape=diamond];
    "Run selected modules (tools, CI, review)" [shape=box];
    "Generate AGENTS.md" [shape=box];
    "Generate .gitignore + auxiliary" [shape=box];
    "AI Rule Discovery + Generate rules" [shape=box];
    "Commit all core files" [shape=box];
    "STOP: git not available" [shape=octagon, style=filled, fillcolor=red, fontcolor=white];
    "Done" [shape=doublecircle];

    "Start" -> "Detect languages, tools, existing config";
    "Detect languages, tools, existing config" -> "Present detection results to user";
    "Present detection results to user" -> "User chooses tier (Full / Basic / Custom)";
    "User chooses tier (Full / Basic / Custom)" -> "Run selected modules (tools, CI, review)" [label="Full or Custom"];
    "User chooses tier (Full / Basic / Custom)" -> "Generate AGENTS.md" [label="Basic"];
    "Run selected modules (tools, CI, review)" -> "Generate AGENTS.md";
    "Generate AGENTS.md" -> "Generate .gitignore + auxiliary";
    "Generate .gitignore + auxiliary" -> "AI Rule Discovery + Generate rules";
    "AI Rule Discovery + Generate rules" -> "Commit all core files";
    "Commit all core files" -> "Done";
    "Start" -> "STOP: git not available" [label="no git"];
}
```

## Roles

| Role | Who | Why |
|------|-----|-----|
| Detector + generator | **You (Claude)** | Read the repo, generate config files |
| Decision maker | **User** | Choose tier and confirm discovered rules |

No Codex in setup. This is environment configuration, not code
implementation. There is no "correctness" to adversarially verify —
the harness either works or it doesn't.

## Hard Rules

1. Detect first, never assume. Never invent a default stack.
2. Keep user interaction to two gates: tier choice and rule confirmation. Do not ask repeatedly outside those gates.
3. Execute ONLY the modules the user selected. This is a gate.
4. Harness rules are generated LAST — rule files and hooks activate enforcement immediately.
5. Respect existing config. Show diff and ask before replacing.

## Quality Gates

| Gate | Condition | Fail action |
|------|-----------|-------------|
| Pre-flight → Detect | git available, cwd is repo (or init) | Stop with message |
| Detect → Choose | At least one language detected | AskUserQuestion for manual config |
| Choose → Modules | User made a tier selection | Wait for response |
| Modules → Core | Selected modules committed | Verify commits exist |
| Core → Done | `.ship/rules/rules.json` + `AGENTS.md` exist and non-empty | Re-generate |

---

## Phase 1: Detect (automatic)

No user interaction in this phase.

### Step A: Pre-flight

- Check `git` is available. If missing, stop.
- Check whether cwd is a git repo with `git rev-parse --is-inside-work-tree`.
- If not a repo, run `git init`.
- Record whether the repo was newly initialized.

### Step B: Language + Package Manager

Scan repo files, then verify package manager / build tool exists on PATH.

| Language | File markers | Package manager / tool check |
|---|---|---|
| TypeScript / JavaScript | `package.json`, `tsconfig.json`, `*.ts`, `*.tsx`, `*.js`, `*.jsx` | `npm`, `pnpm`, `yarn`, `bun` |
| Python | `pyproject.toml`, `requirements*.txt`, `setup.py`, `*.py` | `uv`, `poetry`, `pip`, `pip3` |
| Java | `pom.xml`, `build.gradle*`, `*.java` | `mvn`, `gradle` |
| C# | `*.csproj`, `*.sln`, `*.cs` | `dotnet` |
| Go | `go.mod`, `*.go` | `go` |
| Rust | `Cargo.toml`, `*.rs` | `cargo` |
| PHP | `composer.json`, `*.php` | `composer` |
| Ruby | `Gemfile`, `*.rb` | `bundle`, `gem` |
| Kotlin | `build.gradle*`, `settings.gradle*`, `*.kt` | `gradle`, `mvn` |
| Swift | `Package.swift`, `*.swift`, `*.xcodeproj` | `swift`, `xcodebuild` |
| Dart / Flutter | `pubspec.yaml`, `*.dart` | `dart`, `flutter` |
| Elixir | `mix.exs`, `*.ex`, `*.exs` | `mix` |
| Scala | `build.sbt`, `*.scala` | `sbt`, `mill` |
| C / C++ | `CMakeLists.txt`, `Makefile`, `*.c`, `*.cc`, `*.cpp`, `*.h`, `*.hpp` | `cmake`, `make`, detected compiler |

### Step C: Toolchain Detection

For each detected language, scan all mainstream tools by category:
linter, formatter, type checker, test runner.

Status per tool:
- `ready`: executable and config are usable as-is
- `missing`: repo has no configured tool for that category
- `broken`: config references unavailable or misconfigured tool

Reference: `references/toolchain-matrix.md` for the full detection matrix.

### Step D: Existing Configuration

Check and store:
- `.ship/ship.policy.json`
- `AGENTS.md` and `CLAUDE.md`
- `.gitignore`
- `.github/workflows/*.yml`
- `.github/dependabot.yml`

## Phase 2: Choose (1 user decision)

Ask exactly one `AskUserQuestion` after detection. The prompt must show:

- Detection results by language and tool, including `ready` / `missing` / `broken`
- Which Ship enforcement gates will not work because required tools are missing or broken
- Three tiers:

| Tier | Selection |
|---|---|
| A | `Full setup (recommended)` — install missing tools, configure CI, generate rules + AGENTS.md |
| B | `Basic setup` — generate rules + AGENTS.md only, use repo's current toolchain |
| C | `Custom` — choose modules: `1.[x] AI-driven rules`, `2.[x] AI handbook`, `3.[ ] Install missing tools`, `4.[ ] CI/CD`, `5.[ ] AI Code Review`. Include custom boundaries input |

At the bottom include:
- `Any special notes AI should know about this project? (optional, Enter to skip)`

## Phase 3: Modules (per tier)

**Why modules run BEFORE rules:** structural enforcement becomes active
when setup writes the generated rules and registers hooks in
`.claude/settings.json`. If CI/CD files or tooling configs are written
after that point, the new checks can block setup from completing.
Therefore: write all files first, generate the rules last.

Tier A runs all modules. Tier B skips all modules. Tier C runs only
checked modules.

**Hard rule:** Execute ONLY the modules the user selected. Never run
a module the user did not check.

| Module | Reference |
|---|---|
| Install Tools | `references/tooling.md` |
| CI/CD | `references/ci.md` |
| AI Code Review | `references/review.md` |

After each module, commit atomically:
```
git add <changed files>
git commit -m "<conventional commit message>"
```

## Phase 4: Core — generate rules and AGENTS.md last

Always run this phase for every tier. This is the final phase because
generated rules and registered hooks activate enforcement immediately.

### Step A: Generate AGENTS.md

- Read `templates/agents-md.md`.
- Fill commands with actual detected (and newly installed) tools.
- Fill repo map, code style, boundaries, testing notes from repo inspection.
- Keep under 200 lines.
- If `AGENTS.md` or `CLAUDE.md` already exists, show diff and ask before replacing.

### Step B: Auxiliary

- Create `.ship/audit/`.
- Update `.gitignore` to include `.ship/tasks/` and `.ship/audit/`.
- Add language-specific ignores if not already present.

### Step C: Migrate existing policy (if present)

If `.ship/ship.policy.json` exists:
- Read `workflow.phases` from it.
- Preserve these values for the new `rules.json`.
- Inform user: "Found existing ship.policy.json. Workflow phase config will be migrated to rules.json. The old file is no longer used and can be safely deleted."

### Step D: AI Rule Discovery

This is the core of Harness v2. Instead of reading a template, analyze
the project.

#### Step D.1: Infer from code

- Scan directory structure for layering patterns (if any exist).
- Analyze import/require graphs for dependency boundaries.
- Sample error handling, validation, logging patterns across files.
- Detect naming conventions (variables, files, functions).
- Identify security-sensitive patterns (credential files, env usage).
- Check existing linter configs for implicit conventions.
- Assess confidence: intentional convention vs coincidence.

#### Step D.2: Supplement from documentation

- Read `CONTRIBUTING.md`, `STYLE_GUIDE.md`, `ARCHITECTURE.md` if they exist.
- Extract conventions from linter configs (`.eslintrc`, `ruff.toml`, `tsconfig.json`).
- Read `CLAUDE.md` / `AGENTS.md` for coded behavioral rules.

#### Step D.3: Present to user for confirmation

Present discovered rules with evidence and confidence:

```text
Discovered coding conventions. Confirm which to enforce:

Structural rules (deterministic check, deny on violation):
  ✓ [1] No .env file access (detected: .env* in .gitignore)
  ✓ [2] bin/*.sh must use set -u (detected: 4/4 scripts comply)

Semantic rules (AI-judged, feedback on violation):
  ✓ [3] Errors wrapped with AppError (detected: 12/15 files)
  ✓ [4] API handlers validate input first (detected: 8/8 handlers)

Toggle numbers to enable/disable, describe additional rules, or "done".
```

Do NOT use templates. Do NOT pre-populate rules. Every rule comes from analysis.

### Step E: Generate rule files

After user confirms:
- `.ship/rules/rules.json` — index with structural, semantic, and workflow sections; preserve migrated `workflow.phases` when present.
- `.ship/rules/structural/*.sh` — check scripts (you write these based on analysis).
- `.ship/rules/semantic/*.md` — convention docs with good/bad examples.
- `.ship/rules/enforce-structural.sh` — router script.
- Use `jq` for all JSON manipulation.

### Step F: Register hooks

Merge two hook entries into `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "command",
          "command": "bash .ship/rules/enforce-structural.sh",
          "statusMessage": "Checking structural rules..."
        }]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [{
          "type": "agent",
          "prompt": "You are a code convention enforcer. Read .ship/rules/rules.json to find all enabled semantic rules. For each applicable rule (check scope against the file being written), read the rule's .md file from .ship/rules/semantic/. Then verify the code in $ARGUMENTS follows those conventions. If violations found, return JSON with hookSpecificOutput.additionalContext describing each violation and how to fix it. If no violations, return nothing.",
          "model": "claude-haiku-4-5-20251001",
          "statusMessage": "Reviewing coding conventions..."
        }]
      }
    ]
  }
}
```

If `.claude/settings.json` already exists, merge hooks and preserve existing entries.

### Step G: Optionally generate audit hook

If the project would benefit from audit logging (enterprise,
compliance-sensitive), add a `PostToolUse` hook calling
`bash bin/audit-logger.sh`.

### Step H: Commit

```
git add AGENTS.md .ship/ .claude/settings.json .gitignore
git commit -m "feat: generate harness rules and AGENTS.md"
```

---

## Artifacts

```text
.ship/
  rules/
    rules.json             — structural, semantic, and workflow rule index
    enforce-structural.sh  — structural rule router
    structural/            — generated deterministic check scripts
    semantic/              — generated convention docs
  audit/             — audit log directory
  tasks/             — task artifacts (gitignored)
.claude/
  settings.json      — merged hook registration
AGENTS.md            — AI handbook for this repo
.gitignore           — updated with Ship + language ignores
.github/workflows/   — CI/CD (if module selected)
```

## Reference Files

- `references/toolchain-matrix.md` — full detection matrix for 14 languages
- `references/tooling.md` — tool installation instructions per language
- `references/ci.md` — GitHub Actions CI/CD generation
- `references/review.md` — AI code review workflow setup
- `references/runtime-install-guide.md` — platform-specific runtime installation
- `templates/agents-md.md` — AGENTS.md generation template

## Completion

End with an outcome-oriented summary:

- `Security`: structural and semantic rules generated, hooks active, audit path ready
- `Quality`: detected checks enforced, warnings for anything still missing
- `CI/CD`: include only if configured
- `Documentation`: AGENTS.md generated or updated
- Next step: `/ship:auto`

## What Setup Does NOT Do

- Scaffold empty repos beyond `git init`
- Configure deployment or hosting
- Generate rule templates — all rules are discovered from project code
- Replace existing tool configs because Ship prefers a different stack
- Install global packages or use `sudo`

<Bad>
- Assuming a language or tool without detecting it
- Installing tools the user didn't select (tier gate violation)
- Generating rules before modules are written (blocks own setup)
- Replacing existing AGENTS.md or CLAUDE.md without showing diff
- Running modules for Tier B (Basic = rules + AGENTS.md only)
- Asking the user repeated questions outside the tier choice and rule confirmation gates
- Using sudo or installing global packages
</Bad>
