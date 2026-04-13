---
name: write-docs
description: >
  Write, edit, and manage structured project documentation under docs/ — enforces
  frontmatter format, category conventions, numbering, status lifecycle, and writing
  rules. Use when: "write a doc", "document this", "create a guide", "write a design doc",
  "write a troubleshooting guide", "create a reference doc", "update the docs",
  "document this decision", or when capturing guides, troubleshooting playbooks,
  reference material, or design decisions as docs. Note: for system design thinking
  (architecture, trade-offs, scaling), use /ship:arch-design first, then come here
  to write it up. For visual design (DESIGN.md), use /ship:visual-design.
---

# Documentation Standard

All structured docs live under `docs/`. Each subdirectory is a category (e.g., `docs/design/`, `docs/guides/`, `docs/troubleshooting/`). Follow this standard when creating new docs or modifying existing ones.

## Red Flag

**Never:**
- Lead with analysis instead of the decision
- Include implementation details that belong in code
- Mix languages within one document
- Silently delete history — mark superseded sections, don't erase them
- Create a doc without adding it to the docs index
- Mark a doc as `current` without verifying claims against code
- Skip the Boundaries section in design docs — it's the core anti-drift mechanism
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
- **description**: One concise sentence. This gets injected into session context as an index — write it for an AI that needs to decide "should I read this doc?" without opening it. Max 120 chars.
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
bash "${SHIP_PLUGIN_ROOT:-$(ship-plugin-root 2>/dev/null)}/scripts/generate-docs-index.sh"
```

This produces `docs/DOCS_INDEX.md` — a compact table (Category, #, Status, Name, Description, Last Modified, Path) injected at session start so agents know what docs exist without reading each one. Superseded docs are excluded from the index.

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

After writing or updating a doc, regenerate the index and output the report card:

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
2. **Design thinking** — /ship:arch-design if the architectural analysis needs more depth
3. **Ship it** — /ship:handoff to create a PR with the doc changes
```
