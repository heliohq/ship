# Refactor Skill Redesign: Rescue-Grade Contract Generator

## Problem

The current refactor skill (v0.4.0) is built for professional SDEs who can articulate structural pain. Ship's primary persona is vibe coders — people using AI to build fast whose code works but has no intentional architecture. When they say "my code is a mess", the skill asks "what specific task felt harder than it should have been?" — a question they can't answer.

The old detailed workflow (~800 lines) has the right safety instincts (characterization tests, small slices, behavior preservation) but is architecturally wrong for Ship: it creates a second pipeline that duplicates auto/plan/dev/review/verify/QA.

## Goal

Redesign the refactor skill as a **refactor contract generator** that:
1. Auto-diagnoses structural problems from code signals (no user input required for rescue mode)
2. Proposes concrete target structure (file/module map, not abstract crack statements)
3. Classifies risk and declares safety requirements
4. Hands off to the existing auto pipeline (architecture preserved)

The execution pipeline (auto/plan/dev) owns safety enforcement. Refactor declares the contract.

## Target Persona

Vibe coders: non-engineers or junior devs using AI to build fast. Typical situation:
- 1 file with 2000+ lines
- Copy-pasted functions everywhere
- No clear module boundaries, no tests
- User says: "my code is a mess, fix it"

Must also work for professional SDEs who give clear directives.

## Design

### Input Classification

Replace `directive / area / pain / vague` with:

| Type | Signal | Example | Action |
|------|--------|---------|--------|
| **Directive** | Clear structural action | "extract auth into its own file" | Validate, spec |
| **Feature-prep** | Refactor to enable a next feature | "I need multi-tenant but DB is hardcoded everywhere" | Trace what blocks the feature, spec |
| **Rescue** | Code is a mess, no specific pain | "this file is too big", "my code is a mess" | AI auto-diagnoses from code signals, proposes target, spec |
| **Not-structural** | Pain isn't structural | "this function is slow" | Redirect to auto or debug |

Key change: **rescue** replaces vague. Instead of asking questions the user can't answer, the AI independently reads the code and identifies problems.

### Rescue Mode: Auto-Diagnosis

When classified as rescue, the skill scans for structural signals without requiring user input:

1. **God files** — files >300 lines with mixed concerns (UI + logic + data + config)
2. **Duplication clusters** — similar code blocks repeated across files
3. **Import fan-in/fan-out** — files that everything depends on (fragile core) or that depend on everything (god objects)
4. **Mixed responsibilities** — a single file/function doing unrelated things
5. **Global/shared mutable state** — state that's read/written from many places without clear ownership
6. **Dead or unreachable code** — exports never imported, functions never called

Signals are ranked by impact: which, if resolved, would make the most future changes easier?

### Feature-Prep Mode

When classified as feature-prep:

1. Understand the target feature from user description
2. Trace what current structure blocks or complicates that feature
3. Diagnose the minimal structural change needed to unblock the feature
4. Spec the refactor as a prerequisite, not the feature itself

### Refactor Contract (spec.md format)

```markdown
## Goal
[One sentence — what this refactor achieves]

## Critical Behaviors to Preserve
- [Enumerated from reading actual code — user-facing behaviors that must not break]
- [If no tests exist, state explicitly: "No test suite — plan must add characterization tests first"]

## Risk Tier
[low | medium | high]
[Rationale: what makes this risky or safe]

## Primary Contradiction
[What structural boundary doesn't match how the code is actually used/changed]

## Structural Signals Found
- [e.g., God file: app.tsx (1847 lines, mixes UI + API calls + state management + routing)]
- [e.g., Duplication: auth check logic copied in 5 route handlers]
- [e.g., Fan-in: utils.ts imported by 23 files, contains unrelated functions]

## Target Module Map
| Module | Owns | Depends On |
|--------|------|------------|
| page.tsx | UI rendering, layout | useFoo, fooService |
| useFoo.ts | State management hook | fooService |
| fooService.ts | API calls, data transforms | fooSchema |
| fooSchema.ts | Types, validation | (none) |

## What Gets Easier After
- [e.g., Adding a new page: create page + hook, service already exists]
- [e.g., Changing API format: only touch fooService, not every component]

## Migration Constraints
- [e.g., No test suite — plan must generate characterization tests before structural edits]
- [e.g., Single file — must be split incrementally, not rewritten at once]
- [e.g., High risk — plan should use smallest possible slices with validation after each]

## Non-goals
- No new features or behavior changes
- No cosmetic cleanup outside the diagnosed area
```

### Boundary Test for Proposed Modules

Every proposed module boundary must pass this test (adapted from the old workflow's "fake abstraction test"):

1. Does it correspond to a distinct reason-to-change?
2. Can someone understand what it does without reading its internals?
3. Does it reduce the number of files touched for the next likely change?

If a proposed boundary is just "forwarding complexity elsewhere", don't propose it.

### What Stays the Same

- Handoff to auto after spec (architecture preserved)
- Directive path (works well already)
- `[Refactor]` progress reporting prefix
- Task directory structure (`.ship/tasks/<id>/plan/spec.md`)
- Quality gates (classify -> diagnose -> spec -> auto)

### What Gets Removed

- `pain` and `vague` classification types (merged into `rescue`)
- Requirement for user to supply a concrete pain instance
- Dependency on useful git history (still used when available, not required)
- Counterfactual validation requirement (kept as optional for area/directive, removed as required gate)

### Future Pipeline Changes (separate PR)

These are NOT part of the refactor skill itself but are noted for future work:

- `plan` should recognize "No test suite" in migration constraints and generate characterization-test-first stories
- `dev` should enforce one-slice-at-a-time for medium/high risk tiers
- `verify` should check each item in "Critical Behaviors to Preserve"
- `auto` should recognize refactor contracts and apply appropriate safety gates

## Acceptance Criteria

1. Vibe coder says "my code is a mess" → skill classifies as rescue → auto-scans code → proposes concrete target skeleton → writes refactor contract → hands off to auto
2. SDE says "extract auth from UserService" → skill classifies as directive → validates → writes spec → hands off (same as today, slightly updated spec format)
3. User says "I need to add payments but the code won't support it" → skill classifies as feature-prep → traces what blocks payments → specs the minimal refactor
4. Spec includes risk tier, critical behaviors to preserve, and concrete module map (not just abstract diagnosis)
5. No execution in the refactor skill — auto/plan/dev handle all implementation

## Non-goals

- Changing the auto/plan/dev pipeline (future PR)
- Adding characterization test generation to refactor (that's plan/dev's job)
- Supporting multi-repo refactors
- Replacing the entire skill from scratch (evolve the existing structure)
