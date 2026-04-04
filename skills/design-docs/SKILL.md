---
name: design-docs
version: 1.0.0
description: >
  Create and maintain high-level design documents that prevent AI drift
  and capture architectural decisions. Design docs are guardrails — they
  tell AI agents what boundaries exist and why, so agents don't make
  locally-correct decisions that violate the overall architecture.
  Use when: write design doc, create design doc, update design doc,
  review design doc, architecture decision, ADR.
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Ship: Design Docs

Design docs are **architectural guardrails for AI and humans**.

They answer the questions that cause drift when unanswered:
- Why is the code structured this way?
- What boundaries must not be crossed?
- What trade-offs were made and why?
- What was tried and rejected?

Without design docs, an AI agent sees code and "improves" it — merging
services that must stay separate, simplifying flows that have hidden
constraints, re-proposing ideas that already failed.

A short, decisive design doc prevents more drift than a comprehensive
one nobody finishes reading. Most design docs should be under 200 lines.

## Red Flag

**Never:**
- Write a design doc longer than 200 lines without splitting it
- Lead with analysis instead of the decision
- Include implementation details that belong in code
- Mix languages within one document
- Silently delete history — mark superseded sections, don't erase them
- Create a design doc without adding it to the docs index
- Mark a doc as `current` without verifying claims against code

---

## Frontmatter

Every design doc starts with YAML frontmatter for AI indexing:

```yaml
---
title: "Human-readable title"
description: "One sentence, under 120 chars — enough for AI to decide whether to read this doc"
status: current | draft | partially-outdated | superseded | not-implemented
superseded_by: "new-doc-name"  # only when status is superseded
scope:
  - src/auth        # directories this design covers
  - src/middleware
last_verified: "2026-04-04"    # last checked against code
---
```

### Field rules

- **description**: Write for an AI deciding "should I read this?" — not a summary of the doc, but a signal of what it covers.
- **status**: The trust signal. See Status Lifecycle below.
- **scope**: Directories or modules this design covers. When an agent works on files in scope, it should read this doc first.
- **last_verified**: ISO date. Update whenever you confirm the doc matches code.

## Status Lifecycle

```
draft → current → partially-outdated → superseded
                ↘ not-implemented (design was never built)
```

| Status | AI should... |
|--------|-------------|
| `current` | Trust and follow this doc |
| `draft` | Read for context but don't build against it |
| `partially-outdated` | Trust the principles, verify the details |
| `superseded` | Ignore — read the replacement instead |
| `not-implemented` | Design exists but code doesn't match it yet |

When changing status, update `last_verified` to today.

## Document Structure

```markdown
---
(frontmatter)
---

# Title

## Decision

What we chose. 2-3 sentences. A reader should understand the core
design decision from this section alone.

## Context

What problem or constraint led to this decision. Why the status quo
was insufficient. Keep it brief — enough to understand the why,
not a full history.

## Design

How it works at a high level. Use concrete file paths, module names,
and API endpoints — not abstractions. Diagrams welcome but not required.

This section scales to complexity: a simple boundary decision gets a
paragraph, a system architecture gets subsections.

## Boundaries

**The anti-drift section.** What must NOT change and why.

Examples:
- "Service A and Service B must not share a database — they need
  independent scaling and different consistency guarantees."
- "Auth checks in middleware must not be simplified or removed to
  fix downstream errors — see incident 2025-03-12."
- "The event bus is async by design. Do not add sync request-reply
  patterns even if they seem simpler for a specific use case."

Be specific. "Don't break the architecture" is useless. "These two
modules must not import from each other because X" is useful.

## Trade-offs

What we gave up and why it's acceptable. This prevents an AI from
"fixing" something that was a deliberate choice.

Example: "We chose eventual consistency over strong consistency for
user preferences. This means preferences may take up to 5s to
propagate. This is acceptable because preferences are read-heavy
and rarely change."

## Alternatives Considered (optional)

Brief — one paragraph per alternative. What was considered, why it
was rejected. Prevents AI from re-proposing failed ideas.

## References (optional)

Related design docs, external links, prior art.
```

## File Organization

Design docs live in `docs/design/` (create the directory if it doesn't
exist). Use descriptive kebab-case filenames:

```
docs/design/
  auth-architecture.md
  event-bus-design.md
  database-per-service.md
  agent-isolation-model.md
```

If a topic needs multiple docs, use a directory:

```
docs/design/multi-instance-isolation/
  overview.md
  networking.md
  storage.md
```

### Docs index

If `docs/README.md` exists, add your doc there. If no docs index
exists, create `docs/design/README.md` listing all design docs with
their descriptions (from frontmatter).

## Creating a Design Doc

### Phase 1: Investigate

Before writing, read the code that this design covers:
- Trace the key paths
- Identify existing boundaries (explicit or implicit)
- Look for comments or commit messages that explain "why"
- Check if a design doc already exists for this area

### Phase 2: Write

Follow the document structure above. Focus on:
- **Decision first** — a reader should know what was chosen in 10 seconds
- **Boundaries are the most important section** — this is what prevents drift
- **Be concrete** — file paths, module names, endpoint names, not abstractions
- **Be brief** — under 200 lines. If longer, split into multiple docs.

### Phase 3: Verify

Before setting status to `current`:
- Do referenced file paths exist?
- Do referenced module/function names exist?
- Does the described architecture match the actual code structure?
- Are the stated boundaries actually maintained in the code?

Update `last_verified` after verification.

## Updating a Design Doc

When code changes affect a design doc's scope:

1. Read the design doc
2. Check if the change violates any stated boundaries
3. If the design is still accurate → update `last_verified`
4. If details have drifted → update the doc, set `partially-outdated` if unsure
5. If the design is being replaced → write a new doc, set old one to `superseded`

Prefer updating a doc over creating a new one — unless the change is
a complete architectural replacement.

## Execution Handoff

After creating or updating a design doc:

```
[Design Docs] <Created|Updated|Verified> — <doc filename>
  Status: <status>
  Scope: <directories covered>
  Boundaries: <N> architectural constraints documented

## What's next?
1. **Review** — read the doc and give feedback
2. **Implement** — run /ship:auto to build against this design
3. **Share** — the doc is ready for team review
```
