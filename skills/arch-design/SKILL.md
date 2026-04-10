---
name: arch-design
description: >
  Use when creating, editing, or reviewing architectural design docs under docs/design/ —
  enforces frontmatter format, numbering, status lifecycle, and writing conventions. Use
  when: "write a design doc", "create an ADR", "document this decision", "architecture
  doc", "design document", or when capturing engineering decisions, trade-offs, or system
  design rationale. Note: this is for engineering/architecture decisions, NOT visual
  design (use /ship:visual-design for that) or implementation planning (use /ship:design
  for that).
---

# Design Document Standard

All design documents live under `docs/design/`. Follow this standard when creating new docs or modifying existing ones.

## Red Flag

**Never:**
- Lead with analysis instead of the decision
- Include implementation details that belong in code
- Mix languages within one document
- Silently delete history — mark superseded sections, don't erase them
- Create a design doc without adding it to the docs index
- Mark a doc as `current` without verifying claims against code
- Skip the Boundaries section — it's the core anti-drift mechanism

## Frontmatter (Required)

Every design doc MUST start with YAML frontmatter:

```yaml
---
title: "Human-readable title"
description: "One sentence, under 120 chars — enough for an AI to decide whether to read the doc."
number: "029"
status: current | partially-outdated | superseded | draft | not-implemented
services: [scripts, hooks]  # only when specific dirs/components are affected
superseded_by: "034"        # only when status is superseded
related: ["001", "023"]     # only when related docs exist
last_modified: "2026-04-02"
---
```

### Required Fields

- **title**: Match the `# heading` below the frontmatter. Use quotes if it contains special chars.
- **description**: One concise sentence. This gets injected into session context as an index — write it for an AI that needs to decide "should I read this doc?" without opening it. Max 120 chars.
- **number**: Unique across `docs/design/`. Zero-padded 3 digits (e.g., `"002"`, `"029"`). Used for file naming (`029-topic.md`) and cross-referencing.
- **status**: One of the 5 allowed values. See Status Lifecycle below.
- **last_modified**: ISO date (`YYYY-MM-DD`) when the doc was last updated. Must be updated on every edit.

### Conditional Fields

- **services**: Array of affected directories or components. Helps agents match "I'm editing X, does a design doc cover this?"
- **superseded_by**: Required when status is `superseded`. Points to the replacement doc number.
- **related**: Include when related docs exist. Array of doc numbers for navigation.

### Docs Index

After creating or updating a design doc, regenerate the index:

```bash
bash scripts/generate-docs-index.sh
```

This produces `docs/DOCS_INDEX.md` — a compact table (#, Status, Name, Description, Last Modified, Path) injected at session start so agents know what design docs exist without reading each one. The `#` column is extracted from the `number` frontmatter field (falling back to the filename prefix). Superseded docs are excluded from the index.

## Status Lifecycle

```
draft → current → partially-outdated → superseded
                ↘ not-implemented (if design was never built)
```

| Status | Meaning |
|--------|---------|
| `draft` | Design proposed but not yet approved or implemented |
| `current` | Design matches production code |
| `partially-outdated` | Core design still applies but some details have drifted from code |
| `superseded` | Replaced by another doc — must set `superseded_by` |
| `not-implemented` | Design was approved but never built |

When changing status, also update `last_modified` to today's date.

## Numbering

- Next available number: check `ls docs/design/ | sort` and pick the next zero-padded 3-digit number (e.g., `003`, `010`).
- No duplicate numbers. Each top-level doc or directory gets a unique number.
- Sub-documents inside a directory (e.g., `014-credentials-vault/plan-1-vault-service.md`) share the parent number.
- Agent-specific docs go under `docs/design/agents/` with their own numbering sequence.

## File Naming

```
{number}-{kebab-case-topic}.md
```

Examples:
- `029-prototype-v3-web-migration.md`
- `agents/008-coding-agent-core-executor.md`

Directories for multi-doc topics:
```
017-multi-instance-isolation/
├── helm-test-env-deployment-model.md
├── isolated-ingress-shared-alb-proposal.md
└── TBD.md
```

## Document Structure

```markdown
---
(frontmatter)
---

# {Number} — {Title}

## Status

{Status explanation with context — why it has this status, what changed}

## Summary

{2-3 sentences: what problem this solves and the key design decision}

## (Body sections — flexible per topic)

## Boundaries

{What this design does NOT cover. What must not change without updating this doc. This is the core anti-drift mechanism.}

## References

- Related docs, external links, prior art
```

### Writing Rules

- Lead with the decision, not the analysis. Readers want to know "what did we choose" before "what did we consider."
- Use concrete file paths, struct names, and API endpoints — not abstractions.
- If the doc is in Chinese, keep it in Chinese. If in English, keep it in English. Don't mix.
- Mark superseded sections inline with strikethrough or a note, don't silently delete history.
- When a design changes, update the existing doc rather than creating a new one — unless the change is a complete replacement (then supersede).

## Cross-References

- Reference other design docs by number: "see 023-agent-broker-architecture"
- When renaming/renumbering, update ALL references. Use: `grep -r "old-name" docs/ AGENTS.md README.md deploy/`

## Verification

Before marking a doc as `current`, verify key claims against code:
- Do referenced file paths exist?
- Do referenced struct/function names exist?
- Do referenced API endpoints exist?
- Does the described architecture match the actual service boundaries?

Update `last_modified` when you complete verification.
