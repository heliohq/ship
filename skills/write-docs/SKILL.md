---
name: write-docs
description: >
  Create or update structured docs under docs/ with frontmatter, numbering,
  lifecycle status, and index regeneration — guides, references,
  troubleshooting, decisions. Also the home of system-design thinking:
  architecture docs, ADRs, API/data-model decisions, trade-off analysis
  ("design this system", "trade-offs for X", "write an ADR"). Not visual
  design (/ship:visual-design) or implementation planning (/ship:design).
---

# Documentation Standard

All structured docs live under `docs/`. Each subdirectory is a category (e.g., `docs/design/`, `docs/guides/`, `docs/troubleshooting/`). Follow this standard when creating new docs or modifying existing ones.

## Architecture Thinking (before a design doc)

For system-design decisions — architecture, ADRs, API/data-model choices,
service boundaries — do the thinking before the writing. The lenses below
apply to any system: a service, a CLI, a frontend, a data pipeline, an
agent runtime. Scale the depth to the decision — a single component with
clear constraints needs the frame, a contract sketch, and trade-offs; a
new system with unknowns needs every lens. Skipping a lens is a judgment
call you record in the doc ("no trust boundary crossed — internal tool,
single user"), never a silent omission.

The quality bar for every lens: statements someone could prove wrong —
named numbers, named failure behaviors, named rejected alternatives.
Virtue words ("scalable", "robust", "flexible") with no test attached
are filler.

**Method — walk the lenses as a self-interview.** Interview yourself
relentlessly about every aspect of the design until no unresolved
question remains — the lenses below are the branches of the tree. Take
questions one at a time, in dependency order: resolve a decision before
opening the ones that build on it (storage before schema, contract
before internals) — an answer stacked on an unresolved dependency is a
guess, and opening many branches at once produces shallow parallel
guesses. For each question, state your recommended answer, then resolve
it with the strongest means available:

- **Codebase evidence** — if exploring the repo can answer it, explore;
  most questions die here. Never ask anyone what the code already says.
- **Arithmetic** — if a number decides it, compute the number (lens 2).
- **Judgment** — adopt your recommended answer and record it under
  Assumptions with what breaks if it's wrong.

Do not interview the user. Questions only they could answer (product
intent, priorities, external constraints) do not become blocking
prompts — adopt the recommended answer, mark the assumption, and
surface that short list when you present the doc. The Q&A itself is
scaffolding, not deliverable: the doc records the decisions it
produced.

1. **Frame: goals, non-goals, requirements.** Functional capabilities;
   the non-functional numbers that bind the design (latency, throughput,
   availability, consistency, data volume); real constraints (existing
   stack, team, timeline, compliance, backward compatibility). Write
   explicit non-goals — a later reader must be able to tell deliberate
   exclusion from oversight. Never conflate "what we want" with "what
   exists": state the gap.
2. **Do the arithmetic.** Back-of-envelope estimates for the numbers
   that drive the shape: request rates, data growth, fan-out, budget
   per hop. Show the math in the doc — a computed number is falsifiable;
   "should scale fine" is not. Where a number is unknown, state the
   assumption and what breaks if it is 10× off.
3. **The boring option first.** Before designing anything new: does an
   existing utility, library, managed service, or simpler shape already
   cover this? Classify the decision — two-way door (reversible: pick
   the simple option fast and note the revisit trigger) or one-way door
   (hard to undo: full rigor). Most decisions are two-way doors;
   treating them all as one-way is how designs bloat.
4. **Components and contracts.** Responsibilities, data flow, data
   model, storage choices driven by access patterns. Define the
   contracts — interfaces, protocols, schemas — before the internals;
   they are what other people and later phases build against. Verify
   assumptions against the actual codebase, not memory.
5. **Failure modes.** For each component and dependency: what happens
   when it is down, slow, or returning garbage? What do concurrent
   access, retries, and duplicate delivery do? Name the blast radius
   and the degraded behavior a user sees ("if the queue dies, writes
   buffer locally for 10 minutes, then reject with a clear error" —
   never "handles failures gracefully"). Idempotency and
   partial-failure recovery are design decisions, not implementation
   details.
6. **Operability and rollout.** How does the system get from the
   current state to this design — the migration path, and whether it
   must be zero-downtime? What is the rollback story? Which metric or
   log line says it is working, and which signal says it is not? What
   does it cost to run? A design you cannot observe or roll back is
   not finished.
7. **Security and trust boundaries.** Where does data cross a trust
   line? AuthN/authZ at each boundary, secrets and credential handling,
   which data is sensitive and who may see it. One sentence when
   nothing crosses; a real section when anything does.
8. **Trade-off analysis.** For each major decision: at least two
   alternatives considered, concrete pros/cons, the deciding factor,
   and what you are giving up. A design with no rejected alternatives
   has not been designed.
9. **Revisit triggers.** Flag decisions that will not age well, with
   their trigger: load-dependent ("rethink at 10k rps"), time-bound
   ("chose X because Y isn't ready"), assumption-sensitive
   ("multi-region breaks this"). These are honest engineering, not
   weaknesses.

**Red-team before writing it up.** Re-read the design as a skeptical
staff engineer: what is the first thing that breaks in production?
Which number is least defensible? Which alternative was dismissed too
fast? If an attack lands, fix the design, not the wording. For
high-stakes or contested decisions, dispatch a fresh peer challenge
with only the draft (see `../.shared/runtime-resolution.md`) — the same
adversarial pattern /ship:design applies to specs.

Then write it as a design doc per this standard — Boundaries required,
Trade-offs and Assumptions recommended, body shape under Category
Conventions below. If the user only wants to think it through (no doc
yet), the analysis itself is the deliverable — offer the doc as the
follow-up.

## Red Flag

**Never:**
- Lead with analysis instead of the decision
- Include implementation details that belong in code
- Mix languages within one document
- Silently delete history — mark superseded sections, don't erase them
- Create a doc without adding it to the docs index
- Mark a doc as `current` without verifying claims against code
- Skip the Boundaries section in design docs — it's the core anti-drift mechanism
- Ship a design doc with zero numbers and zero rejected alternatives —
  that's a description, not a design
- Use a duplicate number within a category

## Frontmatter (Required)

Every managed doc MUST start with YAML frontmatter:

```yaml
---
title: "Human-readable title"
description: "One sentence, under 120 chars — enough for an AI to decide whether to read the doc."
category: "design"
number: "002"
status: current | partially-outdated | superseded | draft | not-implemented
services: [scripts, hooks]  # only when specific dirs/components are affected
superseded_by: "034"        # only when status is superseded
related: ["design/001", "guides/003"]  # category-qualified when cross-category
last_modified: "2026-04-13"
---
```

### Required Fields

- **title**: Match the `# heading` below the frontmatter. Use quotes if it contains special chars.
- **description**: One concise sentence for the docs index — write it for an AI that needs to decide "should I read this doc?" without opening it. Max 120 chars.
- **category**: Matches the subdirectory name (e.g., `"design"`, `"guides"`, `"troubleshooting"`). Must be one of the subdirectories under `docs/`.
- **number**: Unique within its category. Zero-padded 3 digits (e.g., `"002"`, `"029"`). Used for file naming (`029-topic.md`) and cross-referencing.
- **status**: One of the 5 allowed values. See Status Lifecycle below.
- **last_modified**: ISO date (`YYYY-MM-DD`) when the doc was last updated. Must be updated on every edit.

### Conditional Fields

- **services**: Array of affected directories or components. Helps agents match "I'm editing X, does a doc cover this?"
- **superseded_by**: Required when status is `superseded`. Points to the replacement doc as `category/number`.
- **related**: Include when related docs exist. Array of `category/number` references for navigation.

### Docs Index

After creating or updating a doc, regenerate the index:

```bash
# SKILL_DIR = this skill's base directory (announced as "Base directory
# for this skill" when the skill loaded) — your cwd is the user's repo,
# so a bare relative path will not find the plugin's scripts.
bash "$SKILL_DIR/../../scripts/generate-docs-index.sh"
```

This produces `docs/DOCS_INDEX.md` — a compact table (Category, #, Status, Name, Description, Last Modified, Path) that agents can read on demand to see what docs exist without opening each one. Superseded docs are excluded from the index.

## Status Lifecycle

```
draft → current → partially-outdated → superseded
                ↘ not-implemented (if design was never built)
```

| Status | Meaning |
|--------|---------|
| `draft` | Proposed but not yet approved or implemented |
| `current` | Content matches production code |
| `partially-outdated` | Core content still applies but some details have drifted from code |
| `superseded` | Replaced by another doc — must set `superseded_by` |
| `not-implemented` | Approved but never built |

When changing status, also update `last_modified` to today's date.

## Numbering

- Next available number: check `ls docs/<category>/ | sort` and pick the next zero-padded 3-digit number (e.g., `003`, `010`).
- No duplicate numbers within a category. Each top-level doc or directory within a category gets a unique number.
- Sub-documents inside a directory (e.g., `design/014-credentials-vault/plan-1-vault-service.md`) share the parent number.

## File Naming

```
docs/<category>/{number}-{kebab-case-topic}.md
```

Examples:
- `docs/design/029-prototype-v3-web-migration.md`
- `docs/guides/003-getting-started.md`
- `docs/troubleshooting/001-auth-failures.md`

## Document Structure

```markdown
---
(frontmatter)
---

# {Number} — {Title}

## Status

{Status explanation with context — why it has this status, what changed}

## Summary

{2-3 sentences: what problem this solves and the key content}

## (Body sections — flexible per topic and category)

## References

- Related docs, external links, prior art
```

### Writing Rules

- Lead with the decision or answer, not the analysis. Readers want to know "what" before "why."
- Use concrete file paths, struct names, and API endpoints — not abstractions.
- If the doc is in Chinese, keep it in Chinese. If in English, keep it in English. Don't mix.
- Mark superseded sections inline with strikethrough or a note, don't silently delete history.
- When content changes, update the existing doc rather than creating a new one — unless the change is a complete replacement (then supersede).

## Category Conventions

Each category has its own natural structure. The frontmatter and status lifecycle are universal; the body structure varies by category.

### design (architectural decisions)
- **Boundaries section required** — the core anti-drift mechanism
- **Recommended body shape** (adapt, don't pad — a small ADR needs only
  Context, Decision, Trade-offs, Revisit triggers):
  Context → Goals / Non-goals → Requirements & numbers → Design
  (components, data model, contracts) → Failure modes → Rollout &
  operations → Security → Alternatives considered → Assumptions →
  Revisit triggers
- **Trade-offs section recommended** — what alternatives were considered, what was given up, and why this choice won
- **Assumptions section recommended** — state what must be true for this design to hold (e.g., "assumes < 10k users", "assumes single-region"). When assumptions change, the doc is stale.
- Lead with the decision, not the analysis
- Verify claims against code before marking `current`

### guide (how-to guides)
- Step-by-step structure with numbered steps
- Include prerequisites and expected outcomes
- Code examples should be copy-pasteable

### troubleshooting (debug playbooks)
- Symptom → Diagnosis → Fix structure
- Include exact error messages for searchability
- Link to related design docs for context

### reference (API docs, schemas, config reference)
- Organized by entity or endpoint
- Include examples for every parameter
- Version-sensitive — note which versions apply

### Other categories
- Any subdirectory under `docs/` becomes a category
- Follow the universal frontmatter and naming rules
- Adapt the body structure to what serves the category best

## Cross-References

- Reference docs in the same category by number: "see 023-agent-broker-architecture"
- Reference docs in other categories with category prefix: "see `guides/003-getting-started`"
- When renaming/renumbering, update ALL references. Use: `grep -r "old-name" docs/`

## Verification

Before marking a doc as `current`, verify key claims against code:
- Do referenced file paths exist?
- Do referenced struct/function names exist?
- Do referenced API endpoints exist?
- Does the described architecture match the actual service boundaries?

Update `last_modified` when you complete verification.

## Execution Handoff

After writing or updating a doc, regenerate the index and output the report card (read `skills/.shared/report-card.md` for the standard format):

```
## [Write Docs] Report Card

| Field | Value |
|-------|-------|
| Status | <DONE / BLOCKED> |
| Summary | <category/number: doc title — created / updated / superseded> |

### Metrics
| Metric | Value |
|--------|-------|
| Docs created | <N> |
| Docs updated | <N> |
| Index regenerated | yes / no |

### Artifacts
| File | Purpose |
|------|---------|
| docs/<category>/<number>-<topic>.md | The doc |
| docs/DOCS_INDEX.md | Regenerated index |

### Next Steps
1. **Review the doc** — read it and verify claims against code
2. **Plan implementation** — /ship:design to turn the decision into executable stories
3. **Ship it** — /ship:handoff to create a PR with the doc changes
```
